import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/chordSectionLocation.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/sectionVersion.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/songs/timeSignature.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'app.dart';

const Level _logAppKey = Level.debug;

TextStyle appDropdownListItemTextStyle = //  fixme: find the right place for this!
    const TextStyle(backgroundColor: Colors.white, color: Colors.black, fontSize: 24); // fixme: shouldn't be fixed

const appBackgroundColor = Color(0xff2196f3);
const _defaultBackgroundColor = Color(0xff2654c6);
const _defaultForegroundColor = Colors.white;
const screenBackgroundColor = Colors.white;

//  universal
const _universalBackgroundColor = Colors.white;
const _universalForegroundColor = Colors.black;
const universalAccentColor = Color(0xff57a9ff);

// const _universalFontWeight = FontWeight.normal;
const _universalFontStyle = FontStyle.normal;

//  app bar
const appbarBackgroundColor = _defaultBackgroundColor;

//  button
const _oddTitleTextColor = Colors.black;
const _oddTitleTextBackgroundColor = Color(0xfff5f5f5); //  whitesmoke
const _evenTitleTextColor = Colors.black;
const _evenTitleTextBackgroundColor = Colors.white;

//  tooltip
const _tooltipBackgroundColor = Color(0xffdcedc8);
const _tooltipColor = Colors.black;

//  chord note
const measureContainerBackgroundColor = Color(0xff598aea);
const _chordNoteColor = Colors.black;
const _chordNoteBackgroundColor = Colors.white;
const _chordNoteFontWeight = FontWeight.bold;
const _chordNoteFontStyle = FontStyle.normal;

//  chord descriptor
const _chordDescriptorColor = Colors.black87;

//  icons
const _iconColor = Colors.white;

Color getBackgroundColorForSectionVersion(SectionVersion? sectionVersion) {
  sectionVersion ??= SectionVersion.defaultInstance;

  var index = sectionVersion.version <= 0 ? 0 : sectionVersion.version - 1;
  var colorInts = _sectionColorMap[sectionVersion.section.sectionEnum] ?? [0xf0f0f0];
  var color = Color(0xff000000 | (colorInts[index % colorInts.length] & 0xffffff));

  return color;
}

