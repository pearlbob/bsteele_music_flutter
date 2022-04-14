import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chord.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/measure.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

import '../util/songPerformanceDaemon.dart';
import 'app_theme.dart';

final App app = App();

String userName = Platform.environment['USER'] ?? Platform.environment['LOGNAME'] ?? 'my';

final Color appDisabledColor = Colors.grey[400] ?? Colors.grey;
const double appDefaultFontSize = 10.0; //  based on phone

const NameValue allSongsMetadataNameValue = NameValue('all', '');
const NameValue holidayMetadataNameValue = NameValue('christmas', '');

const parkFixedIpAddress = '192.168.1.205'; //  hard, fixed ip address of CJ's park raspberry pi

enum MessageType {
  info,
  warning,
  error,
}

enum CommunityJamsSongList {
  all,
  jams,
  ninjam,
}

NameValue get myGoodSongNameValue => NameValue(userName, 'good');

NameValue get myBadSongNameValue => NameValue(userName, 'bad');

/// workaround for rootBundle.loadString() failures in flutter test
Future<String> loadString(String assetPath) async {
  //return rootBundle.loadString(assetPath, cache: false);
  ByteData data = await rootBundle.load(assetPath);
  logger.v('data.lengthInBytes: ${data.lengthInBytes}');
  final buffer = data.buffer;
  var list = buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  return utf8.decode(list);
}

/// Application level, non-persistent, shared values
class App {
  factory App() {
    return _singleton;
  }

  App._internal();

  //  parameters to be evaluated before use
  ThemeData themeData = ThemeData(); //  start with the default theme

  /// A single instance of the screen information class for common use.
  ScreenInfo screenInfo = ScreenInfo.defaultValue(); //  refreshed on main build
  bool isEditReady = false;
  bool isScreenBig = true;
  bool isPhone = false;

  final SongPerformanceDaemon songPerformanceDaemon = SongPerformanceDaemon();

  /// Add a song to the master song list
  void addSong(Song song) {
    logger.v('addSong( ${song.toString()} )');
    _allSongs.remove(song); // any prior version of same song
    _allSongs.add(song);
    _filteredSongs.clear();
    selectedSong = song;
  }

  /// Add a list of songs to the master song list
  void addSongs(List<Song> songs) {
    for (var song in songs) {
      addSong(song);
    }
  }

  /// Remove all songs from the master song list
  void removeAllSongs() {
    _allSongs.clear();
    _filteredSongs.clear();
    selectedSong = _emptySong;
  }

  /// Enter an error message to the user
  bool errorMessage(String error) {
    if (this.error != error) {
      this.error = error;
      return true;
    }
    return false;
  }

  /// Enter an informational message to the user
  void infoMessage(String message) {
    _messageType = MessageType.info;
    _message = message;
  }

  /// Clear all messages to the user
  void clearMessage() {
    _messageType = MessageType.info;
    _message = '';
  }

  set warningMessage(String warning) {
    _messageType = MessageType.warning;
    _message = warning;
  }

  /// Return the current error message
  String? get error => (_messageType == MessageType.error ? _message : null);

  /// Set an error message
  set error(String? message) {
    _messageType = MessageType.error;
    _message = message ?? '';
  }

  /// Generate a message display widget
  Widget messageTextWidget(AppKeyEnum appKeyEnum) {
    return Text(_message,
        style: messageType == MessageType.error ? appErrorTextStyle : appWarningTextStyle, key: appKey(appKeyEnum));
  }

  String get message => _message;
  String _message = '';

  MessageType get messageType => _messageType;
  MessageType _messageType = MessageType.info;

  SplayTreeSet<Song> get allSongs => _allSongs;
  final SplayTreeSet<Song> _allSongs = SplayTreeSet();

  SplayTreeSet<Song> get filteredSongs => _filteredSongs;
  final SplayTreeSet<Song> _filteredSongs = SplayTreeSet();

  Song _selectedSong = _emptySong;

