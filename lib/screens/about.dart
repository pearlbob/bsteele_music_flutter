import 'dart:math';

import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart';

/// Show some data about the app and it's environment.
class About extends StatefulWidget {
  const About({super.key});

  @override
  AboutState createState() => AboutState();

  static const String routeName = 'about';
}

class AboutState extends State<About> with WidgetsBindingObserver {
  @override
  initState() {
    super.initState();

    _lastSize = PlatformDispatcher.instance.implicitView?.physicalSize;
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: appWidgetHelper.backBar(title: 'About the bsteeleMusicApp'),
      body: DefaultTextStyle(
        style: generateAppTextStyle(color: Colors.black87, fontSize: app.screenInfo.fontSize),
        child: SingleChildScrollView(
          child: Column(
              mainAxisAlignment: .start,
              crossAxisAlignment: .start,
              children: <Widget>[
                app.messageTextWidget(),
                const AppSpace(),
                const Text(
                  'The bsteeleMusicApp has been written by bob.',
                ),
                AppTooltip(
                  message: 'Use this QR for the web version of the app.',
                  child: Image(
                    image: const AssetImage('lib/assets/app_qr_code.png'),
                    width: max(150, app.screenInfo.mediaWidth / 5),
                    height: max(150, app.screenInfo.mediaWidth / 5),
                    semanticLabel: "bsteele.com website",
                  ),
                ),
                Row(
                  children: <Widget>[
                    AppTooltip(
                      message: 'Visit bob\'s website',
                      child: AppWrap(children: [
                        const Text(
                          'See ',
                        ),
                        const AppSpace(horizontalSpace: 10),
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
                      ]),
                    ),
                    const AppSpace(horizontalSpace: 20),
                    AppTooltip(
                        message: 'Native versions are available for the app here.',
                        child: InkWell(
                          onTap: () {
                            openLink('http://www.bsteele.com/bsteeleMusicApp/download.html');
                          },
                          child: Text(
                            'Download the app.',
                            style: generateAppLinkTextStyle(fontSize: app.screenInfo.fontSize),
                          ),
                        )),
                  ],
                ),
                const AppSpace(),
                AppWrapFullWidth(
                  spacing: 20,
                  children: [
                    Text(
                      'version: ${packageInfo.version}',
                    ),
                    if (isBeta)
                      const Text(
                        'beta  ',
                      ),
                    //  release notes
                    InkWell(
                      onTap: () {
                        //  why is this so hard?
                        openLink('${Uri.base.scheme}://${Uri.base.authority}${Uri.base.path}release_notes.html');
                      },
                      child: Text(
                        'Release Notes',
                        style: generateAppLinkTextStyle(fontSize: app.screenInfo.fontSize),
                      ),
                    ),
                    const Text(
                      'Mode: ${kReleaseMode ? 'release' : 'debug'}',
                    ),
                    //  utc date
                    Text(
                      'utcDate: ${_utcDateAsString ?? 'unknown'}',
                    ),
                  ],
                ),

                AppWrapFullWidth(children: [
                  const Text(
                    'Test the ',
                  ),
                  InkWell(
                    onTap: () {
                      var path = Uri.base.path.replaceFirst('index.html', '').replaceFirst('/beta', '');
                      openLink('${Uri.base.scheme}://${Uri.base.authority}${path}beta/index.html');
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
              ]),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(),
    );
  }

  void _readPackageInfo() async {
    try {
      final applicationDocumentsDirectory = await getApplicationDocumentsDirectory();
      _applicationDocumentsPath = applicationDocumentsDirectory.path;
    } catch (e) {
      _applicationDocumentsPath = 'unknown';
    }
  }

  void _readUtcDate() async {
    _utcDateAsString = await app.releaseUtcDate();
    setState(() {});
  }

  String? _utcDateAsString;

  @override
  void didChangeMetrics() {
    //  used to keep the window size data current
    Size? size = PlatformDispatcher.instance.implicitView?.physicalSize;
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
  Size? _lastSize;
}