//  all section versions 1 will be the same color as the section without a version number
//  section version color cycle will be determined by the number of colors added here for each section
Map<SectionEnum, List<int>> _sectionColorMap = {
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

EdgeInsetsGeometry getMeasureMargin() {
  return const EdgeInsets.all(3);
}

EdgeInsetsGeometry getMeasurePadding() {
  return const EdgeInsets.all(5);
}

/// Application keys to select all application actions. See [ appKey() ]
enum AppKeyEnum implements Comparable<AppKeyEnum> {
  ///  Return from the about screen
  aboutBack(Null),
  aboutErrorMessage(Null),
  aboutLog(Null),

  ///  Write the diagnostic file of application actions
  aboutWriteDiagnosticLogFile(Null),
  appBack(Null), //  screen pop
  ///  Return to the screen's parent
  appBarBack(Null),
  cssDemoBack(Null),
  cssDemoButton(Null),
  cssDemoIconButton(Null),
  debugWriteLog(Null),
  detailBack(Null),
  detailCloseOptions(Null),
  detailLoop1(Null),
  detailLoop2(Null),
  detailLoop4(Null),
  detailLoop(Null),
  detailLoopSelected(Null),
  detailLyrics(Null),
  detailOptions(Null),
  detailPlay(Null),
  detailStop(Null),
  documentationBack(Null),
  editAcceptChordModificationAndExtendRow(Null),
  editAcceptChordModificationAndFinish(Null),
  editAcceptChordModificationAndStartNewRow(Null),
  editAddChordRow(ChordSectionLocation),
  editAddChordRowNew(ChordSectionLocation),
  editAddChordRowRepeat(ChordSectionLocation),
  editArtist(String),
  editBack(Null),
  editBPM(String),
  editCancelChordModification(Null),
  editChordDataPoint(ChordSectionLocation),
  editChordPlusAppend(ChordSectionLocation),
  editChordPlusInsert(ChordSectionLocation),
  editChordSectionAcceptAndAdd(ChordSection),
  editChordSectionAccept(ChordSection),
  editChordSectionCancel(ChordSection),
  editChordSectionDelete(ChordSection),
  editChordSectionLocation(ChordSectionLocation),
  editClearSong(Null),
  editCopyright(String),
  editCoverArtist(String),
  editDeleteChordMeasure(Null),
  editDeleteLyricsSection(Null),
  editDeleteRepeat(ChordSectionLocation),
  editDiscardAllChanges(Null),
  editDominant7Chord(Null),
  editEditKeyDropdown(music_key.Key),
  editEditTimeSignatureDropdown(TimeSignature),
  editEditTimeSignature(TimeSignature),
  editEnterSong(Null),
  editErrorMessage(Null),
  editFormat(Null),
  editHints(Null),
  editImportLyrics(Null),
  editMajorChord(Null),
  editMinorChord(Null),
  editMusicKey(music_key.Key),
  editNewChordSection(Null),
  editProChords(String),
  editProInputOff(Null),
  editProInputOn(Null),
  editProLyrics(String),
  editRedo(Null),
  editRemoveSong(Null),
  editRenameSong(Null),
  editRepeatCancel(ChordSectionLocation),
  editRepeat(ChordSectionLocation),
  editRepeatX2(ChordSectionLocation),
  editRepeatX3(ChordSectionLocation),
  editRepeatX4(ChordSectionLocation),
  editRowJoin(Null),
  editRowSplit(Null),
  editScaleChord(ScaleChord),
  editScaleNote(ScaleNote),
  editScreenDetail(Null),
  editSilentChord(Null),
  editSingleChildScrollView(Null),
  editTitle(String),
  editUndo(Null),
  editUserName(String),
  editValidateChords(Null),
  listsBack(Null),
  listsCancelDeleteList(Null),
  listsClearLists(Null),
  listsClearSearch(Null),
  listsDeleteList(Null),
  listsErrorMessage(Null),
  listsMetadataAdd(String),
  listsNameClear(Null),
  listsNameEntry(String),
  listsRadio(Null),
  listsReadLists(Null),
  listsSave(Null),
  listsSaveCSV(Null),
  listsSaveSelected(Null),
  listsSearchText(String),
  listsValueClear(Null),
  listsValueEntry(String),
  lyricsEntryLineAdd(int),
  lyricsEntryLineDelete(int),
  lyricsEntryLineDown(int),
  lyricsEntryLine(Null),
  lyricsEntryLineUp(int),
  mainAcceptBeta(Null),
  mainClearSearch(Null),
  mainDrawer(Null),
  mainDrawerAbout(Null),
  mainDrawerCssDemo(Null),
  mainDrawerDebug(Null),
  mainDrawerDocs(Null),
  mainDrawerLists(Null),
  mainDrawerNewSong(Null),
  mainDrawerOptions(Null),
  mainDrawerPerformanceHistory(Null),
  mainDrawerPrivacy(Null),
  mainDrawerSingers(Null),
  mainDrawerSongs(Null),
  mainDrawerTheory(Null),
  mainErrorMessage(Null),
  mainGoToRelease(Null),
  mainHamburger(Null),
  mainSong(Id),
  mainSortType(PlayListSortType),
  mainSortTypeSelection(PlayListSortType),
  mainUp(Null),
  metadataCancelTheReturn(Null),
  metadataDiscardAllChanges(Null),
  metadataWriteAllChanges(Null),
  optionsBack(Null),
  optionsExpandRepeats(String),
  optionsFullScreen(Null),
  optionsLeadership(Null),
  optionsNashville(NashvilleSelection),
  optionsNinJam(String),
  optionsUserDisplayStyle(String),
  optionsUserName(String),
  optionsWebsocketBob(Null),
  optionsWebsocketCJ(Null),
  optionsWebsocketIP(String),
  optionsWebsocketNone(Null),
  optionsWebsocketPark(Null),
  optionsWebsocketThisHost(Null),
  performanceHistoryBack(Null),
  performanceHistoryErrorMessage(Null),
  playListMetadataRemove(NameValue),
  playListMetadata(String),
  playListFilter(NameValue),
  playListSearch(String),
  playerBack(Null),
  playerBPM(int),
  playerCapoLabel(bool),
  playerCapo(bool),
  playerCompressRepeats(bool),
  playerCompressRepeatsLabel(String),
  playerCopyNinjamBPM(Null),
  playerCopyNinjamChords(Null),
  playerCopyNinjamCycle(Null),
  playerEdit(Null),
  playerErrorMessage(Null),
  playerFloatingPlay(Null),
  playerFloatingStop(Null),
  playerFloatingTop(Null),
  playerFullScreen(Null),
  playerKeyDown(Null),
  playerKeyOffset0(Null),
  playerKeyOffset10(Null),
  playerKeyOffset11(Null),
  playerKeyOffset1(Null),
  playerKeyOffset2(Null),
  playerKeyOffset3(Null),
  playerKeyOffset4(Null),
  playerKeyOffset5(Null),
  playerKeyOffset6(Null),
  playerKeyOffset7(Null),
  playerKeyOffset8(Null),
  playerKeyOffset9(Null),
  playerKeyOffset(int),
  playerKeyUp(Null),
  playerMusicKey(music_key.Key),
  playerNextSong(Null),
  playerPlay(Null),
  playerPreviousSong(Null),
  playerReturnFromSettings(Null),
  playerSettings(Null),
  playerSongBad(Null),
  playerSongGood(Null),
  playerSpeed(Null), //  debug only
  playerTempoTap(Null),
  privacyBack(Null),
  sheetMusic16thNoteUp(Null),
  sheetMusic8thNoteUp(Null),
  sheetMusicHalfNoteUp(Null),
  sheetMusicQuarterNoteUp(Null),
  sheetMusicRest16th(Null),
  sheetMusicRest8th(Null),
  sheetMusicRestHalf(Null),
  sheetMusicRestQuarter(Null),
  sheetMusicRestWhole(Null),
  sheetMusicWholeNote(Null),
  singersAddSingerToSession(String),
  singersAllSingers(String),
  singersBack(Null),
  singersCancelDeleteSinger(Null),
  singersClearRequestedSearch(Null),
  singersDeleteSingerConfirmation(Null),
  singersDeleteSinger(Null),
  singersErrorMessage(Null),
  singersMoveSingerEarlierInSession(Null),
  singersMoveSingerLaterInSession(Null),
  singersNameEntry(String),
  singersReadASingleSinger(Null),
  singersReadSingers(Null),
  singersRemoveAllSingers(Null),
  singersRemoveSingerFromSession(Null),
  singersRemoveThisSingerFromSession(Null),
  singersRequestVolunteer(String),
  singersSave(Null),
  singersSaveSelected(Null),
  singersSearchSingle(bool),
  singersSearchSingleSwitch(Null),
  singersSessionSingerSelect(String),
  singersVolunteerSingerSelect(String),
  singersVolunteerSingerSelectClear(Null),
  singersShowOtherActions(Null),
  singersSingerClearSearch(Null),
  singersSingerSearchText(String),
  singersSinging(bool),
  singersSingingTextButton(String),
  singersSortTypeSelection(String),
  songsAcceptAllSongReads(Null),
  songsAcceptSongRead(Null),
  songsBack(Null),
  songsCancelSongAllAdds(Null),
  songsErrorMessage(Null),
  songsReadFiles(Null),
  songsRejectSongRead(Null),
  songsRemoveAll(Null),
  songsWriteFiles(Null),
  theoryBack(Null),
  theoryHalf(Null),
  theoryRoot(Null);

  const AppKeyEnum(this.argType);

  @override
  int compareTo(AppKeyEnum other) {
    if (identical(this, other)) {
      return 0;
    }
    return index.compareTo(other.index);
  }

  final Type argType;
}

class Id {
  Id(this.id);

  @override
  String toString() {
    return id;
  }

  static parse(String s) => Id(s);

  String id;
}

typedef AppKey = ValueKey<String>;

/// Generate an application key from the enumeration and an optional value
AppKey appKey(AppKeyEnum e, {dynamic value}) {
  var type = e.argType;
  switch (type) {
    case Null:
      assert(value == null);
      return ValueKey<String>(e.name);
    case String:
      return ValueKey<String>(e.name + (value == null ? '' : '.$value'));
    case music_key.Key:
      assert(value.runtimeType == type);
      return ValueKey<String>('${e.name}.${(value as music_key.Key).toMarkup()}');
    default:
      if (value.runtimeType != type) {
        logger.w('appKey(): $e.value.runtimeType = ${value.runtimeType} != $type');
        assert(value.runtimeType == type);
      }
      return ValueKey<String>('${e.name}.${value.toString()}');
  }
}

//  the weakly typed storage here is strongly enforced by the strongly typed construction of the registration
//  i.e. by the app key enum argument type
//  fixme: should be cleared on page change
Map<AppKeyEnum, Function> _appKeyRegisterCallbacks = {};

appKeyCallbacksClear() {
  logger.log(_logAppKey, 'appKeyCallbacksClear: ');
  _appKeyRegisterCallbacks.clear(); //  can't run callbacks if the widget tree is now gone
}

_appKeyCallbacksDebugLog() {
  logger.log(_logAppKey, '_appKeyCallbacksDebugLog:');
  for (var e in SplayTreeSet<AppKeyEnum>()..addAll(_appKeyRegisterCallbacks.keys)) {
    logger.log(_logAppKey, '  registered $e: ${_appKeyRegisterCallbacks[e].runtimeType}');
  }
}

//  fixme: can't figure a better way to do this since generic constructors can't reference their type
typedef TypeParser<T> = T? Function(String s);

Map<Type, TypeParser> _appKeyParsers = {
  Null: (s) => null,
  String: (s) => s,

  bool: (s) => s == 'true',
  ChordSection: (s) => ChordSection.parseString(s, 4), //  fixme: not always 4!
  ChordSectionLocation: (s) => ChordSectionLocation.parseString(s), //  void
  PlayListSortType: (s) => PlayListSortType.values.firstWhere((e) => e.name == s),
  NashvilleSelection: (s) => NashvilleSelection.values.firstWhere((e) => e.name == s),
  music_key.Key: (s) => music_key.Key.parseString(s),
  Id: (s) => Id.parse(s),
  int: (s) => int.parse(s),
  ScaleChord: (s) => ScaleChord.parseString(s),
  ScaleNote: (s) => ScaleNote.parseString(s),
  TimeSignature: (s) => TimeSignature.parse(s),
};

void _appKeyRegisterCallback(AppKeyEnum e, {VoidCallback? voidCallback, Function? callback}) {
  if (!kDebugMode) //fixme: temp
  {
    return;
  }
  if (voidCallback != null) {
    assert(e.argType == Null);
    _appKeyRegisterCallbacks[e] = voidCallback;
  } else if (callback != null) {
    if (e.argType == Null) {
      logger.w('_appKeyRegisterCallback: $e.argType == ${e.argType}');
      assert(e.argType != Null);
    }
    _appKeyRegisterCallbacks[e] = callback;
  }
}

Map<String, AppKeyEnum>? _appKeyEnumLookupMap;

bool appKeyExecute(String logString) {
  //  lazy eval up type lookup
  if (_appKeyEnumLookupMap == null) {
    _appKeyEnumLookupMap = {};
    for (var e in AppKeyEnum.values) {
      _appKeyEnumLookupMap![e.name] = e;
      //  assure that we can convert everything
      //  fixme: should be done at compile time
      assert(_appKeyParsers[e.argType] != null);
    }
  }

  //  find the app key and value string... if it exists
  String? eString;
  String? valueString;
  var m = _appKeyLogRegexp.firstMatch(logString);
  if (m != null) {
    eString = m.group(1);
    if (m.groupCount >= 2) {
      valueString = m.group(2); //  may be null!
    }
  }
  logger.v('eString: "$eString", value: $valueString');

  //  execute the app key
  if (eString != null) {
    var e = _appKeyEnumLookupMap![eString];
    if (e != null) {
      var callback = _appKeyRegisterCallbacks[e];
      if (callback != null) {
        try {
          if (callback is VoidCallback) {
            assert(valueString == null);
            appLogKeyCallback(appKey(e));
            callback.call();
            return true;
          } else {
            assert(valueString != null);
            if (e.argType == String) {
              //  optimization
              appLogKeyCallback(appKey(e, value: valueString));
              Function.apply(callback, [valueString]);
              return true;
            } else {
              //  parse string to correct value type
              var value = _appKeyParsers[e.argType]?.call(valueString!);
              logger.log(_logAppKey, '$e ${e.argType}.$valueString => $value');
              callback.call(value);
              return true;
            }
          }
        } catch (ex) {
          logger.w('callback threw exception: $ex');
        }
      } else {
        logger.w('callback not found registered for: $e');
      }
    } else {
      logger.w('appKeyEnum not found: $eString');
    }
  } else {
    logger.w('appKeyEnum not found in logString: $logString');
  }
  return false;
}

final _appKeyLogRegexp = RegExp(r'^([^.]*)(?:\.?(.+?))?$'); // second group may be null!

void testAppKeyCallbacks() async {
  if (!kDebugMode) //fixme: temp
  {
    logger.log(_logAppKey, 'debugLoggerAppKeyRegisterCallbacks:  NOT DEBUG');
    return;
  }
  //  fixme: sample only
  logger.log(_logAppKey, 'testAppKeyCallbacks:');

  //logger.log(_logAppKey,'appKeyExecute: mainSortType.byComplexity: ${appKeyExecute('mainSortType.byComplexity')}');
  // setState() called after dispose():
  _appKeyCallbacksDebugLog();
  logger.log(_logAppKey, 'appKeyExecute: mainDrawer: ${appKeyExecute('mainDrawer')}');
  await Future.delayed(const Duration(seconds: 1));
  _appKeyCallbacksDebugLog();

  logger.log(_logAppKey, 'appKeyExecute: mainDrawerOptions: ${appKeyExecute('mainDrawerOptions')}');
  await Future.delayed(const Duration(seconds: 1));
  logger.log(_logAppKey, 'appKeyExecute: optionsWebsocketBob: ${appKeyExecute('optionsWebsocketBob')}');
  await Future.delayed(const Duration(seconds: 1));
  logger.log(_logAppKey, 'appKeyExecute: optionsUserName.myfirst: ${appKeyExecute('optionsUserName.myfirst')}');
  // await Future.delayed(const Duration(seconds: 8));
  // logger.log(_logAppKey,'appKeyExecute: optionsUserName.bobstuff: ${appKeyExecute('optionsUserName.bobstuff')}');
  await Future.delayed(const Duration(seconds: 4));
  logger.log(_logAppKey, 'appKeyExecute: done');

  // logger.log(_logAppKey,'appKeyExecute: playerMusicKey.Eb: ${appKeyExecute('playerMusicKey.Eb')}');
}

Widget appCircledIcon(IconData iconData, String toolTip,
    {Color? color, EdgeInsetsGeometry? margin, EdgeInsetsGeometry? padding, double? size}) {
  return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: AppTooltip(
        message: toolTip,
        child: Icon(
          iconData,
          size: size,
        ),
      ));
}

