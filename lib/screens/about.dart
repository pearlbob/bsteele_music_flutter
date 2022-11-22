import 'dart:convert';
import 'dart:math';

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Show some data about the app and it's environment.
class About extends StatefulWidget {
  const About({Key? key}) : super(key: key);

  @override
  AboutState createState() => AboutState();

  static const String routeName = 'about';
}

class AboutState extends State<About> with WidgetsBindingObserver {
  @override
  initState() {
    super.initState();

    _lastSize = WidgetsBinding.instance.window.physicalSize;
    WidgetsBinding.instance.addObserver(this);

    _readPackageInfo();
    _readUtcDate();
    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);

    app.screenInfo.refresh(context);

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'About the bsteeleMusicApp'),
      body: DefaultTextStyle(
        style: generateAppTextStyle(color: Colors.black87, fontSize: app.screenInfo.fontSize),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                app.messageTextWidget(AppKeyEnum.aboutErrorMessage),
                const AppSpace(),
                const Text(
                  'The bsteeleMusicApp has been written by bob.',
                ),
                Image(
                  image: const AssetImage('lib/assets/app_qr_code.png'),
                  width: max(150, app.screenInfo.mediaWidth / 5),
                  height: max(150, app.screenInfo.mediaWidth / 5),
                  semanticLabel: "bsteele.com website",
                ),
                Row(
                  children: <Widget>[
                    const Text(
                      'See ',
                    ),
                    InkWell(
                      onTap: () {
                        openLink('http://www.bsteele.com');
                      },
                      child: Text(
                        'bsteele.com',
                        style: generateAppLinkTextStyle(fontSize: app.screenInfo.fontSize),
                      ),
                    ),
                    const Text(
                      '.',
                    ),
                    const AppSpace(horizontalSpace: 20),
                    InkWell(
                      onTap: () {
                        openLink('http://www.bsteele.com/bsteeleMusicApp/download.html');
                      },
                      child: Text(
                        'Download the app.',
                        style: generateAppLinkTextStyle(fontSize: app.screenInfo.fontSize),
                      ),
                    ),
                  ],
                ),
                // Text(
                //   'appName: ${_packageInfo.appName}',
                // ),
                // Text(
                //   'version: ${_packageInfo.version}',
                // ),
                // Text(
                //   'buildNumber: ${_packageInfo.buildNumber}',
                // ),
                // Text(
                //   'packageName: ${_packageInfo.packageName}',
                // ),
                const Text(
                  'Mode: ${kReleaseMode ? 'release' : 'debug'}',
                ),
                if (kReleaseMode) //  fixme: not necessary
                  AppWrapFullWidth(children: [
                    const Text(
                      'Test the ',
                    ),
                    InkWell(
                      onTap: () {
                        openLink('http://www.bsteele.com/bsteeleMusicApp/beta/index.html');
                      },
                      child: Text(
                        'beta',
                        style: generateAppLinkTextStyle(fontSize: app.screenInfo.fontSize),
                      ),
                    ),
                    const Text(
                      '.',
                    ),
                  ]),
                Text(
                  'utcDate: ${_utcDateAsString ?? 'unknown'}',
                ),
                const Text(''),
                Text(
                  'screen: (${app.screenInfo.mediaWidth.toStringAsFixed(0)}'
                  ',${app.screenInfo.mediaHeight.toStringAsFixed(0)})'
                  // ', fontSize: ${app.screenInfo.fontSize}'
                  // ', titleScaleFactor: ${app.screenInfo.titleScaleFactor.toStringAsFixed(2)}'
                  ,
                ),
                Text(
                  'OS:  ${kIsWeb ? 'web version on' : ''}'
                  ' ${Theme.of(context).platform.name}',
                ),
                if (!kIsWeb)
                  Text(
                    'Document Path: $_applicationDocumentsPath',
                  ),
                // Text(
                //   'ver: ${Platform.version}',
                // ),
                const AppSpace(),
                AppTooltip(
                  message: 'If the app did something wrong,\n'
                      'use this button to write a diagnostic file for bob.\n'
                      'Of course it would help to email it to me as well\n'
                      'with a brief description of what happened.',
                  child: appButton(
                    'Write diagnostic log file',
                    appKeyEnum: AppKeyEnum.aboutWriteDiagnosticLogFile,
                    onPressed: () {
                      _writeDiagnosticLogFile();
                    },
                  ),
                ),
              ]),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.aboutBack),
    );
  }

  void _readPackageInfo() async {
    // final info = await PackageInfo.fromPlatform();
    // setState(() {
    //   _packageInfo = info;
    // });
    try {
      final applicationDocumentsDirectory = await getApplicationDocumentsDirectory();
      _applicationDocumentsPath = applicationDocumentsDirectory.path;
    } catch (e) {
      _applicationDocumentsPath = 'unknown';
    }
  }

  void _writeDiagnosticLogFile() async {
    String utcNow = Util.utcNow();
    StringBuffer sb = StringBuffer();
    sb.writeln('''{
    "fileFormat": "1.0.0",
    "user": ${jsonEncode(userName)},
    "versionUtcDate": ${jsonEncode(_utcDateAsString ?? 'unknown')},
    "nowUtc": ${jsonEncode(utcNow)},
    "log": [''');
    // "version": ${jsonEncode(_packageInfo.version)},

    bool first = true;
    for (var s in appLog) {
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
    logger.v('$fileName:${sb.toString()}');
    String message = await UtilWorkaround().writeFileContents(fileName, sb.toString(), fileType: 'log');
    setState(() {
      if (message.toLowerCase().contains('error')) {
        app.errorMessage(message);
      } else {
        app.infoMessage = message;
      }
    });
  }

  void _readUtcDate() async {
    _utcDateAsString = await app.releaseUtcDate();
    setState(() {});
  }

  String? _utcDateAsString;

  // PackageInfo _packageInfo = PackageInfo(
  //   appName: 'Unknown',
  //   packageName: 'Unknown',
  //   version: 'Unknown',
  //   buildNumber: 'Unknown',
  //   buildSignature: 'Unknown',
  // );

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

  String? _applicationDocumentsPath = 'unknown';
  late Size _lastSize;
}
