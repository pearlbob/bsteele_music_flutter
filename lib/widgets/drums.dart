import 'dart:collection';

import 'package:bsteeleMusicLib/songs/drumMeasure.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';

TextStyle _style = generateAppTextStyle();
TextStyle _smallStyle = generateAppTextStyle(fontSize: app.screenInfo.fontSize * 2 / 3);

/// Show some data about the app and it's environment.
class Drums extends StatefulWidget {
  const Drums({Key? key}) : super(key: key);

  final int beats = 4; //  fixme!!!!!!!!!!!!!!!!!!!!!!

  @override
  _Drums createState() => _Drums();
}

int _subBeats = 4;
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

class _Drums extends State<Drums> {
  @override
  initState() {
    super.initState();

    beats = widget.beats;
    _drumParts = DrumParts(beats);
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
        for (var beat = 0; beat < beats; beat++) //  fixme!!!!!!!!!!!!
        {
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
        for (var b = 0; b < beats; b++) {
          for (var s = 0; s < _subBeats; s++) {
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
      for (var col = 1; col < beats * _subBeats; col++) {
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

  late int beats;
  late DrumParts _drumParts;
}

class DrumParts {
  DrumParts(int beats) {
    for (var e in DrumType.values) {
      _drumParts[e] = DrumPart(e, beats);
    }
  }

  DrumPart at(DrumType e) {
    return _drumParts[e];
  }

  bool beatSelection(DrumType e, int beat, int subBeat) {
    return _drumParts[e].beatSelection(beat, subBeat);
  }

  final Map _drumParts = HashMap<DrumType, DrumPart>();
}

class DrumPart {
  DrumPart(this.partEnum, this.beats) {
    _beatSelection = List<bool>.filled(beats * _subBeats, false);
  }

  bool beatSelection(int beat, int subBeat) {
    return _beatSelection[beat * _subBeats + subBeat];
  }

  void setBeatSelection(int beat, int subBeat, bool b) {
    _beatSelection[beat * _subBeats + subBeat] = b;
  }

  final DrumType partEnum;
  final int beats;
  List<bool> _beatSelection = [];
}
