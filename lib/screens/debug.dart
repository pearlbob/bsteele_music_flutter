import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart' as md;

/// Display the application's songlyrics file specification
class Debug extends StatefulWidget {
  const Debug({Key? key}) : super(key: key);

  @override
  _State createState() => _State();

  static const String routeName = '/debug';
}

class _State extends State<Debug> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);

    TextStyle style = generateAppTextStyle(color: Colors.black87);

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'bsteele Music App Debug'),
      body: DefaultTextStyle(
        style: style,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.all(8.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                for (var log in appLog()) Text(log),
              ]),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.documentationBack),
    );
  }
}
