import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/sectionVersion.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:flutter/foundation.dart';
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

    Widget sections = NullWidget();
    {
      var children = <Widget>[];
      children.add(Text(
        'sections:',
        style: generateAppTextStyle(),
      ));
      children.add(appSpace());
      sections = appWrapFullWidth(children: children);

      for (var section in SectionEnum.values) {
        if (kDebugMode) {
          var sectionContainers = <Widget>[];
          for (var index = 0; index <= 8; index++) {
            var sectionVersion = SectionVersion(Section.get(section), index);
            var coloredChordTextStyle = generateChordTextStyle(
                fontSize: fontSize, backgroundColor: getBackgroundColorForSectionVersion(sectionVersion));
            sectionContainers.add(Container(
                margin: getMeasureMargin(),
                padding: getMeasurePadding(),
                color: coloredChordTextStyle.backgroundColor,
                child: Text(
                  Util.enumName(section) + (index > 0 ? index.toString() : ''),
                  style: coloredChordTextStyle,
                )));
          }
          children.add(appWrapFullWidth(children: sectionContainers));
        }
      }
      sections = appWrapFullWidth(children: children);
    }

    TextStyle toolTipTextStyle = generateTooltipTextStyle();
    var verseBackgroundColor = getBackgroundColorForSectionVersion(null);

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
                  color: appbarBackgroundColor(),
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'App Bar Text Style',
                    style: generateAppBarLinkTextStyle(),
                  ),
                ),
                appSpace(),
                appButton('appButton', appKeyEnum: AppKeyEnum.cssDemoButton, onPressed: () {}),
                appSpace(),
                appWrap(
                  [
                    Text(
                      'icon button:',
                      style: generateAppTextStyle(),
                    ),
                    appSpace(),
                    appIconButton(
                        appKeyEnum: AppKeyEnum.cssDemoIconButton, icon: appIcon(Icons.check), onPressed: () {}),
                  ],
                ),
                appSpace(),
                Container(
                  child: sections,
                  color: measureContainerBackgroundColor(),
                ),
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
