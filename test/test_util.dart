import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TextFieldFinder extends MatchFinder {
  _TextFieldFinder(this._valueKeyString);

  @override
  String get description => '_TextFieldFinder: $_valueKeyString';

  @override
  bool matches(Element candidate) {
    logger.v('candidate: ${candidate.widget.runtimeType} ${candidate.widget.key}');
    if (candidate.widget is TextField) {
      return (candidate.widget.key is ValueKey && (candidate.widget.key as ValueKey).value == _valueKeyString);
    }
    return false;
  }

  final String _valueKeyString;
}

class _TextFieldByAppKeyFinder extends MatchFinder {
  _TextFieldByAppKeyFinder(this._appKey);

  @override
  String get description => '_TextFieldFinder: $_appKey';

  @override
  bool matches(Element candidate) {
    logger.v(
        'candidate: ${candidate.widget.runtimeType}, key: ${candidate.widget.key.runtimeType} ${candidate.widget.key},'
            ' match value: $_appKey');
    if (candidate.widget is TextField) {
      return (candidate.widget.key is ValueKey<String> &&
          (candidate.widget.key as ValueKey<String>).value == _appKey.name);
    }
    return false;
  }

  final AppKeyEnum _appKey;
}

class _TextValueKeyFinder extends MatchFinder {
  _TextValueKeyFinder(this._valueKeyString);

  @override
  String get description => '_TextValueKeyFinder: $_valueKeyString';

  @override
  bool matches(Element candidate) {
    return (candidate.widget is Text &&
        (candidate.widget as Text).data != null &&
        candidate.widget.key is ValueKey &&
        (candidate.widget.key as ValueKey).value == _valueKeyString);
  }

  final String _valueKeyString;
}

class _TextByAppKeyFinder extends MatchFinder {
  _TextByAppKeyFinder(this._appKey);

  @override
  String get description => '_TextValueKeyFinder: $_appKey';

  @override
  bool matches(Element candidate) {
    // if (candidate.widget is Text) {
    //   logger.i('_TextByAppKeyFinder(): $_appKey match?: ${candidate.widget.key.runtimeType} $candidate');
    // }
    return (candidate.widget is Text &&
        (candidate.widget as Text).data != null &&
        candidate.widget.key is ValueKey<String> &&
        (candidate.widget.key as ValueKey<String>).value == _appKey.name);
  }

  final AppKeyEnum _appKey;
}

class _TextValueKeyContainsFinder extends MatchFinder {
  _TextValueKeyContainsFinder(this._valueKeyString) : super(skipOffstage: false);

  @override
  String get description => '_TextValueKeyContainsFinder: $_valueKeyString';

  @override
  bool matches(Element candidate) {
    return (candidate.widget.key is ValueKey<String> &&
        (candidate.widget.key as ValueKey<String>).value.toString().contains(_valueKeyString));
  }

  final String _valueKeyString;
}

class _TextContainsFinder extends MatchFinder {
  _TextContainsFinder(this._value) : super(skipOffstage: false);

  @override
  String get description => '_TextContainsFinder: $_value';

  @override
  bool matches(Element candidate) {
    return (candidate.widget is Text &&
        (candidate.widget as Text).data != null &&
        (candidate.widget as Text).data!.contains(_value));
  }

  final String _value;
}

class DropDownFinder extends MatchFinder {
  DropDownFinder(this._valueKeyString);

  @override
  String get description => '_DropDownFinder: $_valueKeyString';

  @override
  bool matches(Element candidate) {
    return (candidate.widget is DropdownButton &&
        candidate.widget.key is ValueKey &&
        (candidate.widget.key as ValueKey).value == _valueKeyString);
  }

  final String _valueKeyString;
}

class DropDownFinderByAppKey extends MatchFinder {
  DropDownFinderByAppKey(this._appKey);

  @override
  String get description => 'DropDownFinderByAppKey: $_appKey';

  @override
  bool matches(Element candidate) {
    //logger.i( 'DropDownFinderByAppKey(): try $candidate');
    return (candidate.widget is DropdownButton &&
        candidate.widget.key is ValueKey<String> &&
        (candidate.widget.key as ValueKey<String>).value == _appKey.name);
  }

  final AppKeyEnum _appKey;
}

class Find {
  static TextField findTextField(String valueKeyString) {
    var _textFieldFinder = _TextFieldFinder(valueKeyString);
    expect(_textFieldFinder, findsOneWidget);
    var ret = _textFieldFinder.evaluate().last.widget as TextField;
    expect(ret.controller, isNotNull);
    return ret;
  }

  static TextField findTextFieldByAppKey(AppKeyEnum appKeyEnum) {
    var _textFieldFinder = _TextFieldByAppKeyFinder(appKeyEnum);
    expect(_textFieldFinder, findsOneWidget);
    var ret = _textFieldFinder.evaluate().last.widget as TextField;
    expect(ret.controller, isNotNull);
    return ret;
  }

  static Text findValueKeyText(String valueKeyString) {
    var finder = _TextValueKeyFinder(valueKeyString);
    expect(finder, findsOneWidget);
    var ret = finder.evaluate().first.widget as Text;
    return ret;
  }

  static Text findTextByAppKey(AppKeyEnum appKeyEnum) {
    var finder = _TextByAppKeyFinder(appKeyEnum);
    expect(finder, findsOneWidget);
    var ret = finder.evaluate().first.widget as Text;
    return ret;
  }

  static List<Text> findTextContains(String value) {
    var finder = _TextContainsFinder(value);
    expect(finder, findsWidgets);
    List<Text> ret = [];
    for (var w in finder.evaluate()) {
      ret.add(w.widget as Text);
    }
    return ret;
  }

  static List<Widget> findValueKeyContains(String value, {bool findSome = true}) {
    var finder = _TextValueKeyContainsFinder(value);
    if (findSome) {
      expect(finder, findsWidgets);
    }
    List<Widget> ret = [];
    for (var w in finder.evaluate()) {
      ret.add(w.widget);
    }
    return ret;
  }

  static DropdownButton<music_key.Key> findDropDown(String valueKeyString) {
    var _textFinder = DropDownFinder(valueKeyString);
    expect(_textFinder, findsOneWidget);
    var ret = _textFinder.evaluate().first.widget as DropdownButton<music_key.Key>;
    return ret;
  }

  static DropdownButton<music_key.Key> findDropDownByAppKey(AppKeyEnum appKeyEnum) {
    var _textFinder = DropDownFinderByAppKey(appKeyEnum);
    expect(_textFinder, findsOneWidget);
    var ret = _textFinder.evaluate().first.widget as DropdownButton<music_key.Key>;
    return ret;
  }

// static Widget findGlobalObjectKeyWidget(String valueKeyString) {
//   var _textFinder = _GlobalObjectKeyFinder(valueKeyString);
//   expect(_textFinder, findsOneWidget);
//   return _textFinder.evaluate().first.widget;
// }
}
