import 'dart:collection';

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/song_base.dart';
import 'package:bsteeleMusicLib/songs/song_metadata.dart';
import 'package:bsteeleMusicLib/songs/song_performance.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';
import 'package:bsteele_music_flutter/util/usTimer.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/*
on linux:
  $XDG_DATA_HOME defines the base directory relative to which user-specific data files should be stored.
  If $XDG_DATA_HOME is either not set or empty, a default equal to $HOME/.local/share should be used.
 */

enum StorageValue {
  //  only partial at the moment
  songMetadata,
  allSongPerformances,
  nashvilleSelection,
  userDisplayStyle,
  drumPartsListJson,
}

/// Application level, persistent, shared values.
class AppOptions extends ChangeNotifier {
  static final AppOptions _singleton = AppOptions._internal();

  factory AppOptions() {
    return _singleton;
  }

  //  private constructor
  AppOptions._internal();

  /// Must be called and waited for prior to appOptions first use!
  /// fixme: this arrangement should be improved!
  Future<void> init() async {
    var usTimer = UsTimer();
    _prefs = await SharedPreferences.getInstance();
    _userDisplayStyle = Util.enumFromString(
            await _readString(StorageValue.userDisplayStyle.name, defaultValue: UserDisplayStyle.both.toString()),
            UserDisplayStyle.values) ??
        UserDisplayStyle.both;
    _nashvilleSelection = Util.enumFromString(
            await _readString(StorageValue.nashvilleSelection.name, defaultValue: NashvilleSelection.off.name),
            NashvilleSelection.values) ??
        NashvilleSelection.off;
    _drumPartsListJson = await _readString(StorageValue.drumPartsListJson.name, defaultValue: '');
    _websocketHost = await _readString('websocketHost', defaultValue: _websocketHost);
    _countIn = await _readBool('countIn', defaultValue: _countIn);
    _dashAllMeasureRepetitions = await _readBool('dashAllMeasureRepetitions', defaultValue: _dashAllMeasureRepetitions);
    _debug = await _readBool('debug', defaultValue: _debug);
    _playWithLineIndicator = await _readBool('playWithLineIndicator', defaultValue: _playWithLineIndicator);
    _playWithMeasureIndicator = await _readBool('playWithMeasureIndicator', defaultValue: _playWithMeasureIndicator);
    _playWithBouncingBall = await _readBool('playWithBouncingBall', defaultValue: _playWithBouncingBall);
    _playWithMeasureLabel = await _readBool('playWithMeasureLabel', defaultValue: _playWithMeasureLabel);
    _alwaysUseTheNewestSongOnRead =
        await _readBool('alwaysUseTheNewestSongOnRead', defaultValue: _alwaysUseTheNewestSongOnRead);
    _playWithChords = await _readBool('playWithChords', defaultValue: _playWithChords);
    _playWithBass = await _readBool('playWithBass', defaultValue: _playWithBass);
    _proEditInput = await _readBool('proEditInput', defaultValue: _proEditInput);
    _compressRepeats = await _readBool('compressRepeats', defaultValue: _compressRepeats);
    _ninJam = await _readBool('ninJam', defaultValue: _ninJam);
    user = await _readString('user', defaultValue: userName);
    _sheetDisplays = sheetDisplaySetDecode(await _readString('sheetDisplays')); // fixme: needs defaultValues?
    _sessionSingers = _stringListDecode(await _readString('sessionSingers'));
    _readSongMetadata();
    _lastAllSongPerformancesStoreMillisecondsSinceEpoch =
        await _readInt('lastAllSongPerformancesStoreMillisecondsSinceEpoch', defaultValue: 0);
    _volume = await _readDouble('volume', defaultValue: 1.0);
    _updateAllSongPerformances();
    notifyListeners();
    logger.v('AppOptions: ${usTimer.seconds} s');
  }

  /// A persistent debug flag for internal software development use.
  bool get debug => _debug;

  set debug(debug) {
    _debug = debug;
    _saveBool('debug', debug);
  }

