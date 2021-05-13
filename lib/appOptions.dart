// ignore: file_names

import 'package:bsteeleMusicLib/util/util.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserDisplayStyle {
  player,
  singer,
  both,
}

class AppOptions {
  static final AppOptions _singleton = AppOptions._internal();

  factory AppOptions() {
    return _singleton;
  }

  AppOptions._internal();

  Future<void> init() async {
    _userDisplayStyle = Util.enumFromString(
            await _readString('userDisplayStyle', defaultValue: UserDisplayStyle.both.toString()),
            UserDisplayStyle.values) ??
        UserDisplayStyle.both;
    _websocketHost = await _readString('websocketHost', defaultValue: _websocketHost);
    countIn = await _readBool('countIn');
    dashAllMeasureRepetitions = await _readBool('dashAllMeasureRepetitions');
    debug = await _readBool('debug');
    playWithLineIndicator = await _readBool('playWithLineIndicator');
    playWithMeasureIndicator = await _readBool('playWithMeasureIndicator');
    playWithBouncingBall = await _readBool('playWithBouncingBall');
    _playWithMeasureLabel = await _readBool('playWithMeasureLabel');
    alwaysUseTheNewestSongOnRead = await _readBool('alwaysUseTheNewestSongOnRead');
    _playWithChords = await _readBool('playWithChords');
    _playWithBass = await _readBool('playWithBass');
    _holiday = await _readBool('holiday');
    _compressRepeats = await _readBool('compressRepeats');
    _user = await _readString('user');
  }

  bool isCountIn() {
    return countIn;
  }

  void setCountIn(bool countIn) {
    if (this.countIn == countIn) return;
    this.countIn = countIn;
    _saveBool('countIn', countIn);
  }

  bool isDashAllMeasureRepetitions() {
    return dashAllMeasureRepetitions;
  }

  void setDashAllMeasureRepetitions(bool dashAllMeasureRepetitions) {
    if (this.dashAllMeasureRepetitions == dashAllMeasureRepetitions) return;
    this.dashAllMeasureRepetitions = dashAllMeasureRepetitions;
    _saveBool('dashAllMeasureRepetitions', dashAllMeasureRepetitions);
  }

  bool get debug => _debug;

  set debug(debug) {
    _debug = debug;
    _saveBool('debug', debug);
  }

  bool isPlayWithLineIndicator() {
    return playWithLineIndicator;
  }

  void setPlayWithLineIndicator(bool playWithLineIndicator) {
    if (this.playWithLineIndicator == playWithLineIndicator) return;
    this.playWithLineIndicator = playWithLineIndicator;
    _saveBool('playWithLineIndicator', playWithLineIndicator);
  }

  bool isPlayWithMeasureIndicator() {
    return playWithMeasureIndicator;
  }

  void setPlayWithMeasureIndicator(bool playWithMeasureIndicator) {
    if (this.playWithMeasureIndicator == playWithMeasureIndicator) return;
    this.playWithMeasureIndicator = playWithMeasureIndicator;
    _saveBool('playWithMeasureIndicator', playWithMeasureIndicator);
  }

//  String toJson() {
//    StringBuffer sb = new StringBuffer();
//    sb.write("[ ");
//    sb.write("\"countIn\": \"" + jsonEncode(countIn) + "\", ");
//    sb.write("\"dashAllMeasureRepetitions\": \"" +
//        jsonEncode(dashAllMeasureRepetitions) +
//        "\", ");
//    sb.write("\"playWithLineIndicator\": \"" +
//        jsonEncode(playWithLineIndicator) +
//        "\", ");
//    sb.write("\"playWithMeasureIndicator\": \"" +
//        jsonEncode(playWithMeasureIndicator) +
//        "\", ");
//    sb.write("\"playWithBouncingBall\": \"" +
//        jsonEncode(playWithBouncingBall) +
//        "\", ");
//    sb.write("\"playWithMeasureLabel\": \"" +
//        jsonEncode(playWithMeasureLabel) +
//        "\", ");
//    sb.write("\"playerDisplay\": \"" + jsonEncode(playerDisplay) + "\", ");
//    sb.write("\"debug\": \"" + jsonEncode(debug) + "\",");
//    sb.write("\"alwaysUseTheNewestSongOnRead\": \"" +
//        jsonEncode(alwaysUseTheNewestSongOnRead) +
//        "\""); //  no comma at end
//    sb.write(" ]");
//    return sb.toString();
//  }

//  bool _parseBool( String value ){
//      return value.toLowerCase()=='true';
//  }
//
//    void fromJson(String json) {
//    if ( json == null )
//      return;
//
//    final RegExp jsonArrayExp = RegExp(r"^\w*\[(.*)\]\w*$");
//    RegExpMatch mr = jsonArrayExp.firstMatch(json);
//    if (mr != null) {
//      // parse
//      String dataString = mr.group(1);
//      final RegExp commaExp = RegExp(",");    //  fixme: will match commas in data!
//      final RegExp jsonNameValueExp = RegExp("\\s*\"(\\w+)\"\\:\\s*\"(\\w+)\"\\s*");
//      SplitResult splitResult = commaExp.split(dataString, 10);       //  worry about the limit here
//      for (int i = 0; i < splitResult.length(); i++) {
//
//        mr = jsonNameValueExp.firstMatch(splitResult.get(i));
//        if (mr != null) {
//          String name = mr.group(1);
//          bool b;
//          switch (name) {
//            case "countIn":
//              b = _parseBool(mr.group(2));
//              setCountIn(b);
//              break;
//            case "dashAllMeasureRepetitions":
//              setDashAllMeasureRepetitions(_parseBool(mr.group(2)));
//              break;
//            case "playWithLineIndicator":
//              setPlayWithLineIndicator(_parseBool(mr.group(2)));
//              break;
//            case "playWithMeasureIndicator":
//              setPlayWithMeasureIndicator(_parseBool(mr.group(2)));
//              break;
//            case "playWithBouncingBall":
//              setPlayWithBouncingBall(_parseBool(mr.group(2)));
//              break;
//            case "playWithMeasureLabel":
//              setPlayWithMeasureLabel(_parseBool(mr.group(2)));
//              break;
//            case "debug":
//              setDebug(_parseBool(mr.group(2)));
//              break;
//            case "alwaysUseTheNewestSongOnRead":
//              setAlwaysUseTheNewestSongOnRead(_parseBool(mr.group(2)));
//              break;
//          }
//        }
//      }
//    }
//  }

