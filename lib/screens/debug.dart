import 'package:bsteeleMusicLib/app_logger.dart';
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
      appBar: appWidgetHelper.backBar(title: 'bsteeleMusicApp Debug'),
      body: DefaultTextStyle(
        style: style,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              appButton('Write Log', appKeyEnum: AppKeyEnum.debugWriteLog, onPressed: () {
                StringBuffer sb = StringBuffer();
                for (var s in appLog) {
                  sb.writeln(s);
                }
                logger.i('write log: $sb');
              }),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.ltr,
                    children: appLog.map((e) => Text(e, textAlign: TextAlign.start)).toList(growable: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.documentationBack),
    );
  }
}
