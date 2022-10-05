import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/chordSectionLocation.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/songs/timeSignature.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'app.dart';

const Level _logAppKey = Level.debug;
const Level _logAppKeyCreation = Level.debug;
const Level _logAllRegistrations = Level.debug;
const Level _logAllCallbacks = Level.debug;
const Level _logCallbacks = Level.debug;
const Level _appKeyExecute = Level.info;

TextStyle appDropdownListItemTextStyle = //  fixme: find the right place for this!
    const TextStyle(backgroundColor: Colors.white, color: Colors.black, fontSize: 24); // fixme: shouldn't be fixed

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
  listsMetadataAddToSong(SongIdMetadataItem),
  listsNameClear(Null),
  listsNameEntry(String),
  listsRadio(Null),
  listsReadLists(Null),
  listsSaveCSV(Null),
  listsSave(Null),
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
  mainDrawerAbout(Null),
  mainDrawerCssDemo(Null),
  mainDrawerDebug(Null),
  mainDrawerDocs(Null),
  mainDrawerLists(Null),
  mainDrawerNewSong(Null),
  mainDrawer(Null),
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
  optionsFullScreen(Null),
  optionsLeadership(Null),
  optionsNashville(NashvilleSelection),
  optionsNinJam(bool),
  optionsUserDisplayStyle(String), //fixme
  optionsUserName(String),
  optionsWebsocketBob(Null),
  optionsWebsocketCJ(Null),
  optionsWebsocketIP(String),
  optionsWebsocketNone(Null),
  optionsWebsocketPark(Null),
  optionsWebsocketThisHost(Null),
  performanceHistoryBack(Null),
  performanceHistoryErrorMessage(Null),
  playerBack(Null),
  playerBPM(int),
  playerCapo(bool),
  playerCapoLabel(bool),
  playerCompressRepeats(bool),
  playerCompressRepeatsToggle(bool),
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
  playListClearSearch(Null),
  playListFilter(NameValue),
  playListMetadataRemoveFromFilter(NameValue),
  playListMetadataRemoveFromSong(SongIdMetadataItem),
  playListSearch(String),
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
  singersActiveSingers(String),
  singersAddSingerToSession(String),
  singersAllSingers(String),
  singersBack(Null),
  singersCancelDeleteSinger(Null),
  singersClearRequestedSearch(Null),
  singersDeleteSingerConfirmation(Null),
  singersDeleteSinger(Null),
  singersErrorMessage(Null),
  singersFullScreen(Null),
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
  singersShowOtherActions(Null),
  singersSingerClearSearch(Null),
  singersSingerSearchText(String),
  singersSinging(bool),
  singersSingingTextButton(String),
  singersSortTypeSelection(String),
  singersVolunteerSingerSelectClear(Null),
  singersVolunteerSingerSelect(String),
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

class SongIdMetadataItem {
  SongIdMetadataItem(Song song, this.nameValue) : songIdString = song.songId.toString();

  SongIdMetadataItem.byIdString(this.songIdString, this.nameValue);

  @override
  String toString() {
    return '$songIdString.${nameValue.name}:${nameValue.value}';
  }

  static SongIdMetadataItem? parse(String s) {
    var m = regexp.firstMatch(s);
    if (m != null) {
      return SongIdMetadataItem.byIdString(m.group(1)!, NameValue(m.group(2)!, m.group(3)!));
    }
    return null;
  }

  final String songIdString;
  final NameValue nameValue;
  static final regexp = RegExp(r'^([^.]+)\.(\w+):(\w+)$');
}

class AppKey extends ValueKey<String> implements Comparable<AppKey> {
  const AppKey(String s) : super(s);

  @override
  String toString() {
    return value;
  }

  @override
  int compareTo(AppKey other) {
    return value.compareTo(other.value);
  }
}

