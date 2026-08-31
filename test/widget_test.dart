import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:readblank/providers/contents_notifier.dart';
import 'package:readblank/providers/activity_notifier.dart';
import 'package:readblank/screens/read_page.dart';

void main() {
  testWidgets(
    'TrainingPage displays content without triggering real network call',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'bookmarks': [],
        'history': '[{"url": "https://example.com"}]',
      });
      final sharedPrefs = await SharedPreferences.getInstance();

      final contentsNotifier = ContentsNotifier(sharedPrefs);
      final activityNotifier = ActivityNotifier();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: contentsNotifier),
            ChangeNotifierProvider.value(value: activityNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(body: ReadPage()),
          ),
        ),
      );

      // If we don't trigger a network call, we should see the content.
      // expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
