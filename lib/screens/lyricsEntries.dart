import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/lyricSection.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:flutter/material.dart';

typedef _LyricsEntriesCallback = void Function(); //  structural change
typedef OnLyricsLineChangedCallback = void Function(); //  text content change

LyricSection? _focusLyricSection;
int _focusLyricsLineIndex = 0;

/// used in the edit screen to manage the lyrics entry and its matching to the chord section sequence
class LyricsEntries extends ChangeNotifier {
  LyricsEntries() : _song = Song.createEmptySong() {
    _focusLyricSection = null;
  }

  LyricsEntries.fromSong(this._song,
      {OnLyricsLineChangedCallback? onLyricsLineChangedCallback, TextStyle? textStyle})
      : _onLyricsLineChangedCallback = onLyricsLineChangedCallback,
        _textStyle = textStyle {
    _focusLyricSection = null;
    updateEntriesFromSong();
    logger.v('LyricsEntries.fromSong: lyrics: ${_song.lyricsAsString().replaceAll('\n', '\\n')}');
    logger.v('LyricsEntries.fromSong: rawLyrics: ${_song.rawLyrics.replaceAll('\n', '\\n')}');
  }

  void updateEntriesFromSong() {
    _entries.clear();
    for (final lyricSection in _song.lyricSections) {
      _entries.add(_LyricsDataEntry.fromSong(
        lyricSection,
        _lyricsEntriesCallback,
        onLyricsLineChangedCallback: _onLyricsLineChangedCallback,
        textStyle: _textStyle,
      ));
    }
    logger.v('LyricsEntries.fromSong()');
    logger.v('_asLyricsEntry():\n<${asRawLyrics()}>');
  }

