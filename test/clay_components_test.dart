// FEAT-003 Phase 4: the clay foundation and shared components, in both
// themes and with reduced motion.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warang/app/theme/components.dart';
import 'package:warang/app/theme/tokens.dart';

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool reduced = false,
}) => MaterialApp(
  theme: buildWarangTheme(brightness),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    ),
  ),
);

/// Horizontal scale factors of every Transform under [finder].
Iterable<double> _scales(WidgetTester tester, Finder finder) => tester
    .widgetList<Transform>(
      find.descendant(of: finder, matching: find.byType(Transform)),
    )
    .map((transform) {
      // The length of the x axis: 1 for pure rotations, the factor for scales.
      final m = transform.transform.storage;
      return math.sqrt(m[0] * m[0] + m[1] * m[1]);
    });

void main() {
  setUp(WarangStamp.resetSession);

  for (final brightness in Brightness.values) {
    for (final reduced in [false, true]) {
      final variant = '${brightness.name}${reduced ? ', reduced motion' : ''}';

      testWidgets('buttons run on release and use ink labels ($variant)', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          _host(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WarangButton.primary(label: 'Save', onPressed: () => taps++),
                const WarangButton.secondary(label: 'Edit'),
                const WarangButton.quiet(label: 'Cancel'),
                const WarangButton.danger(label: 'Delete'),
              ],
            ),
            brightness: brightness,
            reduced: reduced,
          ),
        );
        expect(tester.getSize(find.byType(WarangButton).first).height, 56);
        for (final label in ['Edit', 'Cancel', 'Delete']) {
          expect(
            tester.getSize(find.widgetWithText(WarangButton, label)).height,
            greaterThanOrEqualTo(48),
          );
        }
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          expect(text.style?.color, isNot(Colors.white), reason: text.data);
        }
        // Labels on the amber fill are light-theme ink in both themes.
        expect(
          tester.widget<Text>(find.text('Save')).style?.color,
          WarangColors.lightInk,
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Save')),
        );
        // Tap-down lands after the press timeout; then the press runs.
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 150));
        expect(taps, 0, reason: 'the action waits for release');
        final pressed = _scales(
          tester,
          find.widgetWithText(ClayPressable, 'Save'),
        );
        if (reduced) {
          expect(pressed.every((scale) => scale == 1), isTrue);
        } else {
          expect(pressed.any((scale) => scale < .97), isTrue);
        }
        await gesture.up();
        await tester.pump();
        expect(taps, 1, reason: 'the action runs on release, at once');
        await tester.pumpAndSettle();
      });

      testWidgets('fields show focus and errors beyond colour ($variant)', (
        tester,
      ) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          _host(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WarangField(label: 'Caption', focusNode: focus),
                const WarangField(
                  label: 'Trip name',
                  errorText: 'Trip name is required',
                ),
              ],
            ),
            brightness: brightness,
            reduced: reduced,
          ),
        );
        ClaySurface well(int index) => tester.widget<ClaySurface>(
          find
              .descendant(
                of: find.byType(WarangField).at(index),
                matching: find.byType(ClaySurface),
              )
              .first,
        );
        expect(find.text('Caption'), findsOneWidget);
        expect(well(0).outline?.width, 1);
        expect(tester.getSize(find.byType(ClaySurface).first).height, 56);

        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(well(0).outline?.color, WarangKeepsake.amber.fill);
        expect(well(0).outline?.width, 2);
        expect(well(0).press, closeTo(1, .01));

        expect(well(1).outline?.color, WarangKeepsake.gumamela.fill);
        expect(well(1).outline?.width, 2);
        expect(find.text('Trip name is required'), findsOneWidget);
      });

      testWidgets('stamps tilt by id and pop once per session ($variant)', (
        tester,
      ) async {
        const stamp = WarangStamp.count(
          id: 'moments',
          number: 12,
          word: 'moments',
          tone: WarangKeepsake.dagat,
        );
        expect(stamp.tiltDegrees, inInclusiveRange(-8, 8));
        expect(
          stamp.tiltDegrees,
          const WarangStamp.count(
            id: 'moments',
            number: 3,
            word: 'x',
            tone: WarangKeepsake.ube,
          ).tiltDegrees,
        );
        await tester.pumpWidget(
          _host(
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                stamp,
                WarangStamp.place(
                  id: 'place',
                  lines: ['Malay, Aklan', 'Sat 14 Mar'],
                  tone: WarangKeepsake.langit,
                ),
              ],
            ),
            brightness: brightness,
            reduced: reduced,
          ),
        );
        final first = _scales(tester, find.byType(WarangStamp).first).first;
        if (reduced) {
          expect(first, closeTo(1, .001));
        } else {
          expect(first, lessThan(.2), reason: 'it starts small and pops');
        }
        await tester.pumpAndSettle();
        expect(find.text('12'), findsOneWidget);
        expect(find.text('Malay, Aklan'), findsOneWidget);
        expect(tester.getSize(find.byType(WarangStamp).first).width, 84);

        // The same stamp shown again this session does not pop again.
        await tester.pumpWidget(_host(stamp, brightness: brightness));
        await tester.pumpWidget(
          _host(const SizedBox(), brightness: brightness),
        );
        await tester.pumpWidget(_host(stamp, brightness: brightness));
        final again = _scales(tester, find.byType(WarangStamp)).first;
        expect(again, closeTo(1, .001));
      });

      testWidgets('chips select with a check, not colour alone ($variant)', (
        tester,
      ) async {
        var selected = 0;
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            Wrap(
              children: [
                WarangChip(
                  label: 'Boracay',
                  tone: WarangKeepsake.dagat,
                  selected: true,
                  onSelected: () => selected++,
                ),
                WarangChip(label: 'Everyday', onSelected: () => selected++),
              ],
            ),
            brightness: brightness,
            reduced: reduced,
          ),
        );
        expect(
          find.descendant(
            of: find.widgetWithText(WarangChip, 'Boracay'),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is WarangIcon && widget.glyph == WarangGlyphs.check,
            ),
          ),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(find.text('Boracay')),
          isSemantics(isSelected: true),
        );
        expect(
          tester.getSize(find.byType(WarangChip).first).height,
          greaterThanOrEqualTo(36),
        );
        await tester.tap(find.text('Everyday'));
        await tester.pumpAndSettle();
        expect(selected, 1);
        handle.dispose();
      });

      testWidgets(
        'polaroids keep the photo flat and caption below ($variant)',
        (tester) async {
          await tester.pumpWidget(
            _host(
              const SizedBox(
                width: 240,
                child: WarangPolaroid(
                  photo: ColoredBox(
                    key: Key('photo'),
                    color: Color(0xFF336699),
                  ),
                  caption: 'Sunset at White Beach',
                ),
              ),
              brightness: brightness,
              reduced: reduced,
            ),
          );
          expect(find.text('Sunset at White Beach'), findsOneWidget);
          final caption = tester.widget<Text>(
            find.text('Sunset at White Beach'),
          );
          expect(caption.style?.fontFamily, WarangType.handFamily);
          expect(caption.maxLines, 2);
          // No colour filter or overlay sits over the photo.
          expect(find.byType(ColorFiltered), findsNothing);
          expect(
            find.ancestor(
              of: find.byKey(const Key('photo')),
              matching: find.byType(ClaySurface),
            ),
            findsOneWidget,
          );
          final photo = tester.getRect(find.byKey(const Key('photo')));
          final frame = tester.getRect(find.byType(WarangPolaroid));
          expect(photo.top - frame.top, 12);
          expect(frame.bottom - photo.bottom, 60);
        },
      );

      testWidgets('toggles show state with a check and semantics ($variant)', (
        tester,
      ) async {
        var value = false;
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            StatefulBuilder(
              builder: (context, setState) => WarangToggle(
                value: value,
                semanticLabel: 'Save map areas',
                onChanged: (next) => setState(() => value = next),
              ),
            ),
            brightness: brightness,
            reduced: reduced,
          ),
        );
        expect(tester.getSize(find.byType(WarangToggle)), const Size(52, 48));
        expect(find.byType(WarangIcon), findsNothing);
        await tester.tap(find.byType(WarangToggle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));
        if (!reduced) {
          // Mid-travel, the knob stretches wider than it rests.
          final knob = tester.getSize(find.byType(ClaySurface).last);
          expect(knob.width, greaterThan(26));
        }
        await tester.pumpAndSettle();
        expect(value, isTrue);
        expect(find.byType(WarangIcon), findsOneWidget);
        expect(tester.getSize(find.byType(ClaySurface).last).width, 26);
        expect(
          tester.getSemantics(find.byType(WarangToggle)),
          isSemantics(isToggled: true, hasToggledState: true),
        );
        handle.dispose();
      });

      testWidgets('toast offers undo inside the pill ($variant)', (
        tester,
      ) async {
        var undone = 0;
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showWarangSnackBar(
                  context,
                  'Moment deleted',
                  aboveNavigation: false,
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => undone++,
                  ),
                ),
                child: const Text('Delete'),
              ),
            ),
            brightness: brightness,
            reduced: reduced,
          ),
        );
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(find.byType(WarangToast), findsOneWidget);
        expect(
          tester.getSize(find.byType(WarangToast)).height,
          greaterThanOrEqualTo(56),
        );
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(undone, 1);
        expect(find.byType(WarangToast), findsNothing);
      });

      testWidgets(
        'speech bubbles are silent and leave on their own ($variant)',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            _host(
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WarangSpeechBubble(text: 'Hello!'),
                  WarangSpeechBubble(text: 'Stay', persistent: true),
                ],
              ),
              brightness: brightness,
              reduced: reduced,
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.bySemanticsLabel('Hello!'), findsNothing);
          final text = tester.widget<Text>(find.text('Hello!'));
          expect(text.style?.fontFamily, WarangType.handFamily);
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          double opacity(String label) => tester
              .widget<AnimatedOpacity>(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(AnimatedOpacity),
                ),
              )
              .opacity;
          expect(opacity('Hello!'), 0);
          expect(opacity('Stay'), 1);
          handle.dispose();
        },
      );

      testWidgets('sheets have the handle, top radius, and dimmer ($variant)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showWarangSheet<void>(
                  context,
                  builder: (context) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Sheet body'),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
            brightness: brightness,
            reduced: reduced,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Sheet body'), findsOneWidget);
        final frame = tester.widget<ClaySurface>(
          find
              .descendant(
                of: find.byType(WarangSheetFrame),
                matching: find.byType(ClaySurface),
              )
              .first,
        );
        expect(
          frame.borderRadius.topLeft,
          const Radius.circular(WarangRadius.sheet),
        );
        expect(frame.bottomSheet, isTrue);
        final barrier = tester.widget<ModalBarrier>(
          find.byType(ModalBarrier).last,
        );
        expect(barrier.color, warangDimmer(brightness));
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('Sheet body'), findsNothing);
      });
    }
  }

  testWidgets('reduced motion leaves no animation running', (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WarangStamp.count(
              id: 'still',
              number: 1,
              word: 'trip',
              tone: WarangKeepsake.kalamansi,
            ),
            WarangSpeechBubble(text: 'Hi', persistent: true),
            WarangButton.primary(label: 'Start'),
          ],
        ),
        reduced: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.hasScheduledFrame, isFalse);
    for (final scale in _scales(tester, find.byType(Column))) {
      expect(scale, closeTo(1, .001));
    }
  });

  test('every V2 text colour reads on its tint and on ground', () {
    double contrast(Color a, Color b) {
      double channel(double v) => v <= 0.04045
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      double lum(Color c) =>
          0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
      final la = lum(a);
      final lb = lum(b);
      return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
    }

    for (final tone in WarangKeepsake.all) {
      expect(contrast(tone.lightText, tone.lightTint), greaterThan(4.5));
      expect(
        contrast(tone.lightText, WarangColors.lightGround),
        greaterThan(4.5),
        reason: tone.key,
      );
      expect(contrast(tone.darkText, tone.darkTint), greaterThan(6));
      expect(
        contrast(WarangColors.lightInk, tone.fill),
        greaterThan(4.5),
        reason: '${tone.key}: ink on the solid fill',
      );
    }
  });
}