  set selectedSong(Song value) {
    if (value.songBaseSameContent(_selectedSong)) {
      return;
    }
    _selectedSong = value;
    _selectedMomentNumber = 0;
  }

  Song get selectedSong => _selectedSong;

  int _selectedMomentNumber = 0;

  int get selectedMomentNumber => _selectedMomentNumber;

  set selectedMomentNumber(int value) {
    _selectedMomentNumber = max(0, min(value, _selectedSong.songMoments.length - 1));
  }

  Song get emptySong => _emptySong;
  static final Song _emptySong = Song.createEmptySong();

  set displayKeyOffset(int offset) {
    _displayKeyOffset = offset % MusicConstants.halfStepsPerOctave;
  }

  int get displayKeyOffset => _displayKeyOffset;
  static int _displayKeyOffset = 0;

  bool get fullscreenEnabled => html.document.fullscreenEnabled ?? false;

  //
  void requestFullscreen() {
    if (html.document.fullscreenEnabled == true) {
      html.document.documentElement?.requestFullscreen();
    }
  }

  void exitFullScreen() {
    if (html.document.fullscreenEnabled == true) {
      html.document.exitFullscreen();
    }
  }

  bool get isFullScreen {
    if (html.document.fullscreenEnabled == true) {
      return html.document.fullscreenElement != null;
    }
    return false;
  }

  Future<String> releaseUtcDate() async {
    return await rootBundle.loadString('lib/assets/utcDate.txt').then((value) {
      return Future.value(value.replaceAll('\n', ''));
    });
  }

  //  an experiment
  // clearWidgets() {
  //   _widgetMap.clear();
  // }
  // registerWidget(ValueKey<String> key, Widget widget) {
  //   _widgetMap[key] = widget;
  // }
  //
  // logWidgets() {
  //   logger.i('logWidgets: ${_widgetMap.keys.length}');
  //   for (var key in _widgetMap.keys) {
  //     //logger.i(' key: ${key.runtimeType} ${key.toString()}');
  //     var widget = _widgetMap[key];
  //     if (widget != null) {
  //       if (widget is ElevatedButton) {
  //         logger.i('  ${key.value} => ElevatedButton.${widget.onPressed}');
  //       }
  //       else if (widget is TextButton) {
  //         logger.i('  ${key.value} => TextButton.${widget.onPressed}');
  //         if ( key.value == 'playerNextSong'){
  //           widget.onPressed?.call();
  //         }
  //       }
  //       else {
  //         logger.i('  widget.runtimeType: ${widget.runtimeType}, key: ${key.value}');
  //       }
  //     }
  //   }
  // }
  //
  // final Map<ValueKey<String>, Widget> _widgetMap = {};

  static final App _singleton = App._internal();
}

TextStyle appTextStyle = generateAppTextStyle(fontSize: _defaultFontSize, color: Colors.black);
TextStyle appWarningTextStyle = generateAppTextStyle(fontSize: _defaultFontSize, color: Colors.blue);
TextStyle appErrorTextStyle = generateAppTextStyle(fontSize: _defaultFontSize, color: Colors.red);

const double _defaultFontSize = 24;

TextStyle appButtonTextStyle({final double? fontSize}) {
  return generateAppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.black);
}

Widget appSpace({double? space, double? horizontalSpace, double? verticalSpace}) {
  if (space == null) {
    assert((horizontalSpace ?? 0) >= 0);
    assert((verticalSpace ?? 0) >= 0);
    return SizedBox(
      height: verticalSpace ?? 10,
      width: horizontalSpace ?? 10,
    );
  }
  space = max(space, 0);
  return SizedBox(
    height: space,
    width: space,
  );
}

double viewportWidth(double width) {
  return width / 100 * app.screenInfo.mediaWidth;
}