/// Icon widget with the application look
Icon appIcon(IconData icon, {Key? key, Color? color, double? size}) {
  return Icon(icon,
      key: key,
      color: color ?? _iconColor,
      size: size ?? app.screenInfo.fontSize //  let the algorithm figure the size dynamically
      );
}

class AppTheme {
  static final AppTheme _singleton = AppTheme._internal();

  factory AppTheme() {
    return _singleton;
  }

  AppTheme._internal();

  Future init() async {
    {
      // var iconTheme = IconThemeData(color: _defaultForegroundColor); fixme
      // var radioTheme = RadioThemeData(fillColor: MaterialStateProperty.all(_defaultForegroundColor)); fixme
      var elevatedButtonThemeStyle = app.themeData.elevatedButtonTheme.style ?? const ButtonStyle();
      elevatedButtonThemeStyle = elevatedButtonThemeStyle.copyWith(elevation: MaterialStateProperty.all(6));

      //  hassle with mapping Color to MaterialColor
      var color = appbarBackgroundColor;
      Map<int, Color> colorCodes = {
        50: color.withOpacity(.1),
        100: color.withOpacity(.2),
        200: color.withOpacity(.3),
        300: color.withOpacity(.4),
        400: color.withOpacity(.5),
        500: color.withOpacity(.6),
        600: color.withOpacity(.7),
        700: color.withOpacity(.8),
        800: color.withOpacity(.9),
        900: color.withOpacity(1),
      };
      MaterialColor materialColor = MaterialColor(color.value, colorCodes);
      color = _universalBackgroundColor;

      app.themeData = app.themeData.copyWith(
        backgroundColor: color,
        primaryColor: color,
        disabledColor: Colors.grey.shade300,
        elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonThemeStyle),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: materialColor, accentColor: universalAccentColor),
      );
    }
  }
}

