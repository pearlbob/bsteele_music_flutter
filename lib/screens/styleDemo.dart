import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_lib/songs/section.dart';
import 'package:bsteele_music_lib/songs/section_version.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Show some data about the app and it's environment.
class StyleDemo extends StatefulWidget {
  const StyleDemo({super.key});

  @override
  StyleDemoState createState() => StyleDemoState();

  static const String routeName = 'styleDemo';
}

class StyleDemoState extends State<StyleDemo> {
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
      children.add(const AppSpace());
      sections = AppWrapFullWidth(children: children);

      for (var section in SectionEnum.values) {
        if (kDebugMode) {
          var sectionContainers = <Widget>[];
          for (var index = 0; index <= 8; index++) {
            var sectionVersion = SectionVersion(Section.get(section), index);
            var color = App.getBackgroundColorForSectionVersion(sectionVersion);
            var coloredChordTextStyle =
                generateChordTextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, backgroundColor: color);
            sectionContainers.add(Container(
                margin: app.measureMargin,
                padding: app.measurePadding,
                color: coloredChordTextStyle.backgroundColor,
                child: Text(
                  section.name + (index > 0 ? index.toString() : '')
                  //  + ' ' + colorToCssColorString( color)
                  ,
                  style: coloredChordTextStyle,
                )));
          }
          children.add(AppWrapFullWidth(children: sectionContainers));
        }
      }
      sections = AppWrapFullWidth(children: children);
    }

    TextStyle toolTipTextStyle = generateTooltipTextStyle();
    var verseBackgroundColor = App.getBackgroundColorForSectionVersion(null);

    return Scaffold(
      appBar: appWidgetHelper.backBar(title: 'bsteeleMusicApp Color demo'),
      body: DefaultTextStyle(
        style: generateAppTextStyle(color: Colors.black87),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.ltr,
                children: <Widget>[
                  Text(
                    'Default Text Style',
                    style: generateAppTextStyle(),
                  ),
                  const AppSpace(),
                  Container(
                    color: App.appbarBackgroundColor,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'App Bar Text Style',
                      style: generateAppBarLinkTextStyle(),
                    ),
                  ),
                  const AppSpace(),
                  appButton('appButton', onPressed: () {}),
                  const AppSpace(),
                  AppWrap(
                    children: [
                      Text(
                        'icon button:',
                        style: generateAppTextStyle(),
                      ),
                      const AppSpace(),
                      appIconWithLabelButton(icon: appIcon(Icons.check), onPressed: () {}),
                    ],
                  ),
                  const AppSpace(),
                  Container(
                    color: App.measureContainerBackgroundColor,
                    child: sections,
                  ),
                  const AppSpace(),
                  Container(
                      margin: app.measureMargin,
                      padding: app.measurePadding,
                      color: verseBackgroundColor,
                      child: Text(
                        'Lyrics text style',
                        style: generateLyricsTextStyle(fontSize: lyricsFontSize, backgroundColor: verseBackgroundColor),
                      )),
                  const AppSpace(),
                  TextField(
                    controller: _textFieldController,
                    maxLength: null,
                    style: generateAppTextFieldStyle(),
                  ),
                  const AppSpace(),
                  Text(
                    'link text style',
                    style: generateAppLinkTextStyle(),
                  ),
                  const AppSpace(),
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
      ),
      floatingActionButton: appWidgetHelper.floatingBack(),
    );
  }

  final TextEditingController _textFieldController = TextEditingController(text: 'input text field');
}
