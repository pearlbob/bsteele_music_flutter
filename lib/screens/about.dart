import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double textScaleFactor = w / 1000;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'About bsteele Music',
        ),
        centerTitle: true,
      ),
      body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: TextDirection.ltr,
          children: <Widget>[
            Text(
              'bsteele music has been written by bob.',
              textScaleFactor: textScaleFactor,
            ),
          ]),
    );
  }
}