/// Generate an application key from the enumeration and an optional value
AppKey appKeyCreate(AppKeyEnum e, {dynamic value}) {
  AppKey ret;
  var type = e.argType;
  switch (type) {
    case Null:
      assert(value == null);
      ret = AppKey(e.name);
      break;
    case String:
      ret = AppKey(e.name); //  value is entry
      break;
    case music_key.Key:
      assert(value.runtimeType == type);
      ret = AppKey('${e.name}.${(value as music_key.Key).toMarkup()}');
      break;
    case NameValue:
      ret = AppKey('${e.name}.${(value as NameValue).toShortString()}');
      break;
    default:
      if (value.runtimeType != type) {
        logger.e('appKey(): $e.value.runtimeType = ${value.runtimeType} != $type');
        assert(value.runtimeType == type);
      }
      if (value is Enum) {
        ret = AppKey('${e.name}.${value.name}');
      } else {
        ret = AppKey('${e.name}.${value.toString()}');
      }
      break;
  }
  logger.log(_logAppKeyCreation, 'appKey($e, value: $value) = $ret');
  return ret;
}

//  the weakly typed storage here is strongly enforced by the strongly typed construction of the registration
//  i.e. by the app key enum argument type
//  fixme: should be cleared on page change
Map<AppKey, Function> _appKeyRegisterCallbacks = {};

appKeyCallbacksClear() {
  logger.log(_logAppKey, 'appKeyCallbacksClear: ');
  _appKeyRegisterCallbacks.clear(); //  can't run callbacks if the widget tree is now gone
}

