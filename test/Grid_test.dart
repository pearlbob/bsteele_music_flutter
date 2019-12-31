import 'package:bsteele_music_flutter/Grid.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  Logger.level = Level.warning;
  Logger _logger = new Logger();

  test("test set", () {
    Grid<int> grid = new Grid();

    expect("Grid{[]}", grid.toString());
    grid.clear();
    expect("Grid{[]}", grid.toString());


    grid.set(0,0, 1);
    expect("Grid{[[1]]}", grid.toString());
    grid.set(0,0, 1);
    expect("Grid{[[1]]}", grid.toString());
    grid.set(0,1, 2);
    expect("Grid{[[1], [2]]}", grid.toString());
    grid.set(0,3, 4);
    expect("Grid{[[1], [2], [], [4]]}", grid.toString());
    grid.set(2,3, 4);
    expect("Grid{[[1], [2], [], [4, null, 4]]}", grid.toString());
    grid.set(-2,3, 444);
    expect("Grid{[[1], [2], [], [444, null, 4]]}", grid.toString());
    grid.set(-2,-3, 555);
    expect("Grid{[[555], [2], [], [444, null, 4]]}", grid.toString());

    grid.clear();
    expect("Grid{[]}", grid.toString());
    grid.set(4,0, 1);
    expect("Grid{[[null, null, null, null, 1]]}", grid.toString());
    grid.clear();
    expect("Grid{[]}", grid.toString());
    grid.set(0,4, 1);
    expect("Grid{[[], [], [], [], [1]]}", grid.toString());

    grid.clear();
    expect("Grid{[]}", grid.toString());
  });

  test("test get", () {
    Grid<int> grid = new Grid();

    expect("Grid{[]}", grid.toString());
    expect(grid.get(0, 0),isNull);
    expect(grid.get(1000, 0),isNull);
    expect(grid.get(1000, 2345678),isNull);
    expect(grid.get(-1, -12),isNull);

    grid.set(0,0, 1);
    grid.set(0,1, 5);
    grid.set(0,3, 9);
    grid.set(3,3, 12);
    _logger.d(grid.toString());
    expect(grid.toString(), "Grid{[[1], [5], [], [9, null, null, 12]]}" );
    expect( 1,grid.get(0,0));
    expect(grid.get(3,0),isNull);
    expect( 5,grid.get(0,1));
    expect(grid.get(1,1),isNull);

    expect( 9,grid.get(0,3));
    expect(grid.get(1,3),isNull);
    expect(grid.get(2,3),isNull);
    expect(12,grid.get(3,3));
    expect(grid.get(4,3),isNull);
  });
}