  Future<bool> _readBool(final String key, {defaultValue = false}) async {
    var value = _prefs.getBool(key) ?? defaultValue;
    notifyListeners();
    return value;
  }

  Future<int> _readInt(final String key, {defaultValue = 0}) async {
    var value = _prefs.getInt(key) ?? defaultValue;
    notifyListeners();
    return value;
  }

  Future<double> _readDouble(final String key, {defaultValue = 0.0}) async {
    var value = _prefs.getDouble(key) ?? defaultValue;
    notifyListeners();
    return value;
  }

  Future<String> _readString(final String key, {defaultValue = ''}) async {
    var value = _prefs.getString(key) ?? defaultValue;
    notifyListeners();
    return value;
  }

  _saveBool(final String key, final bool value) async {
    await _prefs.setBool(key, value);
    notifyListeners();
  }

  _saveInt(final String key, final int value) async {
    await _prefs.setInt(key, value);
    notifyListeners();
  }

  _saveDouble(final String key, final double value) async {
    await _prefs.setDouble(key, value);
    notifyListeners();
  }

  _saveString(final String key, String value) async {
    await _prefs.setString(key, value);
    notifyListeners();
  }

  set countIn(bool countIn) {
    if (_countIn == countIn) return;
    _countIn = countIn;
    _saveBool('countIn', _countIn);
  }

  /// True if the user wants a count in to play a song.
  bool get countIn => _countIn;
  bool _countIn = true;

  set dashAllMeasureRepetitions(bool dashAllMeasureRepetitions) {
    if (_dashAllMeasureRepetitions == dashAllMeasureRepetitions) {
      return;
    }
    _dashAllMeasureRepetitions = dashAllMeasureRepetitions;
    _saveBool('dashAllMeasureRepetitions', _dashAllMeasureRepetitions);
  }

  /// True if the user wants all repeated measures to be displayed with a dash.
  bool get dashAllMeasureRepetitions => _dashAllMeasureRepetitions;
  bool _dashAllMeasureRepetitions = true;

  void setPlayWithLineIndicator(bool playWithLineIndicator) {
    if (_playWithLineIndicator == playWithLineIndicator) {
      return;
    }
    _playWithLineIndicator = playWithLineIndicator;
    _saveBool('playWithLineIndicator', _playWithLineIndicator);
  }

  /// True if the user wants an indicator of the current line while playing.
  bool get playWithLineIndicator => _playWithLineIndicator;
  bool _playWithLineIndicator = true;

  void setPlayWithMeasureIndicator(bool playWithMeasureIndicator) {
    if (_playWithMeasureIndicator == playWithMeasureIndicator) {
      return;
    }
    _playWithMeasureIndicator = playWithMeasureIndicator;
    _saveBool('playWithMeasureIndicator', _playWithMeasureIndicator);
  }

  /// True if the user wants an indicator of the current measure while playing.
  bool get playWithMeasureIndicator => _playWithMeasureIndicator;
  bool _playWithMeasureIndicator = true;

  set playWithBouncingBall(bool playWithBouncingBall) {
    if (_playWithBouncingBall == playWithBouncingBall) {
      return;
    }
    _playWithBouncingBall = playWithBouncingBall;
    _saveBool('playWithBouncingBall', _playWithBouncingBall);
  }

  /// True if the user wants an indicator of the current beat while playing.
  bool get playWithBouncingBall => _playWithBouncingBall;
  bool _playWithBouncingBall = true;

  void setPlayWithMeasureLabel(bool playWithMeasureLabel) {
    if (_playWithMeasureLabel == playWithMeasureLabel) {
      return;
    }
    _playWithMeasureLabel = playWithMeasureLabel;
    _saveBool('playWithMeasureLabel', playWithMeasureLabel);
  }

  /// True if the user wants an expanded label of the current measure while playing.
  bool get playWithMeasureLabel => _playWithMeasureLabel;

  bool _playWithMeasureLabel = true;

  set playWithChords(bool playWithChords) {
    if (_playWithChords == playWithChords) {
      return;
    }
    _playWithChords = playWithChords;
    _saveBool('playWithChords', playWithChords);
  }

