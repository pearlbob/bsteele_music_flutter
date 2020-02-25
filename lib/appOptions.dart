import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppOptions {
  static final AppOptions _singleton = AppOptions._internal();

  factory AppOptions() {
    return _singleton;
  }

  AppOptions._internal();

  Future<void> init() async {
    _playerDisplay = await _readBool('playerDisplay', defaultValue: true);
    countIn = await _readBool('countIn');
    dashAllMeasureRepetitions = await _readBool('dashAllMeasureRepetitions');
    dashAllMeasureRepetitions = await _readBool('dashAllMeasureRepetitions');
    debug = await _readBool('debug');
    playWithLineIndicator = await _readBool('playWithLineIndicator');
    playWithMeasureIndicator = await _readBool('playWithMeasureIndicator');
    playWithBouncingBall = await _readBool('playWithBouncingBall');
    playWithMeasureLabel = await _readBool('playWithMeasureLabel');
    alwaysUseTheNewestSongOnRead = await _readBool('alwaysUseTheNewestSongOnRead');

    logger.i('readOptions: playerDisplay: $playerDisplay');
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

  bool isPlayWithMeasureLabel() {
    return playWithMeasureLabel;
  }

  void setPlayWithMeasureLabel(bool playWithMeasureLabel) {
    if (this.playWithMeasureLabel == playWithMeasureLabel) return;
    this.playWithMeasureLabel = playWithMeasureLabel;
    _saveBool('playWithMeasureLabel', playWithMeasureLabel);
  }

  bool isAlwaysUseTheNewestSongOnRead() {
    return alwaysUseTheNewestSongOnRead;
  }

  void setAlwaysUseTheNewestSongOnRead(bool alwaysUseTheNewestSongOnRead) {
    if (this.alwaysUseTheNewestSongOnRead == alwaysUseTheNewestSongOnRead)
      return;
    this.alwaysUseTheNewestSongOnRead = alwaysUseTheNewestSongOnRead;
    _saveBool('alwaysUseTheNewestSongOnRead', alwaysUseTheNewestSongOnRead);
  }

  dynamic _readBool(final String key, {defaultValue: false}) async {
    final prefs = await SharedPreferences.getInstance();
    bool value = prefs.getBool(key) ?? defaultValue;
    return value;
  }

  _saveBool(final String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(key, value);
  }

  bool countIn = true;
  bool dashAllMeasureRepetitions = true;
  bool playWithLineIndicator = true;
  bool playWithMeasureIndicator = true;
  bool playWithBouncingBall = true;
  bool playWithMeasureLabel = true;

  set playerDisplay(value) {
    if (_playerDisplay == value)
    return;

      _playerDisplay = value;
      _saveBool('playerDisplay', value);
      logger.v('set playerDisplay: $value');
  }

  bool get playerDisplay => _playerDisplay;
  bool _playerDisplay = true;

  bool _debug = false;
  bool alwaysUseTheNewestSongOnRead = false;
}
