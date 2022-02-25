import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/songs/drumMeasure.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';

Map<DrumType, String> drumTypeToFileMap = {
  DrumType.closedHighHat: 'audio/hihat1.mp3',
  DrumType.openHighHat: 'audio/hihat3.mp3',
  DrumType.snare: 'audio/snare_4406.mp3',
  DrumType.kick: 'audio/kick_4513.mp3',
  DrumType.bass: 'audio/kick_4516.mp3',
};

TextStyle _style = generateAppTextStyle();
TextStyle _smallStyle = generateAppTextStyle(fontSize: app.screenInfo.fontSize * 2 / 3);

/// Show some data about the app and it's environment.
class DrumsWidget extends StatefulWidget {
  DrumsWidget({Key? key, this.beats = 4, DrumParts? drumParts})
      : _drumParts = drumParts ?? DrumParts.defaultDrumParts(),
        super(key: key);

  final int beats;
  final DrumParts _drumParts;

  @override
  _DrumsState createState() => _DrumsState();
}

const int drumSubBeats = 4;
List<String> _timingNames = [
  '1',
  'e',
  'and',
  'a',
  '2',
  'e',
  'and',
  'a',
  '3',
  'e',
  'and',
  'a',
  '4',
  'e',
  'and',
  'a',
  '5',
  'e',
  'and',
  'a',
  '6',
  'e',
  'and',
  'a',
];

class _DrumsState extends State<DrumsWidget> {
  _DrumsState({int? beats}) : _beats = beats ?? 4;

  @override
  initState() {
    super.initState();

    _beats = widget.beats;
    _drumParts = widget._drumParts;
  }

  @override
  Widget build(BuildContext context) {
    Table table;

    {
      List<TableRow> rows = [];
      List<Widget> children;

      //  title row
      {
        children = [];
        children.add(Center(
          child: Text(
            'Drum',
            style: _smallStyle,
            textAlign: TextAlign.right,
          ),
        ));

        int index = 0;
        for (var beat = 0; beat < _beats; beat++) {
          for (var subBeat = 0; subBeat < 4; subBeat++) {
            children.add(Text(
              _timingNames[index++],
              style: _smallStyle,
              textAlign: TextAlign.center,
            ));
          }
        }
        rows.add(TableRow(children: children));
      }

      //  for each drum
      for (var part in DrumType.values) {
        children = [];
        children.add(Center(
          child: Text(
            Util.camelCaseToLowercaseSpace(Util.enumName(part)),
            style: _smallStyle,
            textAlign: TextAlign.right,
          ),
        ));
        DrumPart drumPart = _drumParts.at(part);
        for (var b = 0; b < _beats; b++) {
          for (var s = 0; s < drumSubBeats; s++) {
            children.add(Checkbox(
              value: drumPart.beatSelection(b, s),
              onChanged: (value) {
                setState(() {
                  drumPart.setBeatSelection(b, s, value ?? false);
                });
              },
            ));
          }
        }
        rows.add(TableRow(children: children));
      }

      Map<int, TableColumnWidth>? columnWidths = {};
      columnWidths[0] = const FlexColumnWidth(4.0);
      //  skip the drum titles
      for (var col = 1; col < _beats * drumSubBeats; col++) {
        columnWidths[col] = const FlexColumnWidth();
      }

      table = Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        columnWidths: columnWidths,
        //  covers all
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
        border: TableBorder.all(),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Drums:',
        style: _style,
      ),
      Center(
        child: Text(
          'Volume:',
          style: _smallStyle,
        ),
      ),
      Slider(
        value: widget._drumParts.volume * 10,
        onChanged: (value) {
          setState(() {
            widget._drumParts.volume = value / 10;
          });
        },
        min: 0,
        max: 10.0,
      ),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            appWrapFullWidth(children: [
              // appNoteButton(
              //   noteQuarterUp.character,
              //   appKeyEnum: AppKeyEnum.sheetMusicQuarterNoteUp,
              //   onPressed: () {
              //     logger.i('noteQuarterUp pressed');
              //   },
              // ),
              //         appSpace(),
              //         appNoteButton(
              //           note8thUp.character,
              //           appKeyEnum: AppKeyEnum.sheetMusic8thNoteUp,
              //           onPressed: () {
              //             logger.i('note8thUp pressed');
              //           },
              //         ),
              //         appSpace(),
              //         appNoteButton(
              //           note16thUp.character,
              //           appKeyEnum: AppKeyEnum.sheetMusic16thNoteUp,
              //           onPressed: () {
              //             logger.i('note16thUp pressed');
              //           },
              //         ),
              //       ]),
              // //       appNoteButton(note8thUp.character, appKeyEnum: AppKeyEnum.aboutBack, onPressed: () {
              // // logger.i('note8thUp.character here');
              // // }),
              //       appInkWell(
              //           appKeyEnum: AppKeyEnum.editBack,
              //           child: Baseline(
              //             baselineType: TextBaseline.alphabetic,
              //             baseline: 45,
              //             child: Text(
              //               note8thUp.character,
              //               style: const TextStyle(
              //                 fontFamily: 'Bravura',
              //                 fontSize: 45,
              //                 height: 0.5,
              //                 // leadingDistribution: ui.TextLeadingDistribution.proportional,
              //                 // fontFeatures:  [ui.FontFeature.stylisticAlternates()],
              //               ),
              //             ),
              //           ),
              //           onTap: () {
              //             logger.i('fix me here');
              //           }),
              //       Container(
              //         color: Colors.black12,
              //         width: fontsize ,
              //         height: fontsize,
              //         child: Align(
              //         alignment: symbol.isUp ? Alignment.bottomCenter : Alignment.topCenter,
              //           child:
              //           Text(
              //             symbol.character,
              //             style:  TextStyle(
              //               fontFamily: 'Bravura',
              //               fontSize: fontsize,
              //              height: 1,
              //             //  leadingDistribution: TextLeadingDistribution.proportional,
              //             //  fontFeatures:  [ui.FontFeature.stylisticAlternates()],
              //             ),
              //           ),
              //         ),
              //     ),
              table,
            ]),
          ]))
    ]);
  }

  int _beats;
  late DrumParts _drumParts;
}