List<String> _appLog = [];

List<String> appLog() {
  return _appLog;
}

void appLogKeyCallback(ValueKey<String> key) {
  _appLog.add(key.value);
}

int _lastMessageEpochUs = DateTime.now().microsecondsSinceEpoch;

void appLogMessage(String message) {
  var t = DateTime.now();
  var duration = Duration(microseconds: t.microsecondsSinceEpoch - _lastMessageEpochUs);
  _lastMessageEpochUs = t.microsecondsSinceEpoch;
  _appLog.add('// $t +$duration: $message');
}

typedef KeyCallback = void Function();

ElevatedButton appEnumeratedButton(
  String commandName, {
  required AppKeyEnum appKeyEnum,
  required VoidCallback? onPressed,
  Color? backgroundColor,
  double? fontSize,
}) {
  _appKeyRegisterCallback(appKeyEnum, voidCallback: onPressed);
  return appButton(
    commandName,
    appKeyEnum: appKeyEnum,
    onPressed: onPressed,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
  );
}

ElevatedButton appButton(
  String commandName, {
  required AppKeyEnum appKeyEnum,
  required VoidCallback? onPressed,
  final TextStyle? style,
  Color? backgroundColor,
  double? fontSize,
  dynamic value,
}) {
  fontSize ??= app.screenInfo.fontSize;
  var key = appKey(appKeyEnum, value: value);

  return ElevatedButton(
    key: key,
    clipBehavior: Clip.hardEdge,
    onPressed: onPressed == null
        ? null //  show as disabled
        : () {
            appLogKeyCallback(key); //  log the click
            onPressed();
          },
    style:
        app.themeData.elevatedButtonTheme.style?.copyWith(backgroundColor: MaterialStateProperty.all(backgroundColor)),
    child: Text(commandName,
        style: style ??
            //  app.themeData.elevatedButtonTheme.style?.textStyle?.resolve({}) ??
            TextStyle(fontSize: fontSize, backgroundColor: backgroundColor)),
  );
}

