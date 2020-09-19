import 'package:bsteele_music_flutter/util/screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Display the application's privacy policy
class Privacy extends StatefulWidget {
  const Privacy({Key key}) : super(key: key);

  @override
  _Privacy createState() => _Privacy();
}

class _Privacy extends State<Privacy> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ScreenInfo screenInfo = ScreenInfo(context);
    final double fontSize = screenInfo.isTooNarrow ? 16 : 24;

    TextStyle style = TextStyle(color: Colors.black87, fontSize: fontSize);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Music App Privacy Policy',
          style: TextStyle(color: Colors.black87, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: DefaultTextStyle(
        style: style,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: EdgeInsets.all(8.0),
          child: Text('The bsteele Music App is a client side application.'
              'Neither the phone app nor the web application has'
              'any contact with the server after initialization.'
              'If used in a local display sharing mode, no data'
              'other than the distribution of local song information'
              'is sent.'
              '\n\n'
              'Even as a webpage, the app is loaded from static pages '
              'on the server at the initialization. No other communication occurs.'
              '\n\n'
              'No personal data is collected in any fashion at any server. '
              'Data unique to your use, such as your user name or an entered song, '
              'is held either in phone memory local to your phone '
              'or in local storage on your browser.'
              '\n\n'
              'Note that entered songs will contain your user name '
              'in their .songlyrics file.'
              '\n\n'
              'Note that the app will try on initialization to access the internet '
              'to download the latest song list from www.bsteele.com.'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        tooltip: 'Back',
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}
