import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/features/news_tab/news_tab_screen.dart';

void main() {
  testWidgets('bundled news articles render without a network source', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildWarangTheme(Brightness.light),
        home: const NewsTabScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('News'), findsOneWidget);
    expect(find.text('Leave a little room for the unexpected'), findsOneWidget);
    expect(find.text('Your book stays with you'), findsOneWidget);
  });
}