_appKeyCallbacksDebugLog() {
  logger.log(_logAppKey, '_appKeyCallbacksDebugLog: ${_appKeyRegisterCallbacks.length}');
  for (var k in SplayTreeSet<AppKey>()..addAll(_appKeyRegisterCallbacks.keys)) {
    logger.log(_logAllCallbacks, '  registered $k: ${_appKeyRegisterCallbacks[k].runtimeType}');
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
  SongIdMetadataItem: (s) => SongIdMetadataItem.parse(s),
  TimeSignature: (s) => TimeSignature.parse(s),
  NameValue: (s) => NameValue.parse(s),
};

void _appKeyRegisterVoidCallback(AppKey key, {VoidCallback? voidCallback}) {
  if (!kDebugMode) //fixme: temp
  {
    return;
  }
  if (voidCallback != null) {
    _appKeyRegisterCallbacks[key] = () {
      _appLogCallback(key);
      voidCallback.call();
    };
  }
  logger.log(_logAllRegistrations, '_appKeyRegisterVoidCallback($key, $voidCallback)');
}

void _appKeyRegisterCallback<T>(AppKey key, {ValueChanged<T>? callback}) {
  if (!kDebugMode) //fixme: temp
  {
    return;
  }
  if (callback != null) {
    _appKeyRegisterCallbacks[key] = (value) {
      _appLogCallback(key);
      callback.call(value);
    };
  }
  logger.log(_logAllRegistrations, '_appKeyRegisterCallback($key, $callback)');
}

Map<String, AppKeyEnum>? _appKeyEnumLookupMap;

Future<bool> appKeyExecute(final String logString, {final Duration? delay}) async {
  //  lazy eval up type lookup
  if (_appKeyEnumLookupMap == null) {
    _appKeyEnumLookupMap = {};
    for (var e in AppKeyEnum.values) {
      _appKeyEnumLookupMap![e.name] = e;
      //  assure that we can convert everything
      //  fixme: should be done at compile time
      //logger.i('  test type for $e: ${e.argType}');
      assert(_appKeyParsers[e.argType] != null);
    }
  }

  final cmds = logString.split('\n');
  logger.i('cmds: $cmds');
  for (var cmd in cmds) {
    //logger.i('cmd: "$cmd"');
    if (cmd.isEmpty) {
      continue;
    }
    //  find the app key and value string... if it exists
    String? eString;
    String? valueString;
    var m = _appKeyLogRegexp.firstMatch(cmd);
    if (m != null) {
      eString = m.group(1);
      if (m.groupCount >= 2) {
        valueString = m.group(2); //  may be null!
      }
    }
    logger.log(
        _appKeyExecute,
        '     _appKeyExecute: eString: "$eString"'
        ', value: "$valueString", from: ${_appKeyRegisterCallbacks.length}  '
        'callbacks');

    // //  execute the app key
    // if (eString != null) {
    //   var e = _appKeyEnumLookupMap![eString];
    //   if (e != null) {
    //     var key = appKeyCreate(e, value: valueString == null ? null : _appKeyParsers[e.argType]!.call(valueString));
    //     var callback = _appKeyRegisterCallbacks[key];
    //     if (callback != null) {
    //       try {
    //         if (e.argType == Null) {
    //           if (callback is VoidCallback) {
    //             assert(valueString == null);
    //             _appLogCallback(appKeyCreate(e));
    //             logger.log(_logAppKey, '$e: VoidCallback');
    //             callback.call();
    //           } else {
    //             logger.w('non-null callback for null argType: $e');
    //             return false;
    //           }
    //         } else if (e.argType == String) {
    //           //  an optimization
    //           assert(valueString != null);
    //           if (e.argType == String) {
    //             _appLogCallback(appKeyCreate(e, value: valueString));
    //             logger.log(_logAppKey, '$e ${e.argType}.$valueString => "$valueString"');
    //             Function.apply(callback, [valueString]);
    //           }
    //         } else {
    //           //  parse string to correct value type
    //           var value = _appKeyParsers[e.argType]?.call(valueString!);
    //           logger.log(_logAppKey, '$e ${e.argType}.$valueString => $value');
    //           if (callback is VoidCallback) {
    //             callback.call();
    //           } else {
    //             callback.call(value);
    //           }
    //         }
    //       } catch (ex) {
    //         logger.w('callback threw exception: $ex');
    //         return false;
    //       }
    //     } else {
    //       logger.w('callback not found registered for: $key');
    //       callback = _appKeyRegisterCallbacks[appKeyCreate(e)];
    //       logger.w('callback for $e: $callback');
    //       _appKeyCallbacksDebugLog();
    //       return false;
    //     }
    //   } else {
    //     logger.w('appKeyEnum not found: "$eString"');
    //     return false;
    //   }
    // } else {
    //   logger.w('appKeyEnum not found in logString: "$cmd"');
    //   return false;
    // }
    //await Future.delayed(delay ?? const Duration(milliseconds: 16));
  }
  logger.i('appKeyExecute: ended');
  return true;
}

final _appKeyLogRegexp = RegExp(r'^\s*([^.]*)(?:\.?(.+?))?$'); // second group may be null!

void _testSearchFor(Song song) async {
  appKeyExecute('''${AppKeyEnum.playListClearSearch.name}
playListSearch.${song.title}
''');
}

void testAppKeyCallbacks() async {
  if (!kDebugMode) //fixme: temp
  {
    logger.log(_logAppKey, 'debugLoggerAppKeyRegisterCallbacks:  NOT DEBUG');
    return;
  }
  const delay = Duration(seconds: 1);

  {
    int count = 0;
    for (var song in app.allSongs) {
      logger.i('test: $song');
      if (++count > 1) {
        break;
      }
      _testSearchFor(song);
      appKeyExecute('''
playerKeyDown
playerKeyDown
playerKeyDown
playerKeyDown
playerKeyUp
playerKeyUp
appBack
''', delay: delay);
    }
  }

  // //  fixme: sample only
  // logger.log(_logAppKey, 'testAppKeyCallbacks:');
  //
  // //logger.log(_logAppKey,'appKeyExecute: mainSortType.byComplexity: ${appKeyExecute('mainSortType.byComplexity')}');
  // // setState() called after dispose():
  // _appKeyCallbacksDebugLog();
  // logger.log(_logAppKey, 'appKeyExecute: mainDrawer: ${appKeyExecute('mainDrawer')}');
  // await Future.delayed(const Duration(seconds: 1));
  // _appKeyCallbacksDebugLog();
  //
  // logger.log(_logAppKey, 'appKeyExecute: mainDrawerOptions: ${appKeyExecute('mainDrawerOptions')}');
  // await Future.delayed(const Duration(seconds: 1));
  // logger.log(_logAppKey, 'appKeyExecute: optionsWebsocketBob: ${appKeyExecute('optionsWebsocketBob')}');
  // await Future.delayed(const Duration(seconds: 1));
  // logger.log(_logAppKey, 'appKeyExecute: optionsUserName.myfirst: ${appKeyExecute('optionsUserName.myfirst')}');
  // await Future.delayed(const Duration(seconds: 1));
  //
  // AppKeyEnum e = AppKeyEnum.appBack;
  // logger.log(_logAppKey, 'appKeyExecute: $e: ${appKeyExecute(e.name)}');
  //
  // // await Future.delayed(const Duration(seconds: 8));
  // // logger.log(_logAppKey,'appKeyExecute: optionsUserName.bobstuff: ${appKeyExecute('optionsUserName.bobstuff')}');
  // await Future.delayed(const Duration(seconds: 4));
  // logger.log(_logAppKey, 'appKeyExecute: done');
  //
  // // logger.log(_logAppKey,'appKeyExecute: playerMusicKey.Eb: ${appKeyExecute('playerMusicKey.Eb')}');
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
      color: color ?? App.iconColor,
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
      var elevatedButtonThemeStyle = app.themeData.elevatedButtonTheme.style ??
          ButtonStyle(
              foregroundColor: MaterialStateProperty.all(App.defaultForegroundColor),
              backgroundColor: MaterialStateProperty.all(App.defaultBackgroundColor));
      elevatedButtonThemeStyle = elevatedButtonThemeStyle.copyWith(elevation: MaterialStateProperty.all(6));

      //  hassle with mapping Color to MaterialColor
      var color = App.appbarBackgroundColor;
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
      color = App.universalBackgroundColor;

      app.themeData = app.themeData.copyWith(
        backgroundColor: color,
        primaryColor: color,
        disabledColor: Colors.grey.shade300,
        elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonThemeStyle),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: materialColor, accentColor: App.universalAccentColor),
      );
    }
  }
}

