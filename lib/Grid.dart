

/// A generic grid used to store data presentations to the user.
/// Grid locations are logically assigned without the details of the UI mapping.
class Grid<T> {

  /// Deep copy, not as a constructor
  Grid<T> deepCopy(Grid<T> other) {
    if (other == null) return null;
    int rLimit = other.getRowCount();
    for (int r = 0; r < rLimit; r++) {
      List<T> row = other.getRow(r);
      int colLimit = row.length;
      for (int c = 0; c < colLimit; c++) {
        set(c, r, row[c]);
      }
    }
    return this;
  }

  bool get isEmpty => grid.isEmpty;

  void set(int x, int y, T t) {
    if (x < 0) x = 0;
    if (y < 0) y = 0;

    while (y >= grid.length) {
      //  addTo a new row to the grid
      grid.add( List<T>());
    }

    List<T> row = grid[y];
    if (x == row.length)
      row.add(t);
    else {
      while (x > row.length - 1)
        row.add(null);
      row[x]=t;
    }
  }

  @override
  String toString() {
    return "Grid{" + grid.toString() + '}';
  }

  T get(int x, int y) {
    try {
      List<T> row = grid[y];
      if (row == null) {
        return null;
      }
      return row[x];
    } catch (ex) {
      return null;
    }
  }

  int getRowCount() {
    return grid.length;
  }

  List<T> getRow(int y) {
    try {
      return grid[y];
    } catch (ex) {
      return null;
    }
  }

  void clear() {
    grid.clear();
  }

  final List<List<T>> grid = List();
}
