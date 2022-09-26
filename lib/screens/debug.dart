import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';

/// Display the application's songlyrics file specification
class Debug extends StatefulWidget {
  const Debug({Key? key}) : super(key: key);

  @override
  DebugState createState() => DebugState();

  static const String routeName = 'debug';
}

class DebugState extends State<Debug> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);

    TextStyle style = generateAppTextStyle(color: Colors.black87, fontSize: appDefaultFontSize * 2);

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'bsteele Music App Debug'),
      body: DefaultTextStyle(
        style: style,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              appButton('Write Log', appKeyEnum: AppKeyEnum.debugWriteLog, onPressed: () {
                logger.i('write log: ${appLog().toString()}');
              }),
              SingleChildScrollView(
                scrollDirection: Axis.vertical,
                padding: const EdgeInsets.all(8.0),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.ltr,
                    children: <Widget>[
                      for (var log in appLog()) Text(log, textAlign: TextAlign.start),
                    ]),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.documentationBack),
    );
  }
}
