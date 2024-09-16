import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/song_tempo_update.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

const Level _log = Level.info;

TempoNotifier tempoNotifier = TempoNotifier();

class TempoNotifier extends ChangeNotifier {
  set songTempoUpdate(final SongTempoUpdate? newSongTempoUpdate) {
    logger.log(
        _log, 'tempoNotifier: ${_songTempoUpdate?.songId}, currentBPM: ${_songTempoUpdate?.currentBeatsPerMinute}');
    if (newSongTempoUpdate != null &&
        (newSongTempoUpdate.songId != _songTempoUpdate?.songId ||
            newSongTempoUpdate.currentBeatsPerMinute != _songTempoUpdate?.currentBeatsPerMinute)) {
      _songTempoUpdate = newSongTempoUpdate;
      notifyListeners();
    }
  }

  @override
  bool operator ==(Object other) {
    return other is TempoNotifier && _songTempoUpdate == other._songTempoUpdate;
  }

  @override
  int get hashCode {
    return _songTempoUpdate?.hashCode ?? 0;
  }

  SongTempoUpdate? get songTempoUpdate => _songTempoUpdate;
  SongTempoUpdate? _songTempoUpdate;
}
