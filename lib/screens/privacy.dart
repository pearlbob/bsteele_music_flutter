import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';

/// Display the application's privacy policy
class Privacy extends StatefulWidget {
  const Privacy({super.key});

  @override
  PrivacyState createState() => PrivacyState();

  static const String routeName = 'privacy';
}

class PrivacyState extends State<Privacy> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);
    app.screenInfo.refresh(context);
    final double fontSize = app.screenInfo.fontSize;

    TextStyle style = generateAppTextStyle(color: Colors.black87, fontSize: fontSize);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: appWidgetHelper.backBar(title: 'bsteeleMusicApp Privacy Policy'),
      body: DefaultTextStyle(
        style: style,
        child: const SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: EdgeInsets.all(8.0),
          child: Text('The bsteeleMusicApp is a client side application.  '
              'In normal circumstances, neither the phone app nor the web application has '
              'any contact with the server after initialization.  '
              'If used in a local display sharing mode (leader/follower), no data '
              'other than the distribution of local song information '
              'is sent.  This can be disabled by placing the host IP to "None".'
              '\n\n'
              'No personal data is collected in any fashion at any server.  '
              'Data unique to your use, such as your user name or an entered song, '
              'is held either in phone memory local to your phone '
              'or in local storage on your browser.  '
              '\n\n'
              'Note that entered songs will contain your user name '
              'in their .songlyrics file.  '
              '\n\n'
              'Note that the app will try on initialization to access the internet '
              'to download the latest song list from www.bsteele.com.  '
              'Should this fail, a local copy will be used.'),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(),
    );
  }

  late AppWidgetHelper appWidgetHelper;
}