TextButton appTextButton(
  String text, {
  required AppKeyEnum appKeyEnum,
  required VoidCallback? onPressed,
  TextStyle? style,
  dynamic value,
}) {
  var key = appKey(appKeyEnum, value: value ?? text);
  _appKeyRegisterCallback(appKeyEnum, callback: onPressed);
  return TextButton(
    key: key,
    onPressed: () {
      appLogKeyCallback(key);
      onPressed?.call();
    },
    style: ButtonStyle(textStyle: MaterialStateProperty.all(style)),
    child: Text(
      text,
      style: style,
    ),
  );
}

TextButton appIconButton({
  required AppKeyEnum appKeyEnum,
  required Widget icon,
  required VoidCallback onPressed,
  dynamic value,
  TextStyle? style,
  double? fontSize,
  String? label,
  Color? backgroundColor,
}) {
  var key = appKey(appKeyEnum, value: value);
  return TextButton.icon(
    key: key,
    icon: icon,
    label: Text(label ?? '', style: style ?? TextStyle(fontSize: fontSize)),
    onPressed: () {
      appLogKeyCallback(key);
      onPressed();
    },
    style: app.themeData.elevatedButtonTheme.style
        ?.copyWith(backgroundColor: MaterialStateProperty.all(backgroundColor ?? _defaultBackgroundColor)),
  );
}

