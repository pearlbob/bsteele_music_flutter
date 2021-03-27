import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/lyricSection.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// used in the edit screen to manage the lyrics entry and its matching to the chord section sequence
class LyricsEntries {
  LyricsEntries();

  LyricsEntries.fromSong(Song song, {TextStyle? textStyle}) : _textStyle = textStyle {
    for (final lyricSection in song.lyricSections) {
      _entries.add(LyricsDataEntry.fromSong(lyricSection, textStyle: textStyle));
    }
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

  void insertChordSection(LyricsDataEntry entry, ChordSection chordSection) {
    var index = _entries.indexOf(entry);
    if (index >= 0) {
      _entries.insert(index, LyricsDataEntry._fromChordSection(chordSection, index, textStyle: _textStyle));
    }
  }

  void addChordSection(ChordSection chordSection) {
    _entries.add(LyricsDataEntry._fromChordSection(chordSection, _entries.length, textStyle: _textStyle));
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

  void addBlankLyricsLine(LyricsDataEntry entry) {
    logger.d('add lyrics line to $entry');
    var line = _LyricsLineTextField(entry, entry.length, '', textStyle: _textStyle);
    entry._lyricsLines.add(line);
    line.requestFocus();
  }

  void deleteLyricLine(
    LyricsDataEntry entry,
    int i,
  ) {
    logger.d('delete lyrics line at $entry, line $i');
    entry._lyricsLines.removeAt(i);
  }

  void delete(LyricsDataEntry entry) {
    _entries.remove(entry);
  }

  List<LyricsDataEntry> get entries => _entries;
  List<LyricsDataEntry> _entries = [];
  TextStyle? _textStyle;
}

class LyricsDataEntry {
  LyricsDataEntry.fromSong(this.lyricSection, {TextStyle? textStyle}) {
    if (lyricSection.lyricsLines.isNotEmpty && lyricSection.lyricsLines.first.isNotEmpty) {
      var i = 0;
      _lyricsLines = List.from(lyricSection.lyricsLines)
          .map((value) => _LyricsLineTextField(this, i++, value, textStyle: textStyle))
          .toList();

      //  deal with the last extra line from lyrics
      if (_lyricsLines.last.text.isEmpty) {
        _lyricsLines.removeAt(_lyricsLines.length - 1);
      }
    }
  }

  LyricsDataEntry._fromChordSection(ChordSection chordSection, int index, {TextStyle? textStyle})
      : lyricSection = LyricSection(chordSection.sectionVersion, index);

  bool wasMultipleLines(int i, String value) {
    var lines = value.split('\n');
    logger.i('wasMultipleLines(): $lines');
    if (lines.length > 1) {
      //  convert multiple lines in the value to multiple text fields

      return true;
    }
    return false;
  }

  TextField textFieldAt(int i) {
    return _lyricsLines[i].textField;
  }

  @override
  String toString() {
    return '{ $lyricSection: lines: ${_lyricsLines.length} }';
  }

  final LyricSection lyricSection;
  int? initialGridRowIndex;

  int get length => _lyricsLines.length;
  List<_LyricsLineTextField> _lyricsLines = [];
}

// Define a custom text field for lyrics.
class _LyricsLineTextField {
  _LyricsLineTextField(LyricsDataEntry entry, int index, String text, {TextStyle? textStyle})
      : _controller = TextEditingController(text: text) {
    _textField = TextField(
      controller: _controller,
      focusNode: FocusNode(),
      style: textStyle,
      onSubmitted: (value) {
        var selection = _controller.selection;
        var text = _controller.text;
        List<String> ret = [];
        if (selection.baseOffset == text.length && selection.extentOffset == text.length) {
          ret.add(text.trim());
        } else if (selection.baseOffset == 0 && selection.extentOffset == 0) {
          //  newline at the start
          ret.add('');
          ret.add(text.trim());
        } else {
          ret.add(text.substring(0, selection.baseOffset).trim());
          ret.add(text.substring(selection.extentOffset).trim());
        }
        logger.i('onSubmitted($value): ${text.length}');
        logger.i('onSubmitted($value): (${selection.baseOffset}, ${selection.extentOffset}): $ret, ${ret.length}');
      },
    );
  }

  requestFocus() => focusNode.requestFocus();

  FocusNode focusNode = FocusNode();

  TextField get textField => _textField;
  late final TextField _textField;

  String get text => _controller.text;
  TextEditingController _controller;
}
