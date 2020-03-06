import 'songPickStub.dart'
// ignore: uri_does_not_exist
    if (dart.library.io) 'package:bsteele_music_flutter/util/songPickPhone.dart'
// ignore: uri_does_not_exist
    if (dart.library.html) 'package:bsteele_music_flutter/util/songPickWeb.dart';

abstract class SongPick {
  Future<void> filePick() { return null; }

  /// factory constructor to return the correct implementation.
  factory SongPick() => getSongPick();
}
