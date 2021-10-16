import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';

/// Show some data about the app and it's environment.
class CssDemo extends StatefulWidget {
  const CssDemo({Key? key}) : super(key: key);

  @override
  _CssDemo createState() => _CssDemo();
}

class _CssDemo extends State<CssDemo> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);

    const fontSize = 40.0;
    const lyricsFontSize = fontSize * 0.6;

    Widget sections;
    {
      var children = <Widget>[];
      for (var section in SectionEnum.values) {
        var backgroundColor = getBackgroundColorForSection(Section.get(section));
        var coloredChordTextStyle = generateChordTextStyle(fontSize: fontSize, backgroundColor: backgroundColor);
        children.add(Container(
            margin: getMeasureMargin(),
            padding: getMeasurePadding(),
            color: backgroundColor,
            child: Text(
              Util.enumToString(section),
              style: coloredChordTextStyle,
            )));
      }
      sections = appWrapFullWidth(children);
    }

    TextStyle toolTipTextStyle = generateTooltipTextStyle();
    var verseBackgroundColor = getBackgroundColorForSection(Section.get(SectionEnum.verse));

    return Scaffold(
      appBar: appWidgetHelper.backBar(title: 'bsteele Music App CSS demo'),
      body: DefaultTextStyle(
        style: generateAppTextStyle(color: Colors.black87),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                Text(
                  'Default Text Style',
                  style: generateAppTextStyle(),
                ),
                appSpace(),
                Container(
                  color: Colors.blue,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'App Bar Text Style',
                    style: generateAppBarLinkTextStyle(),
                  ),
                ),
                appSpace(),
                appButton('appButton', appKeyEnum: AppKeyEnum.cssDemoButton, onPressed: () {}),
                appSpace(),
                sections,
                appSpace(),
                Container(
                    margin: getMeasureMargin(),
                    padding: getMeasurePadding(),
                    color: verseBackgroundColor,
                    child: Text(
                      'Lyrics text style',
                      style: generateLyricsTextStyle(fontSize: lyricsFontSize, backgroundColor: verseBackgroundColor),
                    )),
                appSpace(),
                TextField(
                  controller: _textFieldController,
                  maxLength: null,
                  style: generateAppTextFieldStyle(),
                ),
                appSpace(),
                Text(
                  'link text style',
                  style: generateAppLinkTextStyle(),
                ),
                appSpace(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: appTooltipBoxDecoration(toolTipTextStyle.backgroundColor),
                  child: Text(
                    'toolTip text style and decoration',
                    style: toolTipTextStyle,
                  ),
                ),
              ]),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.cssDemoBack),
    );
  }

  final TextEditingController _textFieldController = TextEditingController(text: 'input text field');
}