  /// True if the user wants the app to play chords when in play mode.
  bool get playWithChords => _playWithChords;
  bool _playWithChords = false;

  set playWithBass(bool playWithBass) {
    if (_playWithBass == playWithBass) {
      return;
    }
    _playWithBass = playWithBass;
    _saveBool('playWithBass', playWithBass);
  }

  /// True if the user wants the app to play bass when in play mode.
  bool get playWithBass => _playWithBass;
  bool _playWithBass = false;

  set proEditInput(bool proEditInput) {
    if (_proEditInput == proEditInput) {
      return;
    }
    _proEditInput = proEditInput;
    _saveBool('proEditInput', proEditInput);
  }

  /// True if the user wants the app to play bass when in play mode.
  bool get proEditInput => _proEditInput;
  bool _proEditInput = false;

  bool get isSinger => _userDisplayStyle == UserDisplayStyle.singer;

  set compressRepeats(bool value) {
    if (_compressRepeats == value) {
      return;
    }
    _compressRepeats = value;
    _saveBool('compressRepeats', value);
  }

  /// True if the user wants repeats to be displayed with the repeat count multiplier.
  /// If false, the fractional display will be shown.
  bool get compressRepeats => _compressRepeats;
  bool _compressRepeats = true;

  set ninJam(bool value) {
    if (_ninJam == value) {
      return;
    }
    _ninJam = value;
    _saveBool('ninJam', value);
  }

  /// True if the user wants NinJam aids shown
  bool get ninJam => _ninJam;
  bool _ninJam = false;

  /// The user's selected style of player display.
  UserDisplayStyle get userDisplayStyle => _userDisplayStyle;
  UserDisplayStyle _userDisplayStyle = UserDisplayStyle.both;

  set userDisplayStyle(UserDisplayStyle value) {
    if (_userDisplayStyle != value) {
      _userDisplayStyle = value;
      _saveString(StorageValue.userDisplayStyle.name, value.name);
    }
  }

  /// The user's drum parts list JSON
  String get drumPartsListJson => _drumPartsListJson;
  String _drumPartsListJson = '';

  set drumPartsListJson(String value) {
    if (_drumPartsListJson != value) {
      _drumPartsListJson = value;
      _saveString(StorageValue.drumPartsListJson.name, value);
    }
  }

  /// The user's selected style of player display.
  NashvilleSelection get nashvilleSelection => _nashvilleSelection;
  NashvilleSelection _nashvilleSelection = NashvilleSelection.off;

  set nashvilleSelection(NashvilleSelection value) {
    if (_nashvilleSelection != value) {
      _nashvilleSelection = value;
      _saveString(StorageValue.nashvilleSelection.name, value.name);
    }
  }

  set websocketHost(String value) {
    if (_websocketHost != value) {
      _websocketHost = value;
      _saveString('websocketHost', value);
    }
  }

  /// The current selected web socket host.
  /// An empty string will indicate the web socket should remain idle.
  String get websocketHost => _websocketHost;
  String _websocketHost = ''; //  initialize idle
  static String idleHost = 'idleHost';

  bool isInThePark() {
    return _websocketHost == parkFixedIpAddress;
  }

  bool _debug = false;

  set alwaysUseTheNewestSongOnRead(bool alwaysUseTheNewestSongOnRead) {
    if (_alwaysUseTheNewestSongOnRead == alwaysUseTheNewestSongOnRead) {
      return;
    }
    _alwaysUseTheNewestSongOnRead = alwaysUseTheNewestSongOnRead;
    _saveBool('alwaysUseTheNewestSongOnRead', _alwaysUseTheNewestSongOnRead);
  }

  /// True if the user wants the most recent song add to replace any existing
  /// song of the same title, artist and cover artist.
  bool get alwaysUseTheNewestSongOnRead => _alwaysUseTheNewestSongOnRead;
  bool _alwaysUseTheNewestSongOnRead = false;

  set user(value) {
    if (_user != value) {
      _user = value;
      _saveString('user', value);
      userName = _user;
    }
  }

