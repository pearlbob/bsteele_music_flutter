import 'dart:math';

import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pretty_diff_text/pretty_diff_text.dart';

import '../app/app.dart';
import '../app/appOptions.dart';
import 'edit.dart';

enum SongsDialogResponse { accept, reject, acceptAll, rejectAll }

/// Provide a number of song related actions for the user.
/// This includes reading song files, clearing all songs from the current song list, and the like.
class Songs extends StatefulWidget {
  const Songs({super.key});

  @override
  SongsState createState() => SongsState();

  static const String routeName = 'songs';
}

class SongsState extends State<Songs> {
  @override
  initState() {
    super.initState();

    app.clearMessage();
    logger.d("_Songs.initState()");
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: appWidgetHelper.backBar(title: 'bsteeleMusicApp Song Management'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(36.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              app.messageTextWidget(),
              const AppSpace(),
              appButton(
                'Read local file',
                onPressed: () {
                  _filePick(context);
                },
              ),
              const AppSpace(
                space: 20,
              ),
              appButton(
                'Write all songs to the local file: $fileLocation',
                onPressed: () {
                  _writeAll();
                },
              ),
              const AppSpace(
                space: 20,
              ),
              AppTooltip(
                message: 'A reload of the application will return them all.',
                child: appButton(
                  'Remove all songs from the current list',
                  onPressed: () {
                    setState(() {
                      app.removeAllSongs();
                    });
                  },
                ),
              ),
              const AppSpace(
                verticalSpace: 40,
              ),
              AppTooltip(
                message: 'Edit the last song the editor validated.\n'
                    'This can be used to recover an edited song... if you are lucky.',
                child: appButton(
                  'Edit the last song edited',
                  onPressed: () {
                    _navigateToLastEdit();
                  },
                ),
              ),
              const AppSpace(
                verticalSpace: 20,
              ),
              Text(
                'Song count:  ${app.allSongs.length}',
                style: generateAppTextStyle(),
              ),
              Text(
                'Most recent song update: ${_mostRecent()}',
                style: generateAppTextStyle(),
              ),
            ]),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(),
    );
  }

  String _mostRecent() {
    if (app.allSongs.isEmpty) {
      return 'empty list';
    }

    var lastModifiedTime = 0;
    for (var song in app.allSongs) {
      lastModifiedTime = max(lastModifiedTime, song.lastModifiedTime);
    }

    return intl.DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(lastModifiedTime));
  }

  /// write all songs to the standard location
  void _writeAll() async {
    String fileName = 'allSongs_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.songlyrics';
    String contents = Song.listToJson(app.allSongs.toList());
    UtilWorkaround().writeFileContents(fileName, contents);

    setState(() {
      app.infoMessage = 'wrote file: $fileName to $fileLocation folder';
    });
  }

  void _filePick(BuildContext context) async {
    int songsReadCount = 0;
    int songsDuplicateCount = 0;
    bool acceptAll = false;

    var songsRead = await UtilWorkaround().songFilePick(context);
    forLoop:
    for (final Song song in songsRead) {
      if (app.allSongs.contains(song)) {
        Song? oldSong = app.allSongs.firstWhere((v) => song.compareTo(v) == 0, orElse: () {
          return Song.theEmptySong; // should never happen
        });
        if (song.songBaseSameContent(oldSong)) {
          songsDuplicateCount++;
          continue;
        }

        if (!acceptAll) {
          switch (await _diffWarningPopup(oldSong, song)) {
            case SongsDialogResponse.accept:
              break;
            case SongsDialogResponse.acceptAll:
              acceptAll = true;
              break;
            case SongsDialogResponse.reject:
              continue;
            case SongsDialogResponse.rejectAll:
              break forLoop;
          }
        }
      }
      app.addSong(song);
      songsReadCount++;
    }
    var dupString = songsDuplicateCount > 1
        ? ', with $songsDuplicateCount duplicates'
        : (songsDuplicateCount > 0 ? ', with 1 duplicate' : '');
    var songsInFile = '${songsRead.length} song${songsRead.length == 1 ? '' : 's'}';
    app.warningMessage = '$songsReadCount new song${songsReadCount == 1 ? '' : 's'} read$dupString out of $songsInFile';
    setState(() {});
  }

  Future<SongsDialogResponse> _diffWarningPopup(Song oldSong, Song newSong) async {
    PrettyDiffText prettyDiffText = PrettyDiffText(
        oldText: Util.readableJson(oldSong.toJsonString()), newText: Util.readableJson(newSong.toJsonString()));
    logger.i('_diffWarningPopup( ${oldSong.songId.toString()} , ${newSong.songId.toString()})');
    SongsDialogResponse response = SongsDialogResponse.rejectAll;
    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(
                '${oldSong.title} by ${oldSong.artist}'
                '${oldSong.coverArtist.isNotEmpty ? ', cover by ${oldSong.coverArtist}' : ''}\n\n'
                'The existing version of this song differs from the song read:',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    AppWrapFullWidth(spacing: 20, children: [
                      Text(
                        'Legend:',
                        style: prettyDiffText.defaultTextStyle,
                      ),
                      Text(
                        'Existing, dated: '
                        '${intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(oldSong.lastModifiedTime))}'
                        ' ${intl.DateFormat.Hms().format(DateTime.fromMillisecondsSinceEpoch(oldSong.lastModifiedTime))}',
                        style: prettyDiffText.deletedTextStyle,
                      ),
                      Text(
                        'Read, dated: '
                        '${intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(newSong.lastModifiedTime))}'
                        ' ${intl.DateFormat.Hms().format(DateTime.fromMillisecondsSinceEpoch(newSong.lastModifiedTime))}'
                        '${oldSong.lastModifiedTime > newSong.lastModifiedTime ? ' It\'s older!' : ''}',
                        style: prettyDiffText.addedTextStyle,
                      )
                    ]),
                    prettyDiffText
                  ],
                ),
              ),
              actions: [
                AppWrapFullWidth(spacing: 20, children: [
                  appButton('Accept', onPressed: () {
                    Navigator.of(context).pop();
                    response = SongsDialogResponse.accept;
                  }),
                  appButton('Reject', onPressed: () {
                    Navigator.of(context).pop();
                    response = SongsDialogResponse.reject;
                  }),
                ]),
                const AppSpace(),
                AppWrapFullWidth(spacing: 20, children: [
                  appButton('Accept all songs', onPressed: () {
                    Navigator.of(context).pop();
                    response = SongsDialogResponse.acceptAll;
                  }),
                  appButton('Reject this and any more songs', onPressed: () {
                    Navigator.of(context).pop();
                    response = SongsDialogResponse.rejectAll;
                  }),
                ]),
              ],
              actionsAlignment: MainAxisAlignment.start,
              elevation: 24.0,
            ));
    return response;
  }

  _navigateToLastEdit() async {
    app.clearMessage();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Edit(initialSong: AppOptions().lastSongEdited)),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  self
  }

  late AppWidgetHelper appWidgetHelper;

  String fileLocation = kIsWeb ? 'download folder in local drive' : 'Downloads';
  final App app = App();
}
