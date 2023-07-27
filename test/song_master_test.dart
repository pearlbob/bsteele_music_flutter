// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/drum_measure.dart';
import 'package:bsteele_music_flutter/songMaster.dart';
import 'package:bsteele_music_lib/songs/key.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

var defaultFontSize = 24.0;

void main() async {
  Logger.level = Level.info;

  TestWidgetsFlutterBinding.ensureInitialized();

  test('test Song master scheduler', () {
    logger.i('test Song master scheduler');

    var scheduler = SongMasterScheduler();

    const beats = 4;
    const bpm = 160;
    const bar = 60.0 / bpm * beats;
    const step = bar / beats / 4;

    DrumParts drumParts = DrumParts(name: 'test', beats: beats, parts: [
      DrumPart(
        DrumTypeEnum.bass,
        beats: beats,
      )..addBeat(DrumBeat.beat1, subBeat: DrumSubBeatEnum.subBeat)
    ]);
    logger.i('bar: $bar, step: $step, drumParts: $drumParts');

    var t = 0.0;
    for (var t = 0.0; t < 2; t += step) {
      logger.i('t: ${t.toStringAsFixed(3)} = ${(t / bar).toStringAsFixed(3)} bars');
      scheduler.tick(t);
    }
    scheduler.drum(drumParts, bpm);
    for (; t < 6; t += step) {
      logger.i('t: ${t.toStringAsFixed(3)} = ${(t / bar).toStringAsFixed(3)} bars');
      scheduler.tick(t);
    }
  });

  test('test bpm changes', () {
    logger.i('test bpm changes');

    int beatsPerBar = 4;
    int bpm = 106;

    var song = Song(
        title: 'A song',
        artist: 'bob',
        copyright: 'bsteele.com',
        key: Key.C,
        beatsPerMinute: bpm,
        beatsPerBar: beatsPerBar,
        unitsPerMeasure: 4,
        user: 'pearl bob',
        chords:
            'I: V: [Am Am/G Am/F# FE ] x8  I2: [Am Am/G Am/F# FE ] x4  C: F F C C, G G F F x12  O: Dm C B Bb x4, A  ',
        rawLyrics: 'i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro');

    double time = 10000;
    double songStart = 0;

    logger.i('song: moments: ${song.songMoments.length}');
    for (var songMoment in song.songMoments) {
      logger.i('$songMoment   ${songMoment.chordSectionLocation}'
          ', t: ${song.getSongTimeAtMoment(songMoment.momentNumber, beatsPerMinute: bpm)}');
      for (var b in [bpm - 4, bpm, bpm + 4]) {
        var momentNumber = songMoment.momentNumber;
        logger.i('   $b: ${song.getSongTimeAtMoment(momentNumber, beatsPerMinute: b).toStringAsFixed(6)}');
        var oldSongStart = songStart;
        songStart = time - song.getSongTimeAtMoment(momentNumber, beatsPerMinute: b);
        logger.i('        resetSongStart(): new songStart: $songStart,  momentNumber: $momentNumber'
            ', ${songStart - oldSongStart}');
      }
    }
  });
}
