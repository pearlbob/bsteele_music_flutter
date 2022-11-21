import 'package:bsteeleMusicLib/songs/drumMeasure.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';

Map<DrumTypeEnum, String> drumTypeToFileMap = {
  DrumTypeEnum.closedHighHat: 'audio/hihat1.mp3',
  DrumTypeEnum.openHighHat: 'audio/hihat3.mp3',
  DrumTypeEnum.snare: 'audio/snare_4406.mp3',
  DrumTypeEnum.kick: 'audio/kick_4513.mp3',
  DrumTypeEnum.bass: 'audio/kick_4516.mp3',
};

final TextStyle _style = generateAppTextStyle();
final TextStyle _smallStyle = generateAppTextStyle(fontSize: app.screenInfo.fontSize * 2 / 3);
final TextStyle _boldSmallStyle = _smallStyle.copyWith(fontWeight: FontWeight.bold);

/// Show some data about the app and it's environment.
class DrumsWidget extends StatefulWidget {
  DrumsWidget({super.key, DrumParts? drumParts, TextStyle? headerStyle})
      : drumParts = drumParts ?? DrumParts(beats: 4),
        _headerStyle = headerStyle ?? _style;

  final DrumParts drumParts;
  final TextStyle _headerStyle;

  @override
  DrumsState createState() => DrumsState();
}

class DrumsState extends State<DrumsWidget> {
  @override
  initState() {
    super.initState();

    _drumParts = widget.drumParts;
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
            style: _boldSmallStyle,
            textAlign: TextAlign.right,
          ),
        ));

        for (var beat = 0; beat < _drumParts.beats; beat++) {
          for (var subBeat in DrumSubBeatEnum.values) {
            var name = drumShortSubBeatName(subBeat);
            children.add(Text(
              '${name.isEmpty ? beat + 1 : name}',
              style: name.isEmpty ? _boldSmallStyle : _smallStyle,
              textAlign: TextAlign.center,
            ));
          }
        }
        rows.add(TableRow(children: children));
      }

      //  for each drum
      for (var part in DrumTypeEnum.values) {
        DrumPart drumPart = _drumParts.at(part);
        children = [];
        children.add(Center(
          heightFactor: 1.0,
          child: Text(
            Util.camelCaseToLowercaseSpace(part.name),
            style: _smallStyle,
            textAlign: TextAlign.right,
          ),
        ));

        for (var b = 0; b < _drumParts.beats; b++) {
          for (var subBeat in DrumSubBeatEnum.values) {
            children.add(Checkbox(
              value: drumPart.beatSelection(b, subBeat),
              onChanged: (value) {
                setState(() {
                  drumPart.setBeatSelection(b, subBeat, value ?? false);
                });
              },
            ));
          }
        }
        rows.add(TableRow(children: children));
      }

      Map<int, TableColumnWidth>? columnWidths = {};

      //  skip the drum titles
      columnWidths[0] = const FlexColumnWidth(3.0);
      for (var col = 1; col < _drumParts.beats * drumSubBeatsPerBeat; col++) {
        columnWidths[col] = const FlexColumnWidth();
      }

      table = Table(
        defaultColumnWidth: const FlexColumnWidth(),
        columnWidths: columnWidths,
        //  covers all
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
        border: TableBorder.all(),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AppSpace(),
      AppWrapFullWidth(spacing: 10, children: [
        Text(
          'Drums: ${_drumParts.name}',
          style: widget._headerStyle,
        ),
        AppTooltip(
          message: 'Clear the drum selections',
          child: appButton(
            'Clear',
            appKeyEnum: AppKeyEnum.drumsSelectionClear,
            onPressed: () {
              setState(() {
                _drumParts.clear();
              });
            },
          ),
        ),
      ]),
      AppWrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(
          'Volume:',
          style: _smallStyle,
        ),
        SizedBox(
          width: app.screenInfo.mediaWidth * 0.4, // fixme: too fiddly
          child: Slider(
            value: widget.drumParts.volume * 10,
            onChanged: (value) {
              setState(() {
                widget.drumParts.volume = value / 10;
              });
            },
            min: 0,
            max: 10.0,
          ),
        ),
      ]),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppWrapFullWidth(children: [
              // appNoteButton(
              //   noteQuarterUp.character,
              //   appKeyEnum: AppKeyEnum.sheetMusicQuarterNoteUp,
              //   onPressed: () {
              //     logger.i('noteQuarterUp pressed');
              //   },
              // ),
              //         const AppSpace(),
              //         appNoteButton(
              //           note8thUp.character,
              //           appKeyEnum: AppKeyEnum.sheetMusic8thNoteUp,
              //           onPressed: () {
              //             logger.i('note8thUp pressed');
              //           },
              //         ),
              //         const AppSpace(),
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

  late DrumParts _drumParts;
}
