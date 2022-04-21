import 'dart:convert';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Show some data about the app and it's environment.
class CommunityJams extends StatefulWidget {
  const CommunityJams({Key? key}) : super(key: key);

  @override
  _CommunityJams createState() => _CommunityJams();

  static const String routeName = '/communityJams';
}

class _CommunityJams extends State<CommunityJams> with WidgetsBindingObserver {
  @override
  initState() {
    super.initState();

    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);

    ScreenInfo screenInfo = App().screenInfo;

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'Community Jams'),
      body: DefaultTextStyle(
        style: generateAppTextStyle(color: Colors.black87, fontSize: screenInfo.fontSize),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                app.messageTextWidget(AppKeyEnum.aboutErrorMessage),
                appSpace(),
                const Text(
                  'The bsteele Music App has been motivated by Community Jams.',
                ),
                Image(
                  image: const AssetImage('lib/assets/cj_qr_code.png'),
                  width: max(200,screenInfo.mediaWidth / 5),
                  height: max(200,screenInfo.mediaWidth / 5),
                  semanticLabel: "communityjams.org website",
                ),
                appWrapFullWidth(children: <Widget>[const Text(
                  'See ',
                ),
                InkWell(
                  onTap: () {
                    openLink('http://communityjams.org/');
                  },
                  child: Text(
                    'CommunityJams.org',
                    style: generateAppLinkTextStyle(fontSize: screenInfo.fontSize),
                  ),
                ),
                const Text(
                  '.',
                ),
              ],),
              ]),
        ),
      ),
    );
  }
}
