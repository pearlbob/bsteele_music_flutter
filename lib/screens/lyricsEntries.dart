import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/lyricSection.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

typedef _LyricsEntriesCallback = void Function();

/// used in the edit screen to manage the lyrics entry and its matching to the chord section sequence
class LyricsEntries extends ChangeNotifier {
  LyricsEntries();

  LyricsEntries.fromSong(Song song, {TextStyle? textStyle}) : _textStyle = textStyle {
    for (final lyricSection in song.lyricSections) {
      _entries.add(
          _LyricsDataEntry.fromSong(lyricSection, textStyle: textStyle, lyricsEntriesCallback: _lyricsEntriesCallback));
    }
    logger.v('LyricsEntries.fromSong()');
    logger.v('_asLyricsEntry():\n<${asRawLyrics()}>');
  }

  String asRawLyrics() {
    var sb = StringBuffer();
    for (final entry in _entries) {
      sb.writeln(entry.lyricSection.sectionVersion.toString());
      for (final line in entry._lyricsLines) {
        sb.writeln(line.text);
      }
    }
    return sb.toString();
  }

  void insertChordSection(_LyricsDataEntry entry, ChordSection chordSection) {
    var index = _entries.indexOf(entry);
    if (index >= 0) {
      _entries.insert(
          index,
          _LyricsDataEntry._fromChordSection(chordSection, index,
              textStyle: _textStyle, lyricsEntriesCallback: _lyricsEntriesCallback));
    }
  }

  void addChordSection(ChordSection chordSection) {
    _entries.add(_LyricsDataEntry._fromChordSection(chordSection, _entries.length,
        textStyle: _textStyle, lyricsEntriesCallback: _lyricsEntriesCallback));
  }

  // void moveChordSection(_LyricsDataEntry entry, {bool isUp = false}) {
  //   if (__entries.length <= 1) {
  //     return;
  //   }
  //   var chordSectionNumber = entry.index;
  //   if (isUp) {
  //     if (chordSectionNumber <= 0) {
  //       return;
  //     }
  //     var topSectionNumber = chordSectionNumber - 1;
  //     var bottomSectionNumber = chordSectionNumber;
  //     var topLines = __entries[topSectionNumber].lines;
  //     var bottomLines = __entries[bottomSectionNumber].lines;
  //     if (topLines.isNotEmpty) {
  //       var line = topLines.removeLast();
  //       bottomLines.insert(0, line);
  //       __entries[topSectionNumber].lines = topLines;
  //       __entries[bottomSectionNumber].lines = bottomLines;
  //     }
  //   } else {
  //     //  down
  //     if (chordSectionNumber <= 0) {
  //       return;
  //     }
  //     var topSectionNumber = chordSectionNumber - 1;
  //     var bottomSectionNumber = chordSectionNumber;
  //     var topLines = __entries[topSectionNumber].lines;
  //     var bottomLines = __entries[bottomSectionNumber].lines;
  //     if (bottomLines.isNotEmpty) {
  //       var line = bottomLines.removeAt(0);
  //       topLines.add(line);
  //       __entries[topSectionNumber].lines = topLines;
  //       __entries[bottomSectionNumber].lines = bottomLines;
  //     }
  //   }
  // }

  void moveLyricLine(LyricSection lyricSection, int line, {bool isUp = false}) {
    logger.d('_Lyrics_entries._moveLyricLine( $lyricSection, line: $line, isUp: $isUp )');
    if (_entries.length <= 1) {
      return;
    }
    var chordSectionNumber = lyricSection.index;
    if (isUp) {
      //  up
      if (chordSectionNumber <= 0) {
        return;
      }
      var topSectionNumber = chordSectionNumber - 1;
      var bottomSectionNumber = chordSectionNumber;
      var topLines = _entries[topSectionNumber]._lyricsLines;
      var bottomLines = _entries[bottomSectionNumber]._lyricsLines;
      for (var i = 0; i <= line; i++) {
        if (bottomLines.isEmpty) {
          break;
        }
        var lyrics = bottomLines.removeAt(0);
        topLines.add(lyrics);
      }
      _entries[topSectionNumber]._lyricsLines = topLines;
      _entries[bottomSectionNumber]._lyricsLines = bottomLines;
    } else {
      //  down
      if (chordSectionNumber >= _entries.length - 1) {
        return;
      }
      var topSectionNumber = chordSectionNumber;
      var bottomSectionNumber = chordSectionNumber + 1;
      var topLines = _entries[topSectionNumber]._lyricsLines;
      var bottomLines = _entries[bottomSectionNumber]._lyricsLines;

      for (var i = topLines.length - 1; i >= line; i--) {
        if (topLines.isEmpty) {
          break;
        }
        var lyrics = topLines.removeLast();
        bottomLines.insert(0, lyrics);
      }
      _entries[topSectionNumber]._lyricsLines = topLines;
      _entries[bottomSectionNumber]._lyricsLines = bottomLines;
    }
  }

  void addBlankLyricsLine(_LyricsDataEntry entry) {
    logger.d('add lyrics line to $entry');
    entry.addEmptyLine(textStyle: _textStyle);
  }

  void deleteLyricLine(
    _LyricsDataEntry entry,
    int i,
  ) {
    logger.d('delete lyrics line at $entry, line $i');
    entry._lyricsLines.removeAt(i);
  }

  void delete(_LyricsDataEntry entry) {
    _entries.remove(entry);
  }

  void _lyricsEntriesCallback() {
    notifyListeners();
  }

