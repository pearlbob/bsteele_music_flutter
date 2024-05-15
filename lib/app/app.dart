import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/chord_section.dart';
import 'package:bsteele_music_lib/songs/drum_measure.dart';
import 'package:bsteele_music_lib/songs/key.dart' as music_key;
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/section.dart';
import 'package:bsteele_music_lib/songs/section_version.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_metadata.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:bsteele_music_lib/songs/song_update.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

import '../util/songPerformanceDaemon.dart';
import 'appOptions.dart';
import 'app_theme.dart';

final App app = App();
final AppOptions _appOptions = AppOptions();

String userName = Platform.environment['USER'] ??
    Platform.environment['USERNAME'] ??
    Platform.environment['LOGNAME'] ??
    Song.defaultUser;

//  intentionally global to share with singer screen    fixme?
music_key.Key? playerSelectedSongKey;
int? playerSelectedBpm = MusicConstants.defaultBpm;
String? playerSinger;

const double appDefaultFontSize = 10.0; //  based on phone

const parkFixedIpAddress = '192.168.1.205'; //  hard, fixed ip address of CJ's park raspberry pi

const _toolTipWaitDuration = Duration(seconds: 1, milliseconds: 500);

extension SongUpdateStateExtension on SongUpdateState {
  bool get isPlaying => this == SongUpdateState.playing;

  bool get isPlayingOrPaused => this == SongUpdateState.playing || this == SongUpdateState.pause;

// IconData get icon {
//   return switch (this) {
//     SongUpdateState.idle => Icons.stop,
//     SongUpdateState.playing => Icons.play_arrow,
//     SongUpdateState.pause => Icons.pause,
//     _ => Icons.stop,
//   };
// }
}

/// Song list sort types
enum PlayListSortType {
  byHistory('Order by when the song was last sung\n'
      'with the most oldest singing first.'), //  by convention: should be first
  byLastSung('Order by when the song was last sung\n'
      'with the most recent first.'), //  by convention: should be second
  bySinger('Order by the song performance\'s singer.'),
  byTitle('Order by the song\'s title.'),
  byArtist('Order by the song\'s artist.'),
  byLastChange('Order by the date of the most recent edit.'),
  byComplexity('Order by the song\'s complexity when compared to other songs.'),
  byYear('Order by the song\'s year.'),
  ;

  const PlayListSortType(this.toolTip);

  final String toolTip;
}

enum MessageType {
  info,
  warning,
  error,
}

enum NashvilleSelection {
  off,
  both,
  only;
}

enum CommunityJamsSongList {
  all,
  jams,
  ninjam,
}

NameValue get myGoodSongNameValue => NameValue(userName, 'good');

NameValue get myBadSongNameValue => NameValue(userName, 'bad');

const defaultTableGap = 3.0;

