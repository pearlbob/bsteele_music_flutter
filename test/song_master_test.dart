// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/songs/drum_measure.dart';
import 'package:bsteele_music_flutter/songMaster.dart';
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
}
