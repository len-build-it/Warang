// The News tab (S10): bundled postcards, and a visible message while the
// notes load or when there are none.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';
import 'package:warang/features/news_tab/news_tab_screen.dart';

void main() {
  Widget app(Widget home) =>
      MaterialApp(theme: buildWarangTheme(Brightness.light), home: home);

  testWidgets('bundled news articles render without a network source', (
    tester,
  ) async {
    await tester.pumpWidget(app(const NewsTabScreen()));
    await tester.pumpAndSettle();

    expect(find.text('News'), findsOneWidget);
    expect(find.text('Leave a little room for the unexpected'), findsOneWidget);
    expect(find.text('Your book stays with you'), findsOneWidget);
    // Each note is a postcard with a stamp in its corner, and its kind is
    // written in sentence case.
    expect(find.byType(WarangStamp), findsNWidgets(3));
    expect(find.text('Travel note'), findsOneWidget);
    expect(find.text('TRAVEL NOTE'), findsNothing);
  });

  testWidgets('while loading, a message instead of a lone spinner', (
    tester,
  ) async {
    final pending = Completer<List<NewsListEntry>>();
    await tester.pumpWidget(app(NewsTabScreen(entries: pending.future)));
    await tester.pump();
    expect(find.text('Unpacking the postcards'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('No postcards yet'), findsOneWidget);
    expect(find.text('New notes arrive with app updates.'), findsOneWidget);
  });
}
