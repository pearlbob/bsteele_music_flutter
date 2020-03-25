import 'package:bsteeleMusicLib/songs/songMoment.dart';
import 'package:flutter/material.dart';

/// helper class to help manage a song display
class RowLocation {
  RowLocation(this.songMoment, this.row, this.globalKey, this._beats);

  @override
  String toString() {
    return ('${row.toString()} ${globalKey.toString()}'
        ', ${songMoment.toString()}'
        ', beats: ${beats.toString()}'
        // ', dispY: ${dispY.toStringAsFixed(1)}'
        // ', h: ${height.toStringAsFixed(1)}'
        ', b/h: ${pixelsPerBeat.toStringAsFixed(1)}');
  }

  void _computePixelsPerBeat() {
    if (_height != null && beats != null && beats > 0) _pixelsPerBeat = _height / beats;
  }

  final SongMoment songMoment;
  final GlobalKey globalKey;
  final int row;

  set beats(value) {
    _beats = value;
    _computePixelsPerBeat();
  }

  int get beats => _beats;
  int _beats;

  double dispY;

  set height(value) {
    _height = value;
    _computePixelsPerBeat();
  }

  double get height => _height;
  double _height;

  double get pixelsPerBeat => _pixelsPerBeat;
  double _pixelsPerBeat;
}
