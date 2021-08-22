import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:csslib/visitor.dart' as visitor;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'app/app_theme.dart';

final Map<Type, String> cssSampleValueMap = {
  Color: '#2196f3',
  visitor.LengthTerm: '14px',
};
final Map<String, String> cssSamplePropertyMap = {
  'color': 'black',

};

void main() async {
  Logger.level = Level.info;

  //  read the css theme data prior to the first build
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme().init(); //  init the singleton
  generateCssDocumentation();
}

void generateCssDocumentation() {
  logger.i('CssToCssFile:');

  var sb = StringBuffer('''
/*
  bsteele Music App CSS style commands documentation
  
  Commands are listed in increasing priority order.
    
  Sample values used here:
''');
  for ( var type in cssSampleValueMap.keys ){
    sb.writeln('  sample $type: ${cssSampleValueMap[type]}');
  }
  sb.writeln('''

  Obviously in a real specification, not all values of a given type should be identical!
*/

''');
  CssSelectorType lastSelector = CssSelectorType.id;
  String lastSelectorName = '';
  SplayTreeSet<CssAction> sortedActions = SplayTreeSet();
  sortedActions.addAll(cssActions);
  for (var cssAction in sortedActions) {
    if (cssAction.cssProperty.selector != lastSelector || cssAction.cssProperty.selectorName != lastSelectorName) {
      if (lastSelectorName.isNotEmpty) {
        sb.writeln('}\n');
      }
      lastSelector = cssAction.cssProperty.selector;
      lastSelectorName = cssAction.cssProperty.selectorName;
      sb.writeln('${cssAction.cssProperty.selectorName} {');
    }
    var property = cssAction.cssProperty;
    var sampleValue = cssSamplePropertyMap[property.property] ?? cssSampleValueMap[property.type] ?? 'unknown property';
    sb.writeln('  ${property.property}: $sampleValue;'
        '\t\t\t/* type is ${property.type}, ${property.description} */');
  }
  if (lastSelectorName.isNotEmpty) {
    sb.writeln('}\n');
  }
  logger.i(sb.toString());

  Future.delayed(const Duration(milliseconds: 1000), () {
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
      theme: AppTheme().themeData,
      routes: const {},
    );
  }
}