/// Supply a spacing box proportional to the screen's width... not exactly the viewport though!
Widget appSpaceViewportWidth({double? space, double? horizontalSpace, double? verticalSpace}) {
  final width = app.screenInfo.mediaWidth;
  assert(width > 0);

  if (space == null) {
    assert((horizontalSpace ?? 0) >= 0);
    assert((verticalSpace ?? 0) >= 0);
    return SizedBox(
      height: (verticalSpace ?? 1) / 100 * width,
      width: (horizontalSpace ?? 1) / 100 * width,
    );
  }
  space = max(space, 0);
  return SizedBox(
    height: space / 100 * width,
    width: space / 100 * width,
  );
}

Widget appVerticalSpace({double? space}) {
  if (space == null) {
    return const SizedBox(
      height: 10,
      width: double.infinity,
    );
  }
  space = max(space, 0);
  return SizedBox(
    height: space,
    width: double.infinity,
  );
}

/// helper function to generate tool tips
Widget appTooltip({
  final Key? key,
  required final String message,
  required final Widget child,
  final double? fontSize,
}) {
  var textStyle = generateTooltipTextStyle(fontSize: fontSize);
  return Tooltip(
      key: key,
      message: message,
      child: child,
      textStyle: textStyle,
      waitDuration: const Duration(seconds: 1, milliseconds: 200),
      verticalOffset: 75,
      decoration: appTooltipBoxDecoration(textStyle.backgroundColor),
      padding: const EdgeInsets.all(8));
}

BoxDecoration appTooltipBoxDecoration(final Color? color) {
  return BoxDecoration(
      color: color,
      border: Border.all(),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      boxShadow: const [BoxShadow(color: Colors.grey, offset: Offset(8, 8), blurRadius: 10)]);
}

Wrap appWrap(List<Widget> children,
    {final WrapAlignment? alignment, final WrapCrossAlignment? crossAxisAlignment, final double? spacing}) {
  return Wrap(
    children: children,
    crossAxisAlignment: crossAxisAlignment ?? WrapCrossAlignment.end,
    alignment: alignment ?? WrapAlignment.start,
    spacing: spacing ?? 0.0,
  );
}

Widget appWrapFullWidth(
    {final List<Widget>? children,
    final WrapAlignment? alignment,
    final WrapCrossAlignment? crossAxisAlignment,
    final double? spacing}) {
  return SizedBox(
    width: double.infinity,
    child: appWrap(children ?? [], alignment: alignment, crossAxisAlignment: crossAxisAlignment, spacing: spacing),
  );
}

appRadio<T>(
  String text, {
  required AppKeyEnum appKeyEnum,
  required T value,
  required T groupValue,
  required VoidCallback? onPressed,
  TextStyle? style,
}) {
  return appWrap(
    [
      Radio<T>(
        value: value,
        groupValue: groupValue,
        onChanged: (value) {
          onPressed?.call();
        },
      ),
      appTextButton(text, appKeyEnum: appKeyEnum, onPressed: onPressed, style: style),
    ],
  );
}

typedef CanPopQualifier = bool Function();

///  A collection of methods that generate application styled widgets.
///  It also provides a handy place to hold the build context should it be needed.
class AppWidgetHelper {
  AppWidgetHelper(this.context);

  Widget back({final CanPopQualifier? canPop, final VoidCallback? onPressed}) {
    return appTooltip(
      message: 'Back',
      child: appIconButton(
        appKeyEnum: AppKeyEnum.appBack,
        onPressed: () {
          if (canPop?.call() ?? true) {
            onPressed?.call();
            Navigator.pop(context);
          }
        },
        icon: appIcon(Icons.arrow_back),
      ),
    );
  }

