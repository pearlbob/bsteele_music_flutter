import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pretty_diff_text/pretty_diff_text.dart';

import '../app/app.dart';

enum _dialogResponse { accept, reject, acceptAll, rejectAll }

/// Provide a number of song related actions for the user.
/// This includes reading song files, clearing all songs from the current song list, and the like.
class Songs extends StatefulWidget {
  const Songs({Key? key}) : super(key: key);

  @override
  _Songs createState() => _Songs();
}

class _Songs extends State<Songs> {
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
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'bsteele Music App Song Management'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(36.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              app.messageTextWidget(AppKeyEnum.songsErrorMessage),
              appSpace(),
              appEnumeratedButton(
                'Read local file',
                appKeyEnum: AppKeyEnum.songsReadFiles,
                onPressed: () {
                  _filePick(context);
                },
              ),
              appSpace(
                space: 20,
              ),
              appEnumeratedButton(
                'Write all songs to the local file: $fileLocation',
                appKeyEnum: AppKeyEnum.songsWriteFiles,
                onPressed: () {
                  _writeAll();
                },
              ),
              appSpace(
                space: 20,
              ),
              appTooltip(
                message: 'A reload of the application will return them all.',
                child: appEnumeratedButton(
                  'Remove all songs from the current list',
                  appKeyEnum: AppKeyEnum.songsRemoveAll,
                  onPressed: () {
                    setState(() {
                      app.removeAllSongs();
                    });
                  },
                ),
              ),
              appSpace(
                space: 20,
              ),
              Text(
                'Song count:  ${app.allSongs.length}',
                style: generateAppTextStyle(),
              ),
              Text(
                'Most recent: ${_mostRecent()}',
                style: generateAppTextStyle(),
              ),
            ]),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.songsBack),
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

    return intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(lastModifiedTime));
  }

  /// write all songs to the standard location
  void _writeAll() async {
    String fileName = 'allSongs_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.songlyrics';
    String contents = Song.listToJson(app.allSongs.toList());
    UtilWorkaround().writeFileContents(fileName, contents);

    setState(() {
      app.infoMessage('wrote file: $fileName to $fileLocation folder');
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
            case _dialogResponse.accept:
              break;
            case _dialogResponse.acceptAll:
              acceptAll = true;
              break;
            case _dialogResponse.reject:
              continue;
            case _dialogResponse.rejectAll:
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

  Future<_dialogResponse> _diffWarningPopup(Song oldSong, Song newSong) async {
    PrettyDiffText prettyDiffText =
        PrettyDiffText(oldText: Util.readableJson(oldSong.toJson()), newText: Util.readableJson(newSong.toJson()));
    logger.i('_diffWarningPopup( ${oldSong.songId.toString()} , ${newSong.songId.toString()})');
    _dialogResponse response = _dialogResponse.rejectAll;
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
                    appWrapFullWidth([
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
                        '${oldSong.lastModifiedTime>newSong.lastModifiedTime?' It\'s older!':''}',
                        style: prettyDiffText.addedTextStyle,
                      )
                    ], spacing: 20),
                    prettyDiffText
                  ],
                ),
              ),
              actions: [
                appWrapFullWidth([
                  appButton('Accept', appKeyEnum: AppKeyEnum.songsAcceptSongRead, onPressed: () {
                    Navigator.of(context).pop();
                    response = _dialogResponse.accept;
                  }),
                  appButton('Reject', appKeyEnum: AppKeyEnum.songsRejectSongRead, onPressed: () {
                    Navigator.of(context).pop();
                    response = _dialogResponse.reject;
                  }),
                ], spacing: 20),
                appSpace(),
                appWrapFullWidth([
                  appButton('Accept all songs', appKeyEnum: AppKeyEnum.songsAcceptAllSongReads, onPressed: () {
                    Navigator.of(context).pop();
                    response = _dialogResponse.acceptAll;
                  }),
                  appButton('Reject this and any more songs', appKeyEnum: AppKeyEnum.songsCancelSongAllAdds,
                      onPressed: () {
                    Navigator.of(context).pop();
                    response = _dialogResponse.rejectAll;
                  }),
                ], spacing: 20),
              ],
              actionsAlignment: MainAxisAlignment.start,
              elevation: 24.0,
            ));
    return response;
  }

  late AppWidgetHelper appWidgetHelper;

  String fileLocation = kIsWeb ? 'download folder in local drive' : 'Documents';
  final App app = App();
}
