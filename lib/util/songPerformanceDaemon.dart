import 'dart:async';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' as intl;
import 'package:universal_io/io.dart';

import '../app/app.dart';

class SongPerformanceDaemon {
  static final SongPerformanceDaemon _singleton = SongPerformanceDaemon._internal();

  factory SongPerformanceDaemon() {
    return _singleton;
  }

  SongPerformanceDaemon._internal() {
    _initialize();
  }

  Future<void> saveAllSongPerformances() {
    return _saveSongPerformances('allSongPerformances', _allSongPerformances.toJsonString());
  }

  Future<void> saveSingersSongList(String singer) {
    return _saveSongPerformances('singer_${singer.replaceAll(' ', '_')}', _allSongPerformances.toJsonStringFor(singer));
  }

  Future<void> _saveSongPerformances(String prefix, String contents) async {
    String fileName =
        '${prefix}_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}${AllSongPerformances.fileExtension}';
    String message = await UtilWorkaround().writeFileContents(fileName, contents); //  fixme: should be async
    logger.d('saveSingersSongList message: \'$message\'');
    app.infoMessage(message);
  }

  void _initialize() async {
    if (!kDebugMode && !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      _lastStore = _appOptions.lastAllSongPerformancesStoreMillisecondsSinceEpoch;
      Timer.periodic(const Duration(minutes: 10), _timerCallback);
      logger.i('SongPerformanceDaemon initialized');
    } else {
      logger.i('SongPerformanceDaemon skipped');
    }
  }

  _timerCallback(Timer timer) async {
    var due = _appOptions.lastAllSongPerformancesStoreMillisecondsSinceEpoch + _updateDelayMilliseconds;

    var dueFormat = intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.fromMillisecondsSinceEpoch(due));
    var nowMs = DateTime.now().millisecondsSinceEpoch;

    if (_lastStore != _appOptions.lastAllSongPerformancesStoreMillisecondsSinceEpoch //  store required
            &&
            nowMs >= due //  been idle long enough
        ) {
      logger.i('SongPerformanceDaemon update: '
          '${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.fromMillisecondsSinceEpoch(nowMs))} > $dueFormat');
      saveAllSongPerformances().then((response) {
        _appOptions.lastAllSongPerformancesStoreMillisecondsSinceEpoch = nowMs;
        _lastStore = _appOptions.lastAllSongPerformancesStoreMillisecondsSinceEpoch;
      });
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