/// workaround for rootBundle.loadString() failures in flutter test
Future<String> loadAssetString(String assetPath) async {
  //return rootBundle.loadString(assetPath, cache: false);
  ByteData data = await rootBundle.load(assetPath);
  logger.t('data.lengthInBytes: ${data.lengthInBytes}');
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
  ThemeData themeData =
      ThemeData.localize(ThemeData.light(useMaterial3: true), Typography().white); //  start with a default theme

  //  colors
  static const appBackgroundColor = Color(0xff2196f3);
  static const screenBackgroundColor = Colors.white;
  static const defaultBackgroundColor = Color(0xff2654c6);
  static const defaultForegroundColor = Colors.white;
  static const disabledColor = Color(0xFFE8E8E8);
  static const textFieldColor = Color(0xFFE8E8E8);

  //  universal
  static const universalBackgroundColor = Colors.white;
  static const universalForegroundColor = Colors.black;
  static const universalAccentColor = Color(0xff57a9ff);

  // const _universalFontWeight = FontWeight.normal;
  static const universalFontStyle = FontStyle.normal;

  //  app bar
  static const appbarBackgroundColor = defaultBackgroundColor;

  //  button
  static const oddTitleTextColor = Colors.black;
  static const oddTitleTextBackgroundColor = Color(0xfff5f5f5); //  whitesmoke
  static const evenTitleTextColor = Colors.black;
  static const evenTitleTextBackgroundColor = Colors.white;

  //  tooltip
  static const tooltipBackgroundColor = Color(0xffdcedc8);
  static const tooltipColor = Colors.black;

  //  chord note
  static const measureContainerBackgroundColor = Color(0xff598aea);
  static const chordNoteColor = Colors.black;
  static const chordNoteBackgroundColor = Colors.white;
  static const chordNoteFontWeight = FontWeight.bold;
  static const chordNoteFontStyle = FontStyle.normal;

  //  chord descriptor
  static const chordDescriptorColor = Colors.black87;

  //  icons
  static const iconColor = Colors.white;

  //  margins and padding
  EdgeInsetsGeometry get measureMargin => const EdgeInsets.all(3);

  EdgeInsetsGeometry get measurePadding => const EdgeInsets.all(5);

  static Color getBackgroundColorForSectionVersion(SectionVersion? sectionVersion) {
    sectionVersion ??= SectionVersion.defaultInstance;

    var index = sectionVersion.version <= 0 ? 0 : sectionVersion.version - 1;
    var colorInts = _sectionColorMap[sectionVersion.section.sectionEnum] ?? [0xf0f0f0];
    var color = Color(0xff000000 | (colorInts[index % colorInts.length] & 0xffffff));

    return color;
  }

//  all section versions 1 will be the same color as the section without a version number
//  section version color cycle will be determined by the number of colors added here for each section
  static const Map<SectionEnum, List<int>> _sectionColorMap = {
    SectionEnum.intro: [
      // 0&1     2         3
      0xccfcc3, 0xb5e6ad, 0xa3cf9b
    ],
    SectionEnum.verse: [
      // 0 & 1     2         3
      0xfcf99d, 0xeaea7a, 0xd1d16d,
    ],
    SectionEnum.preChorus: [
      // 0 & 1     2
      0xf4dcf2, 0xe1bee7, 0xdaa8e5
    ],
    SectionEnum.chorus: [
      // 0 & 1     2         3
      0xf0f0f0, 0xd1d2d3, 0xbdbebf
    ],
    SectionEnum.a: [
      // 0 & 1     2         3
      0xfcf99d, 0xeaea7a, 0xd1d16d,
    ],
    SectionEnum.b: [0xdfd9ff, 0xcabbff, 0xaca0ef],
    SectionEnum.bridge: [0xdfd9ff, 0xcabbff, 0xaca0ef],
    SectionEnum.coda: [0xd7e5ff, 0xb6d2fc, 0x92b8ef],
    SectionEnum.tag: [0xf4dcf2, 0xe1bee7, 0xdaa8e5],
    SectionEnum.outro: [
      // 0 & 1
      0xd7e5ff, 0xb6d2fc, 0x92b8ef
    ],
  };

  /// A single instance of the screen information class for common use.
  ScreenInfo screenInfo = ScreenInfo.defaultValue(); //  refresh often for window size changes
  bool isEditReady = false;
  bool isScreenBig = true;
  bool isPhone = false;

  final SongPerformanceDaemon songPerformanceDaemon = SongPerformanceDaemon();

  /// Add a song to the master song list
  void addSong(Song song) {
    logger.t('addSong( ${song.toString()} )');
    _allSongs.remove(song); // any prior version of same song
    _allSongs.add(song);
    SongMetadata.generateSongMetadata(song);
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
    SongMetadata.clear();
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
  set infoMessage(String message) {
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
    if (_message.isEmpty) {
      return NullWidget();
    }
    return Text(_message,
        style: messageType == MessageType.error ? appErrorTextStyle : _appWarningTextStyle,
        key: appKeyCreate(appKeyEnum));
  }

  String get message => _message;
  String _message = '';

  MessageType get messageType => _messageType;
  MessageType _messageType = MessageType.info;

  SplayTreeSet<Song> get allSongs => _allSongs;
  final SplayTreeSet<Song> _allSongs = SplayTreeSet();

  Song _selectedSong = _emptySong;

  set selectedSong(Song value) {
    if (value.songBaseSameContent(_selectedSong)) {
      return;
    }
    _selectedSong = value;
    _selectedMomentNumber = 0;
  }

  Song get selectedSong => _selectedSong;

  DrumParts? selectedDrumParts;

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

  Future<String> releaseUtcDate() {
    return rootBundle.loadString('lib/assets/utcDate.txt').then((value) {
      return value.replaceAll('\n', '');
    });
  }

  @override
  String toString() {
    return 'App{screenInfo: $screenInfo, isPhone: $isPhone'
        ', _selectedSong: $_selectedSong, _selectedMomentNumber: $_selectedMomentNumber}';
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
TextStyle _appWarningTextStyle = generateAppTextStyle(fontSize: _defaultFontSize, color: Colors.blue);
TextStyle appErrorTextStyle = generateAppTextStyle(fontSize: _defaultFontSize, color: Colors.red);

const double _defaultFontSize = 24;

TextStyle appButtonTextStyle({final double? fontSize}) {
  return generateAppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.black);
}

@immutable
class AppSpace extends StatelessWidget {
  const AppSpace(
      {super.key,
      this.space,
      //this.spaceFactor = 1.0,
      this.horizontalSpace,
      this.verticalSpace});

  static const double defaultSpace = 10;

  @override
  Widget build(BuildContext context) {
    if (space == null) {
      assert((horizontalSpace ?? 0) >= 0);
      assert((verticalSpace ?? 0) >= 0);
      return SizedBox(
        height: verticalSpace ?? (spaceFactor * defaultSpace),
        width: horizontalSpace ?? (spaceFactor * defaultSpace),
      );
    }
    final double maxSpace = max(space ?? 0, 0);
    return SizedBox(
      height: maxSpace,
      width: maxSpace,
    );
  }

  final double? space;
  static const double spaceFactor = 1;
  final double? horizontalSpace;
  final double? verticalSpace;
}

double viewportWidth(double width) {
  return width / 100 * app.screenInfo.mediaWidth;
}

/// Supply a spacing box proportional to the screen's width... not exactly the viewport though!
@immutable
class AppSpaceViewportWidth extends StatelessWidget {
  const AppSpaceViewportWidth({super.key, this.space, this.horizontalSpace, this.verticalSpace});

  @override
  Widget build(BuildContext context) {
    final width = app.screenInfo.mediaWidth;
    assert(width > 0);

    if (space == null) {
      assert((horizontalSpace ?? 0) >= 0 || (verticalSpace ?? 0) >= 0);
      return SizedBox(
        height: (verticalSpace ?? 0) / 100 * width,
        width: (horizontalSpace ?? 0) / 100 * width,
      );
    }
    var fixedSpace = max(space ?? 0, 0);
    return SizedBox(
      height: fixedSpace / 100 * width,
      width: fixedSpace / 100 * width,
    );
  }

  final double? space;
  final double? horizontalSpace;
  final double? verticalSpace;
}

@immutable
class AppVerticalSpace extends StatelessWidget {
  const AppVerticalSpace({super.key, this.space});

  @override
  Widget build(BuildContext context) {
    if (space == null) {
      return const SizedBox(
        height: 10,
        width: 0,
      );
    }
    final double height = max(space ?? 0, 0);
    return SizedBox(
      height: height,
      width: 0,
    );
  }

  final double? space;
}

/// helper function to generate tool tips
@immutable
class AppTooltip extends StatelessWidget {
  const AppTooltip({super.key, required this.message, required this.child});

  @override
  Widget build(BuildContext context) {
    if (_appOptions.toolTips) {
      var textStyle = generateTooltipTextStyle(fontSize: app.screenInfo.fontSize);
      return Tooltip(
          key: key,
          message: message,
          textStyle: textStyle,
          waitDuration: _toolTipWaitDuration,
          verticalOffset: 75,
          decoration: appTooltipBoxDecoration(textStyle.backgroundColor),
          padding: const EdgeInsets.all(8),
          child: child);
    } else {
      return child;
    }
  }

  final String message;
  final Widget child;
}

BoxDecoration appTooltipBoxDecoration(final Color? color) {
  return BoxDecoration(
      color: color,
      border: Border.all(),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      boxShadow: const [BoxShadow(color: Colors.grey, offset: Offset(8, 8), blurRadius: 10)]);
}

@immutable
class AppWrap extends StatelessWidget {
  const AppWrap({super.key, required this.children, this.alignment, this.crossAxisAlignment, this.spacing});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: crossAxisAlignment ?? WrapCrossAlignment.center,
      alignment: alignment ?? WrapAlignment.start,
      spacing: spacing ?? 0.0,
      runSpacing: 3,
      children: children,
    );
  }

  final List<Widget> children;
  final WrapAlignment? alignment;
  final WrapCrossAlignment? crossAxisAlignment;
  final double? spacing;
}

