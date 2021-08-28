import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/appButton.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

const bool _widgetLog = false; //  true false

const _environmentDefault = 'main'; //  fixme: duplicate
const _environment = String.fromEnvironment('environment', defaultValue: _environmentDefault);

final Color appDisabledColor = Colors.grey[400] ?? Colors.grey;
const double appDefaultFontSize = 10.0; //  based on phone

const NameValue allSongsMetadataNameValue = NameValue('all', '');
const NameValue holidayMetadataNameValue = NameValue('christmas', '');

const parkFixedIpAddress = '192.168.1.205'; //  hard, fixed ip address of CJ's park raspberry pi

enum MessageType {
  message,
  warning,
  error,
}

enum CommunityJamsSongList {
  all,
  best,
  ninjam,
  ok,
}

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
  /// A single instance of the screen information class for common use.
  ScreenInfo screenInfo = ScreenInfo.defaultValue(); //  refreshed on main build
  bool isEditReady = false;
  bool isScreenBig = true;
  bool isPhone = false;

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
  void infoMessage(String warning) {
    _messageType = MessageType.warning;
    _message = warning;
  }

  /// Clear all messages to the user
  void clearMessage() {
    _messageType = MessageType.message;
    _message = '';
  }

  set warningMessage(String message) {
    _messageType = MessageType.warning;
    _message = message;
  }

  /// Return the current error message
  String? get error => (_messageType == MessageType.error ? _message : null);

  /// Set an error message
  set error(String? message) {
    _messageType = MessageType.error;
    _message = message ?? '';
  }

  /// Generate a message display widget
  Widget messageTextWidget() {
    return Text(message,
        style: messageType == MessageType.error ? appErrorTextStyle : appWarningTextStyle,
        key: AppKey(AppKeyEnum.errorMessage));
  }

  String get message => _message;
  String _message = '';

  MessageType get messageType => _messageType;
  MessageType _messageType = MessageType.message;

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

  static final App _singleton = App._internal();
}

/// An experimental extension intended to easy widget testing.
extension WidgetLogExtension on Widget {
  void testWidgetLog() {
    logger.i('WidgetLogExtension: $key');
  }
}

/// An experimental class to generate widget test code while running in debug mode.
/// The model is to use the app in debug mode and then copy/paste the generated code
/// into widget tests to replicate the user action with a minimum of coding.
class WidgetLog {
  static void tap(ValueKey<String> key) {
    if (kDebugMode && _widgetLog) {
      if (_environment == _environmentDefault) {
        var varName = Util.firstToLower(Util.underScoresToCamelCase(key.value));
        logger.i('''{
    var $varName = find.byKey(const ValueKey<String>('${key.value}'));
    expect($varName,findsOneWidget);
    await tester.tap($varName);
    await tester.pumpAndSettle();
    }
    ''');
      } else {
        logger.i('tester.tap(${key.value})');
      }
    }
  }
}