ElevatedButton appNoteButton(
  String character, // a note character is expected
  {
  required AppKeyEnum appKeyEnum,
  required VoidCallback? onPressed,
  Color? backgroundColor,
  double? fontSize,
  double? height,
  dynamic value,
}) {
  fontSize ??= app.screenInfo.fontSize;
  var key = appKey(appKeyEnum, value: value);

  fontSize = 30;

  return ElevatedButton(
    key: key,
    onPressed: onPressed == null
        ? null //  show as disabled
        : () {
            appLogKeyCallback(key); //  log the click
            onPressed();
          },
    child: Baseline(
      baselineType: TextBaseline.alphabetic,
      baseline: fontSize,
      child: Text(
        character,
        style: TextStyle(
          fontFamily: noteFontFamily,
          fontSize: fontSize,
          height: height ?? 0.5,
        ),
      ),
    ),
  );
}

@immutable
class AppInkWell extends StatelessWidget {
  const AppInkWell({super.key, required this.appKeyEnum, this.backgroundColor, this.onTap, this.child, this.value});

  @override
  Widget build(BuildContext context) {
    var key = appKey(appKeyEnum, value: value);

    return InkWell(
      key: key,
      onTap: () {
        appLogKeyCallback(key);
        onTap?.call();
      },
      child: child,
    );
  }

  final AppKeyEnum appKeyEnum;
  final Color? backgroundColor;
  final GestureTapCallback? onTap;
  final Widget? child;
  final dynamic value;
}

IconButton appEnumeratedIconButton({
  required Widget icon,
  required AppKeyEnum appKeyEnum,
  required VoidCallback onPressed, //  insist on action
  Color? color,
  double? iconSize,
}) {
  var key = appKey(appKeyEnum);
  return IconButton(
    icon: icon,
    key: key,
    onPressed: () {
      appLogKeyCallback(key);
      onPressed();
    },
    color: color,
    iconSize: iconSize ?? 24.0, //  demanded by IconButton
  );
}

DropdownButton<T> appDropdownButton<T>(AppKeyEnum appKeyEnum, List<DropdownMenuItem<T>> items,
    {T? value, ValueChanged<T?>? onChanged, Widget? hint, TextStyle? style}) {
  _appKeyRegisterCallback(appKeyEnum, callback: onChanged);
  return DropdownButton<T>(
    key: appKey(appKeyEnum, value: value),
    value: value,
    items: items,
    onChanged: onChanged,
    hint: hint,
    style: style,
    isDense: true,
    iconSize: app.screenInfo.fontSize,
    alignment: Alignment.centerLeft,
    elevation: 8,
    itemHeight: null,
  );
}

