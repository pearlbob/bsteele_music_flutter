import 'package:flutter/material.dart';

import 'appOptions.dart';

class Player extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text('Player: debug: '+AppOptions().debug.toString()),
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
}

