import 'dart:convert';

class AppOptions {

  static final AppOptions _singleton = AppOptions._internal();

  factory AppOptions() {
    return _singleton;
  }

  AppOptions._internal();

    bool isCountIn() {
    return countIn;
  }

    void setCountIn(bool countIn) {
    this.countIn = countIn;
    save();
  }

    bool isDashAllMeasureRepetitions() {
    return dashAllMeasureRepetitions;
  }

    void setDashAllMeasureRepetitions(bool dashAllMeasureRepetitions) {
    this.dashAllMeasureRepetitions = dashAllMeasureRepetitions;
    save();
  }

    bool isDebug() {
    return debug;
  }

    void setDebug(bool debug) {
    this.debug = debug;
    save();
  }


    bool isPlayWithLineIndicator() {
    return playWithLineIndicator;
  }

    void setPlayWithLineIndicator(bool playWithLineIndicator) {
    this.playWithLineIndicator = playWithLineIndicator;
    save();
  }

    bool isPlayWithMeasureIndicator() {
    return playWithMeasureIndicator;
  }

    void setPlayWithMeasureIndicator(bool playWithMeasureIndicator) {
    this.playWithMeasureIndicator = playWithMeasureIndicator;
    save();
  }

    String toJson() {
    StringBuffer sb = new StringBuffer();
    sb.write("[ ");
    sb.write("\"countIn\": \"" + jsonEncode(countIn) + "\", ");
    sb.write("\"dashAllMeasureRepetitions\": \"" + jsonEncode(dashAllMeasureRepetitions) + "\", ");
    sb.write("\"playWithLineIndicator\": \"" + jsonEncode(playWithLineIndicator )+ "\", ");
    sb.write("\"playWithMeasureIndicator\": \"" + jsonEncode(playWithMeasureIndicator )+ "\", ");
    sb.write("\"playWithBouncingBall\": \"" + jsonEncode(playWithBouncingBall )+ "\", ");
    sb.write("\"playWithMeasureLabel\": \"" + jsonEncode(playWithMeasureLabel) + "\", ");
    sb.write("\"debug\": \"" + jsonEncode(debug) + "\",");
    sb.write("\"alwaysUseTheNewestSongOnRead\": \"" + jsonEncode(alwaysUseTheNewestSongOnRead) + "\"");      //  no comma at end
    sb.write(" ]");
    return sb.toString();
  }
  
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
//
//    void registerSaveCallback(SaveCallback saveCallback) {
//    this.saveCallback = saveCallback;
//  }

    void save() {
//    if (saveCallback != null)
//      saveCallback.save();
  }

    bool isPlayWithBouncingBall() {
    return playWithBouncingBall;
  }

    void setPlayWithBouncingBall(bool playWithBouncingBall) {
    this.playWithBouncingBall = playWithBouncingBall;
    save();
  }

    bool isPlayWithMeasureLabel() {
    return playWithMeasureLabel;
  }

    void setPlayWithMeasureLabel(bool playWithMeasureLabel) {
    this.playWithMeasureLabel = playWithMeasureLabel;
    save();
  }

    bool isAlwaysUseTheNewestSongOnRead() {
    return alwaysUseTheNewestSongOnRead;
  }

    void setAlwaysUseTheNewestSongOnRead(bool alwaysUseTheNewestSongOnRead) {
    this.alwaysUseTheNewestSongOnRead = alwaysUseTheNewestSongOnRead;
    save();
  }

  bool countIn = true;
  bool dashAllMeasureRepetitions = true;
  bool playWithLineIndicator = true;
  bool playWithMeasureIndicator = true;
  bool playWithBouncingBall = true;
  bool playWithMeasureLabel = true;
  bool debug = false;
  bool alwaysUseTheNewestSongOnRead = false;

//  logger doesn't seem appropriate here    static final Logger logger = Logger.getLogger(AppOptions.class.getName());
}
