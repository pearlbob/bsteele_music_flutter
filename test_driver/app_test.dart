// import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

import 'app.dart' as app;

void main() {
  group('bsteeleMusicApp', () {
    // First, define the Finders and use them to locate widgets from the
    // test suite. Note: the Strings provided to the `byValueKey` method must
    // be the same as the Strings we used for the Keys in step 1.
    // final searchTextFieldFinder = find.byValueKey('searchText');

    // late FlutterDriver driver;

    // Connect to the Flutter driver before running any tests.
    setUpAll(() async {
      // driver = await FlutterDriver.connect();
      // logger.i('driver here');
    });

    // Close the connection to the driver after the tests have completed.
    tearDownAll(() async {
      // driver.close();
    });

    test('starts with search text empty', () async {
      app.main();
      // Use the `driver.getText` method to verify the counter starts at 0.
      // expect(await driver.getText(searchTextFieldFinder), '');
    });
    //
    // // test('increments the counter', () async {
    // //   // First, tap the button.
    // //   await driver.tap(buttonFinder);
    // //
    // //   // Then, verify the counter text is incremented by 1.
    // //   expect(await driver.getText(counterTextFinder), "1");
    // // });
  });
}