List<String> _appLog = [];

List<String> get appLog => _appLog;

//  log in invocation of the callback being done
void _appLogCallback(AppKey key) {
  logger.log(_logCallbacks, '_appLogCallback: $key');
  _appLog.add(key.value);
}

int _lastMessageEpochUs = DateTime.now().microsecondsSinceEpoch;

void appLogMessage(String message) {
  var t = DateTime.now();
  var duration = Duration(microseconds: t.microsecondsSinceEpoch - _lastMessageEpochUs);
  _lastMessageEpochUs = t.microsecondsSinceEpoch;
  _appLog.add('// $t +$duration: $message');
}

ElevatedButton appButton(
  String commandName, {
  required AppKeyEnum appKeyEnum,
  required final VoidCallback? onPressed,
  final Color? backgroundColor,
  final double? fontSize,
  final dynamic value,
}) {
  var key = appKeyCreate(appKeyEnum, value: value);
  var voidCallback = onPressed == null
      ? null //  show as disabled   //  fixme: does this work?
      : () {
          _appLogCallback(key); //  log the click
          onPressed.call();
        };
  _appKeyRegisterVoidCallback(key, voidCallback: voidCallback);

  return ElevatedButton(
    key: key,
    clipBehavior: Clip.hardEdge,
    onPressed: voidCallback,
    style:
        app.themeData.elevatedButtonTheme.style?.copyWith(backgroundColor: MaterialStateProperty.all(backgroundColor)),
    child: Text(commandName,
        style: TextStyle(fontSize: fontSize ?? app.screenInfo.fontSize, backgroundColor: backgroundColor)),
  );
}

