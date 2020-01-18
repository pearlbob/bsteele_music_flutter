import 'package:bsteele_music_flutter/util/Screen.dart';
import 'package:flutter/cupertino.dart';
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
    double fontSize = screenInfo.isTooNarrow ? 18 : 48;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'About bsteele Music',
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
                  'bsteele music has been written by bob.',
                  // textScaleFactor: textScaleFactor,
                ),
                Text(
                  'appName: ${_packageInfo.appName}',
                ),
                Text(
                  'version: ${_packageInfo.version}',
                ),
                Text(
                  'packageName: ${_packageInfo.packageName}',
                ),
                Text(
                  'buildNumber: ${_packageInfo.buildNumber}',
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
    _packageInfo = await PackageInfo.fromPlatform();
    setState(() {});
  }

  static const String unknown = "unknown";
  PackageInfo _packageInfo = PackageInfo(
      appName: unknown,
      version: unknown,
      packageName: unknown,
      buildNumber: unknown);
}