DropdownMenuItem<T> appDropdownMenuItem<T>({
  required AppKeyEnum appKeyEnum,
  KeyCallback? keyCallback,
  T? value,
  required Widget child,
}) {
  var key = appKey(appKeyEnum, value: value);

  return DropdownMenuItem<T>(
      key: key,
      onTap: () {
        appLogKeyCallback(key);
        keyCallback?.call();
      },
      value: value,
      enabled: true,
      alignment: AlignmentDirectional.centerStart,
      child: child);
}

FloatingActionButton appFloatingActionButton({
  required AppKeyEnum appKeyEnum,
  required VoidCallback onPressed,
  Widget? child,
  bool mini = false,
}) {
  var key = appKey(appKeyEnum);
  return FloatingActionButton(
    key: key,
    onPressed: () {
      appLogKeyCallback(key);
      onPressed();
    },
    mini: mini,
    backgroundColor: appBackgroundColor,
    heroTag: null,
    child: child, //  workaround in case there are more than one per route.
  );
}

void appTextFieldListener(AppKeyEnum appKeyEnum, TextEditingController controller) {
  logger.d('appLogListener( $appKeyEnum:\'${controller.text}\':${controller.selection} )');
}

Drawer appDrawer({Key? key, required AppKeyEnum appKeyEnum, required Widget child, VoidCallback? voidCallback}) {
  _appKeyRegisterCallback(appKeyEnum, voidCallback: voidCallback);
  logger.log(_logAppKey, 'appDrawer: ');
  return Drawer(key: key ?? appKey(appKeyEnum), child: child);
}

ListTile appListTile({
  required final AppKeyEnum appKeyEnum,
  required String title,
  required final GestureTapCallback? onTap,
  TextStyle? style,
  final bool enabled = true,
}) {
  var key = appKey(appKeyEnum);
  _appKeyRegisterCallback(appKeyEnum, voidCallback: onTap);
  style = style ?? appTextStyle;
  if (!enabled) {
    style == style.copyWith(color: appDisabledColor);
  }
  return ListTile(
    key: key,
    title: Text(title, style: style),
    enabled: enabled,
    onTap: () {
      appLogKeyCallback(key);
      onTap?.call();
    },
  );
}

Switch appSwitch({required AppKeyEnum appKeyEnum, required bool value, required ValueChanged<bool> onChanged}) {
  var key = appKey(appKeyEnum, value: value);
  return Switch(
    key: key,
    value: value,
    onChanged: (value) {
      appLogKeyCallback(key);
      onChanged(value);
    },
  );
}

@immutable
class AppTextField extends StatelessWidget {
  AppTextField({
    super.key,
    required this.appKeyEnum,
    this.controller,
    this.focusNode,
    required this.onChanged,
    this.hintText,
    this.style,
    this.fontSize, //  fixme: overridden by non-null style above
    this.fontWeight,
    this.enabled,
    this.minLines,
    this.maxLines,
    this.border,
    this.width = 200,
  }) : onSubmitted = null {
    _appKeyRegisterCallback(appKeyEnum, callback: onChanged);
  }

  AppTextField.onSubmitted({
    super.key,
    required this.appKeyEnum,
    this.controller,
    this.focusNode,
    required this.onSubmitted,
    this.hintText,
    this.style,
    this.fontSize, //  fixme: overridden by non-null style above
    this.fontWeight,
    this.enabled,
    this.minLines,
    this.maxLines,
    this.border,
    this.width = 200,
  }) : onChanged = null {
    _appKeyRegisterCallback(appKeyEnum, callback: onSubmitted);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        key: appKey(appKeyEnum),
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: (minLines ?? 0) > 1 ? TextInputType.multiline : TextInputType.text,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          border: border,
          // floatingLabelAlignment: FloatingLabelAlignment.start,
          isDense: true,
          contentPadding: const EdgeInsets.all(2.0),
          hintText: hintText,
          hintStyle: style?.copyWith(color: Colors.black54, fontWeight: FontWeight.normal),
        ),
        style: style ?? generateAppTextFieldStyle(fontSize: fontSize, fontWeight: fontWeight ?? FontWeight.normal),
        //(fontSize: fontSize, fontWeight: fontWeight ?? FontWeight.bold),
        autofocus: true,
        maxLength: null,
        minLines: minLines,
        maxLines: maxLines ?? minLines,
      ),
    );
  }

  final AppKeyEnum appKeyEnum;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final TextStyle? style;
  final double? fontSize; //  fixme: overridden by non-null style above
  final FontWeight? fontWeight;
  final bool? enabled;
  final int? minLines;
  final int? maxLines;
  final InputBorder? border;
  final double width;
}