  List<_LyricsDataEntry> get entries => _entries;
  final List<_LyricsDataEntry> _entries = [];
  TextStyle? _textStyle;
}

typedef _LyricsLineCallback = void Function(_LyricsLine line, List<String> lines);

class _LyricsDataEntry {
  _LyricsDataEntry.fromSong(this.lyricSection, {TextStyle? textStyle, _LyricsEntriesCallback? lyricsEntriesCallback})
      : _textStyle = textStyle,
        _lyricsEntriesCallback = lyricsEntriesCallback {
    if (lyricSection.lyricsLines.isNotEmpty && lyricSection.lyricsLines.first.isNotEmpty) {
      _lyricsLines = List.from(lyricSection.lyricsLines)
          .map((value) => _LyricsLine(value, _lyricsLineCallback, textStyle: _textStyle))
          .toList();

      //  deal with the last extra line from lyrics
      if (_lyricsLines.last.text.isEmpty) {
        _lyricsLines.removeAt(_lyricsLines.length - 1);
      }
    }
  }

  _LyricsDataEntry._fromChordSection(ChordSection chordSection, int index,
      {TextStyle? textStyle, _LyricsEntriesCallback? lyricsEntriesCallback})
      : lyricSection = LyricSection(chordSection.sectionVersion, index),
        _textStyle = textStyle,
        _lyricsEntriesCallback = lyricsEntriesCallback;

  void _lyricsLineCallback(_LyricsLine oldLyricsLine, List<String> newLyricsLines) {
    var index = _lyricsLines.indexOf(oldLyricsLine);
    if (index >= 0) {
      logger.d('$this: $index: $oldLyricsLine, lines: $newLyricsLines)');
      switch (newLyricsLines.length) {
        case 0:
        case 1:
          //  do nothing
          break;
        default:
         var removed = _lyricsLines.remove(oldLyricsLine);
         logger.d( 'removed: $removed $oldLyricsLine');
          _LyricsLine? lastNewLyricsLine;
          for (var newLyricsLine in newLyricsLines) {
            lastNewLyricsLine = _LyricsLine(newLyricsLine, _lyricsLineCallback, textStyle: _textStyle);
            _lyricsLines.insert(index++, lastNewLyricsLine);
          }
          logger.d('newLines: $_lyricsLines');
          lastNewLyricsLine!.requestFocus();
          if (_lyricsEntriesCallback != null) {
            _lyricsEntriesCallback!();
          }
          break;
      }
    }
  }

  TextField textFieldAt(int i) {
    return _lyricsLines[i].textField;
  }

  void addEmptyLine({TextStyle? textStyle}) {
    var lyricsLine = _LyricsLine('', _lyricsLineCallback, textStyle: textStyle);
    _lyricsLines.add(lyricsLine);
    lyricsLine.requestFocus();
  }

  @override
  String toString() {
    return 'LyricsDataEntry{ $lyricSection: lines: ${_lyricsLines.length} }';
  }

  final LyricSection lyricSection;
  int? initialGridRowIndex;
  final TextStyle? _textStyle;
  final _LyricsEntriesCallback? _lyricsEntriesCallback;

  int get length => _lyricsLines.length;
  List<_LyricsLine> _lyricsLines = [];
}

// Define a custom text field for lyrics.
class _LyricsLine {
  _LyricsLine(
    this.originalText,
    this._lyricsLineCallback, {
    TextStyle? textStyle,
  }) : _controller = TextEditingController(text: originalText) {
    _textField = TextField(
      controller: _controller,
      focusNode: focusNode,
      style: textStyle,
      keyboardType: TextInputType.text,
      minLines: 1,
      //  arbitrary, large limit:
      maxLines: 300,
      onSubmitted: (value) {
        // print('onSubmitted(\'$value\')');
        _submit(value);
      },
      onChanged: (value) {
        // logger.i('onChanged(\'$value\')');
        // print('onChanged(\'$value\')');
        _update(_controller.text);
      },
    );
    focusNode.addListener(() {
      _update(_controller.text);
    });
  }

  void _update(String value) {
    //  split into lines
    List<String> ret = _controller.text.split('\n');

    // trim white space
    for (var value in ret) {
      value = value.trim();
    }
    if (ret.length > 1 || ret[0] != originalText) {
      //  update
      _lyricsLineCallback(this, ret);
    }
  }

  void _submit(String value) {
    var selection = _controller.selection;
    var text = _controller.text;

    //  split into lines
    List<String> ret = text.split('\n');

    // trim white space
    for (var value in ret) {
      value = value.trim();
    }
    if (ret.length > 1) {
      //  split multiple lines
    } else if (selection.baseOffset == text.length && selection.extentOffset == text.length) {
      //  blank newline at the end
      ret.add('');
    } else if (selection.baseOffset == 0 && selection.extentOffset == 0) {
      //  newline at the start
      ret.insert(0, '');
    } else {
      //  split an existing line
      ret.clear();
      ret.add(text.substring(0, selection.baseOffset).trim());
      ret.add(text.substring(selection.extentOffset).trim());
    }
    _lyricsLineCallback(this, ret);
  }

  @override
  String toString() {
    return '\'${_controller.text}\'';
  }

  requestFocus() {
    focusNode.requestFocus();
  }

  final FocusNode focusNode = FocusNode();

  TextField get textField => _textField;
  late final TextField _textField;
  final _LyricsLineCallback _lyricsLineCallback;

  String get text => _controller.text;
  final TextEditingController _controller;
  final String originalText;
}
