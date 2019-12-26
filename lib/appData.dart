class AppData {

  String songTitle = "unknown";

  static final AppData _singleton = AppData._internal();

  factory AppData() {
    return _singleton;
  }

  AppData._internal();
}