GestureDetector appGestureDetector(
    {required AppKeyEnum appKeyEnum, dynamic value, Widget? child, GestureTapCallback? onTap}) {
  var key = appKey(appKeyEnum, value: value);
  return GestureDetector(
    key: key,
    child: child,
    onTap: () {
      appLogKeyCallback(key);
      onTap?.call();
    },
  );
}

const appFontFamily = 'Roboto';
const noteFontFamily = 'Bravura'; // the music symbols are over sized in the vertical!
const List<String> appFontFamilyFallback = [
  appFontFamily,
  'DejaVu',
  noteFontFamily,
];

/// Creates the app's text style.
///
/// The `package` argument must be non-null if the font family is defined in a
/// package. It is combined with the `fontFamily` argument to set the
/// [fontFamily] property.

TextStyle generateAppTextStyle({
  Color? color,
  Color? backgroundColor,
  String? fontFamily,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  TextBaseline? textBaseline,
  TextDecoration? decoration,
  TextDecorationStyle? decorationStyle,
  bool nullBackground = false,
}) {
  fontSize ??= app.screenInfo.fontSize;
  fontSize = Util.limit(fontSize, appDefaultFontSize, 150.0) as double?;
  return TextStyle(
    color: color ?? _universalForegroundColor,
    //  watch out: backgroundColor interferes with mouse text select on textFields!
    backgroundColor: nullBackground ? null : backgroundColor ?? _universalBackgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight ?? FontWeight.normal,
    fontStyle: fontStyle ?? _universalFontStyle,
    textBaseline: textBaseline,
    fontFamily: fontFamily ?? appFontFamily,
    fontFamilyFallback: appFontFamilyFallback,
    decoration: decoration ?? TextDecoration.none,
    decorationStyle: decorationStyle,
    overflow: TextOverflow.clip,
  );
}

TextStyle generateAppTextFieldStyle({
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  TextBaseline? textBaseline,
  TextDecoration? decoration,
}) {
  return generateAppTextStyle(
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textBaseline: textBaseline,
      decoration: decoration,
      nullBackground: true //  force a null background for mouse text selection
      );
}

TextStyle generateAppBarLinkTextStyle() {
  return generateAppTextStyle(
    fontWeight: FontWeight.bold,
    color: _defaultForegroundColor,
    backgroundColor: Colors.transparent,
  );
}

TextStyle generateAppLinkTextStyle({
  double? fontSize,
}) {
  return generateAppTextStyle(
    color: Colors.blue, //  fixme
    decoration: TextDecoration.underline,
    fontSize: fontSize,
  );
}

TextStyle generateTooltipTextStyle({double? fontSize}) {
  return generateAppTextStyle(
    color: _tooltipColor,
    backgroundColor: _tooltipBackgroundColor,
    fontSize: fontSize,
  );
}

TextStyle generateChordTextStyle(
    {String? fontFamily, double? fontSize, FontWeight? fontWeight, Color? backgroundColor}) {
  return generateAppTextStyle(
    color: _chordNoteColor,
    backgroundColor: backgroundColor ?? _chordNoteBackgroundColor,
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight ?? _chordNoteFontWeight,
    fontStyle: _chordNoteFontStyle,
  );
}

TextStyle generateLyricsTextStyle({double? fontSize, Color? backgroundColor}) {
  return generateAppTextStyle(
    backgroundColor: backgroundColor ?? _universalBackgroundColor,
    fontSize: fontSize,
  );
}

TextStyle generateChordDescriptorTextStyle({double? fontSize, FontWeight? fontWeight, Color? backgroundColor}) {
  return generateAppTextStyle(
    color: _chordDescriptorColor,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight ?? _chordNoteFontWeight,
    fontStyle: _chordNoteFontStyle,
  );
}

TextStyle oddTitleTextStyle({TextStyle? from}) {
  return (from ?? generateAppTextStyle())
      .copyWith(backgroundColor: _oddTitleTextBackgroundColor, color: _oddTitleTextColor);
}

TextStyle evenTitleTextStyle({TextStyle? from}) {
  return (from ?? generateAppTextStyle())
      .copyWith(backgroundColor: _evenTitleTextBackgroundColor, color: _evenTitleTextColor);
}

ThemeData generateDocsThemeData() {
  return ThemeData(
    textTheme: const TextTheme(bodyText2: TextStyle(fontSize: 24.0)),
  );
}

final ThemeData appDocsThemeData = generateDocsThemeData();
