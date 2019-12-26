import 'package:flutter/material.dart';

import 'appData.dart';

class Player extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text('Player: '+_app.songTitle),
            ),
            body: Center(
                child: RaisedButton(
                    child: Text('Go back!'),
                    onPressed: () {
                        Navigator.pop(context);
                    },
                ),
            ),
        );
    }

    var _app = AppData();
}

