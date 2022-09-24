
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'app/app.dart';
import 'app/app_theme.dart';

final Map<String, String> cssSamplePropertyMap = {
  'color': 'black',

};

void main() async {
  Logger.level = Level.debug;

  //  read the css theme data prior to the first build
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme().init(); //  init the singleton
  generateCssDocumentation();

  Future.delayed(const Duration(seconds: 1), () {
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
  });
}

class CssToCssFileApp extends StatelessWidget {
  const CssToCssFileApp({Key? key}) : super(key: key);

  /// fake app just to compile in flutter
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bsteele Music App',
      theme: App().themeData,
      routes: const {},
    );
  }
}