  Widget floatingBack(final AppKeyEnum appKeyEnum, {final CanPopQualifier? canPop}) {
    return appTooltip(
      message: 'Back',
      child: appFloatingActionButton(
        appKeyEnum: appKeyEnum,
        onPressed: () {
          if (canPop?.call() ?? true) {
            Navigator.pop(context);
          }
        },
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }

  AppBar backBar(
      {final AppKeyEnum? appKeyEnum,
      final Widget? titleWidget,
      final String? title,
      final List<Widget>? actions,
      final VoidCallback? onPressed}) {
    return appBar(
        appKeyEnum: appKeyEnum ?? AppKeyEnum.appBarBack,
        title: title,
        titleWidget: titleWidget,
        leading: back(onPressed: onPressed),
        actions: actions);
  }

  AppBar appBar(
      {final AppKeyEnum? appKeyEnum,
      final String? title,
      final Widget? titleWidget,
      final Widget? leading,
      final List<Widget>? actions}) {
    return AppBar(
      key: appKeyEnum != null ? appKey(appKeyEnum) : null,
      title: titleWidget ??
          Text(
            title ?? 'unknown',
            style: TextStyle(
              fontSize: app.screenInfo.fontSize,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.transparent,
            ),
          ),
      leading: leading,
      centerTitle: false,
      actions: actions,
      toolbarHeight: (app.isScreenBig ? kToolbarHeight : kToolbarHeight * 0.6),
      //  trim for cell phone overrun
      leadingWidth: 2.5 * app.screenInfo.fontSize,
    );
  }

  Widget checkbox({required final bool? value, final ValueChanged<bool?>? onChanged, final double? fontSize}) {
    ThemeData themeData = Theme.of(context);
    return Transform.scale(
      scale: 0.7 * (fontSize ?? _defaultFontSize) / Checkbox.width,
      child: Checkbox(
          checkColor: Colors.white, fillColor: themeData.checkboxTheme.fillColor, value: value, onChanged: onChanged),
    );
  }

  Widget transpose(final Measure measure, final music_key.Key key, final int halfSteps,
      {required final TextStyle style}) {
    TextStyle slashStyle = generateChordSlashNoteTextStyle(fontSize: style.fontSize).copyWith(
      // fontFamily: 'Roboto', //  fixme
      backgroundColor: style.backgroundColor,
    );
    TextStyle chordDescriptorStyle = generateChordDescriptorTextStyle(
      fontSize: 0.8 * (style.fontSize ?? _defaultFontSize),
    ).copyWith(
      backgroundColor: style.backgroundColor,
    );

    if (measure.chords.isNotEmpty) {
      final List<TextSpan> children = [];
      for (final Chord chord in measure.chords) {
        var transposedChord = chord.transpose(key, halfSteps);
        var isSlash = transposedChord.slashScaleNote != null;

        //  chord note
        children.add(TextSpan(
          text: transposedChord.scaleChord.scaleNote.toString(),
          style: style,
        ));
        {
          //  chord descriptor
          var name = transposedChord.scaleChord.chordDescriptor.shortName;
          if (name.isNotEmpty) {
            children.add(
              TextSpan(
                text: name,
                style: chordDescriptorStyle,
              ),
            );
          }
        }

        //  other stuff
        children.add(TextSpan(
          text: transposedChord.anticipationOrDelay.toString() + transposedChord.beatsToString(),
          style: style,
        ));
        if (isSlash) {
          var s = '/${transposedChord.slashScaleNote.toString()} '; //  notice the final space for italics
          children.add(TextSpan(
            text: s,
            style: slashStyle,
          ));
        }
      }

      return RichText(
        text: TextSpan(children: children),
        //  don't allow the rich text to wrap:
        textWidthBasis: TextWidthBasis.longestLine,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        textDirection: TextDirection.ltr,
        textScaleFactor: 1.0,
        textAlign: TextAlign.start,
        textHeightBehavior: const TextHeightBehavior(),
      );
    }

    //  no chord measures such as repeats, repeat markers and comments
    return _text(
      measure.toString(),
      style,
    );
  }

  Widget chordSection(final ChordSection chordSection, {required final TextStyle style}) {
    return _text(
      chordSection.sectionVersion.toString(),
      style,
    );
  }

  Widget _text(final String text, final TextStyle style) {
    return Text(
      text,
      style: style,
      softWrap: false,
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }

  ///  should be set on every build!
  final BuildContext context;
}
