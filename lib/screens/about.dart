import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:package_info/package_info.dart';

/// Display the song moments in sequential order.
class About extends StatefulWidget {
  const About({Key key}) : super(key: key);

  @override
  _About createState() => _About();
}

class _About extends State<About> {
  @override
  initState() {
    super.initState();

    _readPackageInfo();
  }

  @override
  Widget build(BuildContext context) {
    ScreenInfo screenInfo = ScreenInfo(context);
    double fontSize = screenInfo.isTooNarrow ? 18 : 36;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'About the bsteele Music App',
          style: TextStyle(
              color: Colors.black87,
              fontSize: fontSize,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: DefaultTextStyle(
        style: TextStyle(color: Colors.black87, fontSize: fontSize),
        child: Container(
          padding: EdgeInsets.all(8.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                Text(
                  'The bsteele Music App has been written by bob.',
                  // textScaleFactor: textScaleFactor,
                ),
                Row(children: <Widget>[
                  Text(
                    'See ',
                    // textScaleFactor: textScaleFactor,
                  ),
                  InkWell(
                    onTap: () {
                      openLink('http://www.bsteele.com');
                    },
                    child: Text(
                      'bsteele.com',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ]),
                Text(
                  'appName: ${_packageInfo.appName ?? 'unknown'}',
                ),
                Text(
                  'version: ${_packageInfo.version ?? 'unknown'}',
                ),
                Text(
                  'packageName: ${_packageInfo.packageName ?? 'unknown'}',
                ),
                Text(
                  'buildNumber: ${_packageInfo.buildNumber ?? 'unknown'}',
                ),
              ]),
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

  void _readPackageInfo() async {
    if (kIsWeb) {
      _packageInfo = PackageInfo(
          appName: 'bsteele Music App',
          version: 'unknown, web workaround', // fixme
          packageName: 'unknown',
          buildNumber: '0');
    } else {
      _packageInfo = await PackageInfo.fromPlatform();
    }
  }

  PackageInfo _packageInfo;
}