  String asRawLyrics() {
    var sb = StringBuffer();
    for (final entry in _entries) {
      sb.writeln(entry.lyricSection.sectionVersion.toString());
      for (final line in entry._lyricsLines) {
        if (line.text.isEmpty) {
          sb.write('\n'); //  avoid double newline
          if (identical(line, entry._lyricsLines.last)) {
            //  avoid the last empty line being consumed by the lyrics parser at the end of a section
            sb.write('\n');
          }
        } else {
          sb.writeln(line.text);
        }
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
    logger.v('_lyricsEntriesCallback.notifyListeners()');
    notifyListeners();
  }

  bool hasChangedLines() {
    for (var entry in _entries) {
      if (entry._hasChangedLines()) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    assert(hasListeners == false);
    super.dispose();
  }

  final Song _song;
  OnLyricsLineChangedCallback? _onLyricsLineChangedCallback;

  List<_LyricsDataEntry> get entries => _entries;
  final List<_LyricsDataEntry> _entries = [];
  TextStyle? _textStyle;
}

typedef _LyricsLineCallback = void Function(_LyricsLine line, List<String> lines);

class _LyricsDataEntry {
  _LyricsDataEntry.fromSong(
    this.lyricSection,
    _LyricsEntriesCallback? lyricsEntriesCallback, {
    OnLyricsLineChangedCallback? onLyricsLineChangedCallback,
    TextStyle? textStyle,
  })  : _textStyle = textStyle,
        _lyricsEntriesCallback = lyricsEntriesCallback {
    if (lyricSection.lyricsLines.isNotEmpty
        //  note: allow empty (blank) lines, i.e. lyricSection.lyricsLines.first can be empty
        ) {
      _lyricsLines = List.from(lyricSection.lyricsLines)
          .map((line) => _LyricsLine(line, _lyricsLineCallback,
              onLyricsLineChangedCallback: onLyricsLineChangedCallback, textStyle: _textStyle))
          .toList();

      //  copy the focus
      if (_focusLyricSection?.sectionVersion == lyricSection.sectionVersion &&
          _focusLyricSection?.index == lyricSection.index &&
          _lyricsLines.isNotEmpty) {
        _lyricsLines[min(_focusLyricsLineIndex, _lyricsLines.length - 1)].requestFocus();
      }
    }
  }

  _LyricsDataEntry._fromChordSection(ChordSection chordSection, int index,
      {TextStyle? textStyle, _LyricsEntriesCallback? lyricsEntriesCallback})
      : lyricSection = LyricSection(chordSection.sectionVersion, index),
        _textStyle = textStyle,
        _lyricsEntriesCallback = lyricsEntriesCallback;

  ///
  void _lyricsLineCallback(_LyricsLine oldLyricsLine, final List<String> newLyricsLines) {
    var index = _lyricsLines.indexOf(oldLyricsLine);
    if (index < 0) {
      throw 'cannot find: <oldLyricsLine> in $_lyricsLines';
    }
    if (newLyricsLines.length > 1) {
      logger.d('_lyricsLineCallback: $this: $index: $oldLyricsLine, lines: $newLyricsLines)');
      var removed = _lyricsLines.remove(oldLyricsLine);
      logger.d('removed: $removed $oldLyricsLine');
      _LyricsLine? lastNewLyricsLine;
      var newIndex = index;
      for (var newLyricsLine in newLyricsLines) {
        lastNewLyricsLine = _LyricsLine(newLyricsLine, _lyricsLineCallback, textStyle: _textStyle);
        _lyricsLines.insert(newIndex++, lastNewLyricsLine);
      }
      logger.d('newLines: $_lyricsLines');
      logger.d('lastNewLyricsLine: <$lastNewLyricsLine> requestFocus():'
          ' $lyricSection $index+${newLyricsLines.length - 1}');
      lastNewLyricsLine!.requestFocus();
    }
    _focusLyricSection = lyricSection;
    _focusLyricsLineIndex = index + newLyricsLines.length - 1;
    if (_lyricsEntriesCallback != null) {
      logger.v('newLines: _lyricsEntriesCallback()');
      _lyricsEntriesCallback!();
    }
  }

  TextField textFieldAt(int i) {
    return _lyricsLines[i].textField;
  }

  void addEmptyLine({TextStyle? textStyle}) {
    var lyricsLine = _LyricsLine('', _lyricsLineCallback, textStyle: textStyle);
    _lyricsLines.add(lyricsLine);
    _focusLyricSection = lyricSection;
    _focusLyricsLineIndex = _lyricsLines.length - 1;
    lyricsLine.requestFocus();
  }

  bool _hasChangedLines() {
    for (var line in _lyricsLines) {
      if (line._hasChanged()) {
        return true;
      }
    }
    return false;
  }

  Key keyForLine(int line, String id) {
    return ValueKey('lyrics_$lyricSection:$line:$id');
  }

  Key get key => ValueKey('lyrics_$lyricSection');

  Key get deleteKey => ValueKey('lyrics_delete_$lyricSection');

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
    lineText,
    this._lyricsLineCallback, {
    OnLyricsLineChangedCallback? onLyricsLineChangedCallback,
    TextStyle? textStyle,
  }) : _onLyricsLineChangedCallback = onLyricsLineChangedCallback {
    _originalText = lineText.replaceAll('\n', '');
    _controller = TextEditingController(text: _originalText);
    _textField = TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: textStyle,
      keyboardType: TextInputType.text,
      minLines: 1,
      //  arbitrary, large limit:
      maxLines: 300,
      onSubmitted: (value) {
        //  deal with newlines
        logger.d('onSubmitted(\'$value\')');
        _submitLine();
      },
      onChanged: (value) {
        logger.d('onChanged(\'$value\'), ${_focusNode.hasFocus}');
        if (_onLyricsLineChangedCallback != null) {
          _onLyricsLineChangedCallback!();
        }
        // _updateFromController();
      },
      // onEditingComplete: () {
      //   logger.d('onEditingComplete(\'${_controller.text}\')');
      // },
    );
  }

  /// bad idea
  // void _updateFromController() {
  //   //  split into lines
  //   logger.i('_updateFromController(): <${_controller.text}>');
  //
  //   List<String> ret = [];
  //   ret.add(_controller.text);
  //   //  update
  //   _lyricsLineCallback(this, ret);
  // }

  void _submitLine() {
    var selection = _controller.selection;
    var text = _controller.text;

    //  split into lines
    List<String> ret = text.split('\n');

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

  bool _hasChanged() {
    return _originalText != _controller.text;
  }

  @override
  String toString() {
    return '\'${_controller.text}\'';
  }

  requestFocus() {
    _focusNode.requestFocus();
  }

  ///
  ///   @override
  ///   void dispose() {
  ///     _node.removeListener(_handleFocusChange);
  ///     // The attachment will automatically be detached in dispose().
  ///     _node.dispose();
  ///     super.dispose();
  ///   }

  final FocusNode _focusNode = FocusNode();

  TextField get textField => _textField;
  late final TextField _textField;
  final _LyricsLineCallback _lyricsLineCallback;
  final OnLyricsLineChangedCallback? _onLyricsLineChangedCallback;

  String get text => _controller.text;
  late final TextEditingController _controller;
  late final String _originalText;
}