@immutable
class AppWrapFullWidth extends StatelessWidget {
  const AppWrapFullWidth({super.key, required this.children, this.alignment, this.crossAxisAlignment, this.spacing});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child:
          AppWrap(alignment: alignment, crossAxisAlignment: crossAxisAlignment, spacing: spacing, children: children),
    );
  }

  final List<Widget> children;
  final WrapAlignment? alignment;
  final WrapCrossAlignment? crossAxisAlignment;
  final double? spacing;
}

/// Used as a workaround for Wrap not having CrossAxisAlignment.baseline
@immutable
class AppRow extends StatelessWidget {
  const AppRow({super.key, this.mainAxisAlignment = MainAxisAlignment.spaceBetween, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: children);
  }

  final MainAxisAlignment mainAxisAlignment;
  final List<Widget> children;
}

@immutable
class AppRadio<T> extends StatelessWidget {
  const AppRadio({
    super.key,
    required this.text,
    required this.appKeyEnum,
    required this.value,
    required this.groupValue,
    required this.onPressed,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return AppWrap(
      children: [
        Radio<T>(
          value: value,
          groupValue: groupValue,
          onChanged: (value) {
            onPressed?.call();
          },
        ),
        appTextButton(text, appKeyEnum: appKeyEnum, onPressed: onPressed, style: style, value: value),
      ],
    );
  }

  final String text;
  final AppKeyEnum appKeyEnum;
  final T value;
  final T groupValue;
  final VoidCallback? onPressed;
  final TextStyle? style;
}

// appRadio<T>(
//   String text, {
//   required AppKeyEnum appKeyEnum,
//   required T value,
//   required T groupValue,
//   required VoidCallback? onPressed,
//   TextStyle? style,
// }) {
//   return AppWrap(
//     children: [
//       Radio<T>(
//         value: value,
//         groupValue: groupValue,
//         onChanged: (value) {
//           onPressed?.call();
//         },
//       ),
//       appTextButton(text, appKeyEnum: appKeyEnum, onPressed: onPressed, style: style),
//     ],
//   );
// }

typedef CanPopQualifier = bool Function();

///  A collection of methods that generate application styled widgets.
///  It also provides a handy place to hold the build context should it be needed.
class AppWidgetHelper {
  AppWidgetHelper(this.context);

