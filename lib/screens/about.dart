import 'dart:convert';
import 'dart:io';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Show some data about the app and it's environment.
class About extends StatefulWidget {
  const About({Key? key}) : super(key: key);

  @override
  _About createState() => _About();
}

class _About extends State<About> with WidgetsBindingObserver {
  @override
  initState() {
    super.initState();

    _lastSize = WidgetsBinding.instance!.window.physicalSize;
    WidgetsBinding.instance!.addObserver(this);

    _readPackageInfo();
    _readUtcDate();
    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);

    ScreenInfo screenInfo = App().screenInfo;
    final double fontSize = screenInfo.fontSize;

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'About the bsteele Music App'),
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
                      style: generateAppLinkTextStyle(),
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
                appSpace(),
                appButton('Write diagnostic log file', appKeyEnum: AppKeyEnum.aboutWriteDiagnosticLogFile,
                    onPressed: () {
                  writeDiagnosticLogFile();
                }),
                appSpace(),
                app.messageTextWidget(),
              ]),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.aboutBack),
    );
  }

  void _readPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  void writeDiagnosticLogFile() async {
    String utcNow = Util.utcNow();
    StringBuffer sb = StringBuffer();
    sb.writeln('''{
    "fileFormat": "1.0.0",
    "user": ${jsonEncode(userName)},
    "version": ${jsonEncode(_packageInfo.version)},
    "versionUtcDate": ${jsonEncode(_utcDateAsString ?? 'unknown')},
    "nowUtc": ${jsonEncode(utcNow)},
    "log": [''');

    bool first = true;
    for (var s in appLog()) {
      if (first) {
        first = false;
      } else {
        sb.writeln(',');
      }
      sb.write('        ');
      sb.write(jsonEncode(s));
    }
    sb.write('''

    ]
}
''');
    var fileName = 'bsteeleMusicAppLog_$utcNow.json';
    logger.i('$fileName:${sb.toString()}');
    String message = await UtilWorkaround().writeFileContents(fileName, sb.toString(), fileType: 'log');
    setState(() {
      if (message.toLowerCase().contains('error')) {
        app.errorMessage(message);
      } else {
        app.infoMessage(message);
      }
    });
  }

  void _readUtcDate() async {
    rootBundle.loadString('lib/assets/utcDate.txt').then((value) {
      setState(() {
        _utcDateAsString = value.replaceAll('\n', '');
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
}
