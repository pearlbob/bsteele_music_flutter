import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/appButton.dart';
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
    appWidget.context = context; //	required on every build

    Widget sections;
    {
      var children = <Widget>[];
      for (var section in SectionEnum.values) {
        var backgroundColor = getBackgroundColorForSection(Section.get(section));
        var coloredChordTextStyle = generateChordTextStyle(fontSize: 40, backgroundColor: backgroundColor);
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

    return Scaffold(
      appBar: appWidget.backBar(title: 'bsteele Music App CSS demo'),
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
                appButton('appButton', onPressed: () {}),
                appSpace(),
                sections,
              ]),
        ),
      ),
      floatingActionButton: appWidget.floatingBack(),
    );
  }

  final AppWidget appWidget = AppWidget();
}