  IconButton back({final CanPopQualifier? canPop, final VoidCallback? onPressed}) {
    return appIconButton(
      appKeyEnum: AppKeyEnum.appBack,
      onPressed: () {
        if (canPop?.call() ?? true) {
          onPressed?.call();
          Navigator.pop(context);
        }
      },
      icon: appIcon(Icons.arrow_back),
    );
  }

  Widget floatingBack(final AppKeyEnum appKeyEnum, {final CanPopQualifier? canPop}) {
    return AppTooltip(
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
      final IconButton? leading,
      final List<Widget>? actions}) {
    _toolbarHeight = (app.isScreenBig ? kToolbarHeight : kToolbarHeight * 0.6);
    return AppBar(
      key: appKeyEnum != null ? appKeyCreate(appKeyEnum) : null,
      leading: leading,
      title: titleWidget ??
          Text(
            title ?? 'unknown',
            style: TextStyle(
              fontSize: app.screenInfo.fontSize,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.transparent,
            ),
          ),
      centerTitle: false,
      actions: actions,
      toolbarHeight: _toolbarHeight,
      //  trim for cell phone overrun
      leadingWidth: 2.75 * app.screenInfo.fontSize,
      backgroundColor: App.defaultBackgroundColor,
      foregroundColor: App.defaultForegroundColor,
    );
  }

  Widget checkbox(
      {required final bool? value, final ValueChanged<bool?>? onChanged, final TextStyle? style, final String? label}) {
    var checkbox = Checkbox(
        checkColor: Colors.white,
        fillColor: WidgetStateProperty.all(App.appBackgroundColor),
        value: value,
        onChanged: onChanged);
    if (label != null) {
      return AppWrap(
        children: [
          checkbox,
          const AppSpace(
              //    spaceFactor: 0.5,
              ),
          Text(
            label,
            style: style,
          )
        ],
      );
    }
    return checkbox;
  }

  RichText chordSection(final ChordSection chordSection, {required final TextStyle style}) {
    return RichText(
      text: TextSpan(text: chordSection.sectionVersion.toString(), style: style),
      //  don't allow the rich text to wrap:
      textWidthBasis: TextWidthBasis.longestLine,
      maxLines: 1,
      overflow: TextOverflow.clip,
      softWrap: false,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      textAlign: TextAlign.start,
      textHeightBehavior: const TextHeightBehavior(),
    );
  }

  double get toolbarHeight => _toolbarHeight;
  double _toolbarHeight = kToolbarHeight;

  ///  should be set on every build!
  final BuildContext context;
}
