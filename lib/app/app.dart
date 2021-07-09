import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const bool _widgetLog = false;

const _environmentDefault = 'main'; //  fixme: duplicate
const _environment = String.fromEnvironment('environment', defaultValue: _environmentDefault);

const Color appDefaultColor = Color(0xFF4FC3F7); //Color(0xFFB3E5FC);
const double appDefaultFontSize = 10.0; //  based on phone

enum MessageType {
  message,
  warning,
  error,
}

/// application shared values
class App {
  factory App() {
    return _singleton;
  }

  App._internal();

  //  parameters to be evaluated before use
  ScreenInfo screenInfo = ScreenInfo.defaultValue(); //  refreshed on main build
  bool isEditReady = false;
  bool isScreenBig = true;
  bool isPhone = false;

  void addSong(Song song) {
    logger.v('addSong( ${song.toString()} )');
    _allSongs.remove(song); // any prior version of same song
    _allSongs.add(song);
    _filteredSongs.clear();
    selectedSong = song;
  }

  void addSongs(List<Song> songs) {
    for (var song in songs) {
      addSong(song);
    }
  }

  void removeAllSongs() {
    _allSongs.clear();
    _filteredSongs.clear();
    selectedSong = _emptySong;
  }

  void messageClear() {
    message = '';
  }

  set message(String message) {
    _messageType = MessageType.message;
    _message = message;
  }

  set warning(String message) {
    _messageType = MessageType.warning;
    _message = message;
  }

  String? get error => (_messageType == MessageType.error ? _message : null);

  set error(String? message) {
    _messageType = MessageType.error;
    _message = message ?? '';
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

void widgetLog(ValueKey<String> key) {
  if (kDebugMode && _widgetLog ) {
    if (_environment == _environmentDefault) {
      var varName = Util.firstToLower(Util.underScoresToCamelCase(key.value));
      logger.i( '''{
    var $varName = find.byKey(const ValueKey<String>('${key.value}'));
    expect($varName,findsOneWidget);
    await tester.tap($varName);
    await tester.pumpAndSettle();
    }
    ''');
    } else {
      logger.i( 'tester.tap(${key.value})');
    }
  }
}
