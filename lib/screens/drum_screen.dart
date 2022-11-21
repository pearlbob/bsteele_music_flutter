import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';

import '../widgets/drums.dart';

/// Show some data about the app and it's environment.
class DrumScreen extends StatefulWidget {
  const DrumScreen({Key? key, this.song}) : super(key: key);

  @override
  DrumScreenState createState() => DrumScreenState();

  final Song? song;

  static const String routeName = 'drumScreen';
}

class DrumScreenState extends State<DrumScreen> with WidgetsBindingObserver {
  @override
  initState() {
    super.initState();

    _lastSize = WidgetsBinding.instance.window.physicalSize;
    WidgetsBinding.instance.addObserver(this);

    _drums = DrumsWidget(
      beats: widget.song?.timeSignature.beatsPerBar ?? 4, //  fixme temp
    );

    logger.i('song: ${widget.song?.toString()}');

    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);

    app.screenInfo.refresh(context);

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'Drums'),
      body: DefaultTextStyle(
          style: generateAppTextStyle(color: Colors.black87, fontSize: app.screenInfo.fontSize),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: ListView(children: [
              _drums,
            ])),
          ])),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.aboutBack),
    );
  }

  @override
  void didChangeMetrics() {
    //  used to keep the window size data current
    Size size = WidgetsBinding.instance.window.physicalSize;
    if (size != _lastSize) {
      setState(() {
        _lastSize = size;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DrumsWidget _drums = DrumsWidget();
  late Size _lastSize;
}
