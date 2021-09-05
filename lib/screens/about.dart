import 'dart:io';

import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/appButton.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Show some data about the app and it's environment.
class About extends StatefulWidget {
  const About({Key? key}) : super(key: key);

  @override
  _About createState() => _About();
}

class _About extends State<About> with  WidgetsBindingObserver{
  @override
  initState() {
    super.initState();

    _lastSize = WidgetsBinding.instance!.window.physicalSize;
    WidgetsBinding.instance!.addObserver(this);

    _readPackageInfo();
    _readUtcDate();
  }

  @override
  Widget build(BuildContext context) {
    appWidget.context = context; //	required on every build

    ScreenInfo screenInfo = App().screenInfo;
    final double fontSize = screenInfo.fontSize;

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidget.backBar(title:'About the bsteele Music App'),
      body: DefaultTextStyle(
        style: generateAppTextStyle(color: Colors.black87, fontSize: fontSize),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                const Text(
                  'The bsteele Music App has been written by bob.',
                ),
                Row(children: <Widget>[
                  const Text(
                    'See ',
                  ),
                  InkWell(
                    onTap: () {
                      openLink('http://www.bsteele.com');
                    },
                    child: Text(
                      'bsteele.com',
                      style: generateAppTextStyle(),
                    ),
                  ),
                ]),
                Text(
                  'appName: ${_packageInfo.appName}',
                ),
                Text(
                  'version: ${_packageInfo.version}',
                ),
                Text(
                  'buildNumber: ${_packageInfo.buildNumber}',
                ),
                // Text(
                //   'packageName: ${_packageInfo.packageName}',
                // ),
                const Text(
                  'Mode: ${kReleaseMode ? 'release' : 'debug'}',
                ),
                Text(
                  'utcDate: ${_utcDateAsString ?? 'unknown'}',
                ),
                const Text(''),
                Text(
                  'screen: (${screenInfo.widthInLogicalPixels.toStringAsFixed(0)}'
                  ',${screenInfo.heightInLogicalPixels.toStringAsFixed(0)})',
                ),
                Text(
                  'OS: ${kIsWeb ? 'web' : Platform.operatingSystem}',
                ),
                // Text(
                //   'ver: ${Platform.version}',
                // ),
              ]),
        ),
      ),
      floatingActionButton: appWidget.floatingBack(),
    );
  }

  void _readPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  void _readUtcDate() async {
    rootBundle.loadString('lib/assets/utcDate.txt').then((value) {
      setState(() {
        _utcDateAsString = value;
      });
    });
  }

  String? _utcDateAsString;
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
  );

  @override
  void didChangeMetrics() {
    //  used to keep the window size data current
    Size size = WidgetsBinding.instance!.window.physicalSize;
    if (size != _lastSize) {
      setState(() {
        _lastSize = size;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  late Size _lastSize;

  final AppWidget appWidget = AppWidget();
}