TextButton appTextButton(
  String text, {
  required AppKeyEnum appKeyEnum,
  required VoidCallback? onPressed,
  TextStyle? style,
  dynamic value,
}) {
  var key = appKeyCreate(appKeyEnum, value: value ?? text);
  _appKeyRegisterVoidCallback(key, voidCallback: onPressed);
  return TextButton(
    key: key,
    onPressed: () {
      _appLogCallback(key);
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
  var key = appKeyCreate(appKeyEnum, value: value);
  _appKeyRegisterVoidCallback(key, voidCallback: onPressed);
  return TextButton.icon(
    key: key,
    icon: icon,
    label: Text(label ?? '', style: style ?? TextStyle(fontSize: fontSize)),
    onPressed: () {
      _appLogCallback(key);
      onPressed();
    },
    style: app.themeData.elevatedButtonTheme.style
        ?.copyWith(backgroundColor: MaterialStateProperty.all(backgroundColor ?? App.defaultBackgroundColor)),
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
  var key = appKeyCreate(appKeyEnum, value: value);
  _appKeyRegisterVoidCallback(key, voidCallback: onPressed);

  fontSize = 30;

  return ElevatedButton(
    key: key,
    onPressed: onPressed == null
        ? null //  show as disabled
        : () {
            _appLogCallback(key); //  log the click
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
  AppInkWell({super.key, required this.appKeyEnum, this.backgroundColor, this.onTap, this.child, this.value})
      : appKey = appKeyCreate(appKeyEnum, value: value) {
    _appKeyRegisterVoidCallback(appKey, voidCallback: onTap);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: appKey,
      onTap: () {
        _appLogCallback(appKey);
        onTap?.call();
      },
      child: child,
    );
  }

  final AppKeyEnum appKeyEnum;
  final AppKey appKey;
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
  var key = appKeyCreate(appKeyEnum);
  _appKeyRegisterVoidCallback(key, voidCallback: onPressed);
  return IconButton(
    icon: icon,
    key: key,
    onPressed: () {
      _appLogCallback(key);
      onPressed();
    },
    color: color,
    iconSize: iconSize ?? 24.0, //  demanded by IconButton
  );
}

DropdownButton<T> appDropdownButton<T>(
  AppKeyEnum appKeyEnum,
  List<DropdownMenuItem<T>> items, {
  T? value,
  ValueChanged<T?>? onChanged,
  Widget? hint,
  TextStyle? style,
}) {
  AppKey key = appKeyCreate(appKeyEnum, value: value);
  _appKeyRegisterCallback(key, callback: onChanged);
  return DropdownButton<T>(
    key: key,
    value: value,
    items: items,
    onChanged: (value) {
      _appLogCallback(key);
      onChanged?.call(value);
    },
    hint: hint,
    style: style,
    isDense: true,
    iconSize: app.screenInfo.fontSize,
    alignment: Alignment.centerLeft,
    elevation: 8,
    itemHeight: null,
  );
}

//  note: the call back is on the appDropdownButton that is given the value from here
DropdownMenuItem<T> appDropdownMenuItem<T>({
  required AppKeyEnum appKeyEnum,
  required T value,
  required Widget child,
}) {
  var key = appKeyCreate(appKeyEnum, value: value);
  return DropdownMenuItem<T>(
      key: key, value: value, enabled: true, alignment: AlignmentDirectional.centerStart, child: child);
}

FloatingActionButton appFloatingActionButton({
  required AppKeyEnum appKeyEnum,
  required VoidCallback onPressed,
  Widget? child,
  bool mini = false,
}) {
  var key = appKeyCreate(appKeyEnum);
  _appKeyRegisterVoidCallback(key, voidCallback: onPressed);
  return FloatingActionButton(
    key: key,
    onPressed: () {
      _appLogCallback(key);
      onPressed();
    },
    mini: mini,
    backgroundColor: App.appBackgroundColor,
    heroTag: null,
    child: child, //  workaround in case there are more than one per route.
  );
}

void appTextFieldListener(AppKeyEnum appKeyEnum, TextEditingController controller) {
  logger.d('appLogListener( $appKeyEnum:\'${controller.text}\':${controller.selection} )');
}

Drawer appDrawer({required AppKeyEnum appKeyEnum, required Widget child, VoidCallback? voidCallback}) {
  var key = appKeyCreate(appKeyEnum);
  _appKeyRegisterVoidCallback(key, voidCallback: voidCallback);
  logger.log(_logAppKey, 'appDrawer: ');
  return Drawer(key: key, child: child);
}

ListTile appListTile({
  required final AppKeyEnum appKeyEnum,
  required String title,
  required final GestureTapCallback? onTap,
  TextStyle? style,
  final bool enabled = true,
}) {
  var key = appKeyCreate(appKeyEnum);
  _appKeyRegisterVoidCallback(key, voidCallback: onTap);
  style = style ?? appTextStyle;
  if (!enabled) {
    style == style.copyWith(color: appDisabledColor);
  }
  return ListTile(
    key: key,
    title: Text(title, style: style),
    enabled: enabled,
    onTap: () {
      _appLogCallback(key);
      onTap?.call();
    },
  );
}

Switch appSwitch({required AppKeyEnum appKeyEnum, required bool value, required ValueChanged<bool> onChanged}) {
  var key = appKeyCreate(appKeyEnum, value: value);
  _appKeyRegisterCallback(key, callback: onChanged);
  return Switch(
    key: key,
    value: value,
    onChanged: (value) {
      _appLogCallback(key);
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
  })  : onSubmitted = null,
        appKey = appKeyCreate(appKeyEnum) {
    _appKeyRegisterCallback(appKey, callback: onChanged);
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
  })  : onChanged = null,
        appKey = appKeyCreate(appKeyEnum) {
    _appKeyRegisterCallback(appKey, callback: onSubmitted);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        key: appKey,
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
  final AppKey appKey;
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

// GestureDetector appGestureDetector(  //  fixme: install!
//     {required AppKeyEnum appKeyEnum, dynamic value, Widget? child, GestureTapCallback? onTap}) {
//   var key = appKey(appKeyEnum, value: value);
//   _appKeyRegisterCallback(key,callback: onTap);
//   return GestureDetector(
//     key: key,
//     child: child,
//     onTap: () {
//       appLogKeyCallback(key);
//       onTap?.call();
//     },
//   );
// }

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
    color: color ?? App.universalForegroundColor,
    //  watch out: backgroundColor interferes with mouse text select on textFields!
    backgroundColor: nullBackground ? null : backgroundColor ?? App.universalBackgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight ?? FontWeight.normal,
    fontStyle: fontStyle ?? App.universalFontStyle,
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
    color: App.defaultForegroundColor,
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
    color: App.tooltipColor,
    backgroundColor: App.tooltipBackgroundColor,
    fontSize: fontSize,
  );
}

TextStyle generateChordTextStyle(
    {String? fontFamily, double? fontSize, FontWeight? fontWeight, Color? backgroundColor}) {
  return generateAppTextStyle(
    color: App.chordNoteColor,
    backgroundColor: backgroundColor ?? App.chordNoteBackgroundColor,
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight ?? App.chordNoteFontWeight,
    fontStyle: App.chordNoteFontStyle,
  );
}

TextStyle generateLyricsTextStyle({double? fontSize, Color? backgroundColor}) {
  return generateAppTextStyle(
    backgroundColor: backgroundColor ?? App.universalBackgroundColor,
    fontSize: fontSize,
  );
}

TextStyle generateChordDescriptorTextStyle({double? fontSize, FontWeight? fontWeight, Color? backgroundColor}) {
  return generateAppTextStyle(
    color: App.chordDescriptorColor,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight ?? App.chordNoteFontWeight,
    fontStyle: App.chordNoteFontStyle,
  );
}

TextStyle oddTitleTextStyle({TextStyle? from}) {
  return (from ?? generateAppTextStyle())
      .copyWith(backgroundColor: App.oddTitleTextBackgroundColor, color: App.oddTitleTextColor);
}

TextStyle evenTitleTextStyle({TextStyle? from}) {
  return (from ?? generateAppTextStyle())
      .copyWith(backgroundColor: App.evenTitleTextBackgroundColor, color: App.evenTitleTextColor);
}

ThemeData generateDocsThemeData() {
  return ThemeData(
    textTheme: const TextTheme(bodyText2: TextStyle(fontSize: 24.0)),
  );
}

final ThemeData appDocsThemeData = generateDocsThemeData();
