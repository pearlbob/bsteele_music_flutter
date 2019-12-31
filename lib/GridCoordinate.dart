 class GridCoordinate implements Comparable<GridCoordinate> {
    GridCoordinate(this._row, this._col) ;


  @override
    String toString() {
    return "(" + _row.toString() + "," + _col.toString() + ")";
  }

  @override
    bool equals(Object obj) {
    try {
      GridCoordinate o = obj as GridCoordinate;
      return _row == o._row && _col == o._col;
    } catch ( ex) {
    return false;
    }
  }


  @override
    int compareTo(GridCoordinate o) {
    if (_row != o._row) {
      return _row < o._row ? -1 : 1;
    }

    if (_col != o._col) {
      return _col < o._col ? -1 : 1;
    }
    return 0;
  }

  int get row => _row;
    final int _row;
    int get col => _col;
    final int _col;
}
