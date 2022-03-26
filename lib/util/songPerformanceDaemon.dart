import 'dart:async';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:intl/intl.dart' as intl;

import '../app/app.dart';

class SongPerformanceDaemon {
  static final SongPerformanceDaemon _singleton = SongPerformanceDaemon._internal();

  factory SongPerformanceDaemon() {
    return _singleton;
  }

  SongPerformanceDaemon._internal() {
    _initialize();
  }

  void saveAllSongPerformances() {
    _saveSongPerformances('allSongPerformances', _allSongPerformances.toJsonString());
  }

  void saveSingersSongList(String singer) async {
    return _saveSongPerformances('singer_${singer.replaceAll(' ', '_')}', _allSongPerformances.toJsonStringFor(singer));
  }

  void _saveSongPerformances(String prefix, String contents) async {
    String fileName =
        '${prefix}_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}${AllSongPerformances.fileExtension}';
    String message = await UtilWorkaround().writeFileContents(fileName, contents); //  fixme: should be async
    app.infoMessage(message);
  }

  void _initialize() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      _lastStore = _appOptions.lastAllSongPerformancesStoreMillisecondsSinceEpoch;
      Timer.periodic(const Duration(minutes: 10), _timerCallback);
      logger.i('SongPerformanceDaemon initialized');
    } else {
      logger.i('SongPerformanceDaemon skipped');
    }
  }

  _timerCallback(Timer timer) {
    var due = _appOptions.lastAllSongPerformancesStoreMillisecondsSinceEpoch + _updateDelayMilliseconds;

    var dueFormat = intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.fromMillisecondsSinceEpoch(due));
    var nowMs = DateTime.now().millisecondsSinceEpoch;

    if (_lastStore != _appOptions.lastAllSongPerformancesStoreMillisecondsSinceEpoch //  store required
            &&
            nowMs >= due //  been idle long enough
        ) {
      logger.i('SongPerformanceDaemon update: '
          '${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.fromMillisecondsSinceEpoch(nowMs))} > $dueFormat');
      saveAllSongPerformances();
      _appOptions.lastAllSongPerformancesStoreMillisecondsSinceEpoch = nowMs;
      _lastStore = _appOptions.lastAllSongPerformancesStoreMillisecondsSinceEpoch;
    } else {
      logger.i('SongPerformanceDaemon callback: not needed: '
          '${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.fromMillisecondsSinceEpoch(_lastStore))}'
          ', ${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.fromMillisecondsSinceEpoch(nowMs))}'
          ' ${nowMs < due ? '<' : '>'} $dueFormat');
    }
  }

  final int _updateDelayMilliseconds = Duration.millisecondsPerMinute * 30;
  final AllSongPerformances _allSongPerformances = AllSongPerformances();
  final AppOptions _appOptions = AppOptions();
  int _lastStore = 0;
}