  bool isPlayWithBouncingBall() {
    return playWithBouncingBall;
  }

  void setPlayWithBouncingBall(bool playWithBouncingBall) {
    if (this.playWithBouncingBall == playWithBouncingBall) return;
    this.playWithBouncingBall = playWithBouncingBall;
    _saveBool('playWithBouncingBall', playWithBouncingBall);
  }

  bool get playWithMeasureLabel => _playWithMeasureLabel;

  void setPlayWithMeasureLabel(bool playWithMeasureLabel) {
    if (_playWithMeasureLabel == playWithMeasureLabel) return;
    _playWithMeasureLabel = playWithMeasureLabel;
    _saveBool('playWithMeasureLabel', playWithMeasureLabel);
  }

  bool isAlwaysUseTheNewestSongOnRead() {
    return alwaysUseTheNewestSongOnRead;
  }

  void setAlwaysUseTheNewestSongOnRead(bool alwaysUseTheNewestSongOnRead) {
    if (this.alwaysUseTheNewestSongOnRead == alwaysUseTheNewestSongOnRead) return;
    this.alwaysUseTheNewestSongOnRead = alwaysUseTheNewestSongOnRead;
    _saveBool('alwaysUseTheNewestSongOnRead', alwaysUseTheNewestSongOnRead);
  }

  Future<bool> _readBool(final String key, {defaultValue= false}) async {
    final prefs = await SharedPreferences.getInstance();
    var value = prefs.getBool(key) ?? defaultValue;
    return value;
  }

  Future<String> _readString(final String key, {defaultValue= ''}) async {
    final prefs = await SharedPreferences.getInstance();
    var value = prefs.getString(key) ?? defaultValue;
    return value;
  }

  _saveBool(final String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  _saveString(final String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  set playWithChords(bool playWithChords) {
    if (_playWithChords == playWithChords) return;
    _playWithChords = playWithChords;
    _saveBool('playWithChords', playWithChords);
  }

  set playWithBass(bool playWithBass) {
    if (_playWithBass == playWithBass) return;
    _playWithBass = playWithBass;
    _saveBool('playWithBass', playWithBass);
  }

  bool countIn = true;
  bool dashAllMeasureRepetitions = true;
  bool playWithLineIndicator = true;
  bool playWithMeasureIndicator = true;
  bool playWithBouncingBall = true;
  bool _playWithMeasureLabel = true;

  bool get playWithChords => _playWithChords;
  bool _playWithChords = false;

  bool get playWithBass => _playWithBass;
  bool _playWithBass = false;

  set holiday(bool value) {
    if (_holiday == value) return;
    _holiday = value;
    _saveBool('holiday', value);
  }

  bool get holiday => _holiday;
  bool _holiday = false;

  set userDisplayStyle(UserDisplayStyle value) {
    if (_userDisplayStyle != value) {
      _userDisplayStyle = value;
      _saveString('userDisplayStyle', Util.enumToString(value));
    }
  }

  set compressRepeats(bool value) {
    if (_compressRepeats == value) return;
    _compressRepeats = value;
    _saveBool('compressRepeats', value);
  }
  bool get compressRepeats => _compressRepeats;
  bool _compressRepeats = false;


  UserDisplayStyle get userDisplayStyle => _userDisplayStyle;
  UserDisplayStyle _userDisplayStyle = UserDisplayStyle.both;

  set websocketHost(String value) {
    if (_websocketHost != value) {
      _websocketHost = value;
      _saveString('websocketHost', value);
    }
  }

  String get websocketHost => _websocketHost;
  String _websocketHost = '192.168.1.205';

  bool _debug = false;
  bool alwaysUseTheNewestSongOnRead = false;

  set user(value) {
    if (_user != value) {
      _user = value;
      _saveString('user', value);
    }
  }

  String get user => _user;
  String _user = '';
}