class DrumParts {
  DrumParts(int beats, {double? volume})
      : _beats = beats,
        _volume = volume ?? 0.25 {
    for (var e in DrumType.values) {
      _drumParts[e] = DrumPart(e, beats);
    }
  }

  DrumPart at(DrumType e) {
    return _drumParts[e];
  }

  static DrumParts defaultDrumParts() {
    return _defaultDrumParts;
  }

  bool beatSelection(DrumType e, int beat, int subBeat) {
    return _drumParts[e].beatSelection(beat, subBeat);
  }

  void setBeatSelection(DrumType e, int beat, int subBeat, bool value) {
    _drumParts[e].setBeatSelection(beat, subBeat, value);
  }

  static final _defaultDrumParts = DrumParts(4)
        //..setBeatSelection(DrumType.bass, 0, 0, true)
        ..setBeatSelection(DrumType.openHighHat, 0, 0, true)
        ..setBeatSelection(DrumType.closedHighHat, 1, 0, true)
        // ..setBeatSelection(DrumType.snare, 1, 0, true)
        ..setBeatSelection(DrumType.closedHighHat, 2, 0, true)
        ..setBeatSelection(DrumType.closedHighHat, 3, 0, true)

      // ..setBeatSelection(DrumType.snare, 3, 0, true)
      ;

  int get beats => _beats;
  final int _beats;
  final Map _drumParts = HashMap<DrumType, DrumPart>();

  set volume(double value) {
    _volume = max(0, min(1.0, value));
  }

  double get volume => _volume;
  double _volume = 0.25;
}

class DrumPart {
  DrumPart(this.partEnum, this.beats) {
    _beatSelection = List<bool>.filled(beats * drumSubBeats, false);
  }

  bool subBeatSelection(int subBeatIndex, int subBeat) {
    return _beatSelection[subBeatIndex];
  }

  /// Count from zero
  bool beatSelection(int beat, int subBeat) {
    assert(beat < beats);
    assert(subBeat < drumSubBeats);
    return _beatSelection[beat * drumSubBeats + subBeat];
  }

  void setBeatSelection(int beat, int subBeat, bool b) {
    _beatSelection[beat * drumSubBeats + subBeat] = b;
  }

  int get subBeatLength => _beatSelection.length;

  final DrumType partEnum;
  final int beats;
  List<bool> _beatSelection = [];
}