  set sheetDisplays(HashSet<SheetDisplay> values) {
    if (_sheetDisplays != values) {
      _sheetDisplays = values;
      _saveString('sheetDisplays', sheetDisplaySetEncode(values));
    }
  }

  void storeAllSongPerformances() {
    String storage = allSongPerformances.toJsonString();
    _saveString(StorageValue.allSongPerformances.name, storage);
    _lastAllSongPerformancesStoreMillisecondsSinceEpoch = DateTime.now().millisecondsSinceEpoch;
  }

  void _updateAllSongPerformances() async {
    var jsonString = await _readString(StorageValue.allSongPerformances.name, defaultValue: '');
    logger.i('_updateAllSongPerformances() length: ${jsonString.length}');
    logger.d('_updateAllSongPerformances(): ${StorageValue.allSongPerformances.name}: $jsonString');
    if (jsonString.isNotEmpty) {
      int count = allSongPerformances.updateFromJsonString(jsonString);
      logger.i('_updateAllSongPerformances() update count: $count');
    }
    logger.d('_readSongMetadata(): SongMetadata: ${SongMetadata.idMetadata}');
  }

  void storeSongMetadata() {
    String storage = SongMetadata.toJson();
    logger.d('storeSongMetadata(): ${StorageValue.songMetadata.name}: $storage');
    _saveString(StorageValue.songMetadata.name, storage);
  }

  void _readSongMetadata() async {
    var jsonString = await _readString(StorageValue.songMetadata.name, defaultValue: '');
    //logger.d('_readSongMetadata(): ${StorageValue.songMetadata.name}: $jsonString');
    if (jsonString.isNotEmpty) {
      SongMetadata.fromJson(jsonString);
    }
    logger.d('_readSongMetadata(): SongMetadata: ${SongMetadata.idMetadata}');
  }

  set sessionSingers(List<String> values) {
    if (!listEquals(_sessionSingers, values)) {
      _sessionSingers = List.from(values);
      _saveString('sessionSingers', _stringListEncode(values));
    }
  }

  List<String> get sessionSingers => List.from(_sessionSingers); //  don't give away a mutable list!

  String _stringListEncode(List<String> strings) {
    StringBuffer ret = StringBuffer();
    var first = true;
    for (var string in strings) {
      if (string.isEmpty) {
        continue;
      }
      if (first) {
        first = false;
      } else {
        ret.write(', ');
      }
      ret.write(string);
    }
    return ret.toString();
  }

  List<String> _stringListDecode(String all) {
    List<String> ret = [];
    for (var string in all.split(', ')) {
      if (string.isNotEmpty) {
        ret.add(string);
      }
    }
    return ret;
  }

  set lastAllSongPerformancesStoreMillisecondsSinceEpoch(int milliseconds) {
    if (_lastAllSongPerformancesStoreMillisecondsSinceEpoch == milliseconds) {
      return;
    }
    _lastAllSongPerformancesStoreMillisecondsSinceEpoch = milliseconds;
    _saveInt('lastAllSongPerformancesStoreMillisecondsSinceEpoch', milliseconds);
  }

  int get lastAllSongPerformancesStoreMillisecondsSinceEpoch => _lastAllSongPerformancesStoreMillisecondsSinceEpoch;
  int _lastAllSongPerformancesStoreMillisecondsSinceEpoch = 0;

  set volume(double volume) {
    if (_volume == volume) {
      return;
    }
    _volume = volume;
    _saveDouble('volume', _volume);
  }

  double get volume => _volume;
  double _volume = 1.0;

  /// A list of the names of sheet music displays that are currently active.
  HashSet<SheetDisplay> get sheetDisplays => _sheetDisplays;
  HashSet<SheetDisplay> _sheetDisplays = HashSet();
  List<String> _sessionSingers = [];

  AllSongPerformances allSongPerformances = AllSongPerformances();

  static const String unknownUser = Song.unknownUser;

  /// The user's application name.
  String get user => _user;
  String _user = userName;

  late final SharedPreferences _prefs;
}
