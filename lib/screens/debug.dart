import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';

/// Display the application's songlyrics file specification
class Debug extends StatefulWidget {
  const Debug({super.key});

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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: appWidgetHelper.backBar(title: 'bsteeleMusicApp Debug'),
      body: DefaultTextStyle(
        style: style,
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text('empty now'),
            ],
          ),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(),
    );
  }
}
