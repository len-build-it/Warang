import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/components.dart';
import '../theme/tokens.dart';

/// One tab in the dock or rail.
@immutable
class DockItem {
  const DockItem({required this.glyph, required this.label});
  final WarangGlyph glyph;
  final String label;
}

/// C1 clay dock: Map and Trips, the raised capture button, then News and
/// Search. The amber-tint blob slides to the active tab and stretches while
/// it travels.
class WarangDock extends StatefulWidget {
  const WarangDock({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCapture,
  }) : assert(items.length == 4);

  /// The four side tabs, left to right; capture sits between the second
  /// and the third.
  final List<DockItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onCapture;

  static const _captureGap = 92.0;
  static const _inset = 8.0;
  static const _blob = Size(52, 34);

  @override
  State<WarangDock> createState() => _WarangDockState();
}

class _WarangDockState extends State<WarangDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _travel = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  late int _from = widget.selectedIndex;

  @override
  void didUpdateWidget(covariant WarangDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex == widget.selectedIndex) return;
    _from = oldWidget.selectedIndex;
    if (WarangMotion.reduced(context)) {
      _travel.value = 1;
    } else {
      _travel.value = 0;
      _travel.animateWith(WarangMotion.slide.simulate(0, 1));
    }
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  static const _raise = WarangLayout.captureOuterDiameter / 2;

  double _centre(int index, double slot) {
    final before = index * slot + (index >= 2 ? WarangDock._captureGap : 0);
    return WarangDock._inset + before + slot / 2;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final showLabels = MediaQuery.textScalerOf(context).scale(1) <= 1.6;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        WarangLayout.dockMarginHorizontal,
        0,
        WarangLayout.dockMarginHorizontal,
        WarangLayout.dockMarginBottom + bottom,
      ),
      // The box includes the raised half of the capture button, so all of
      // it takes taps; its empty corners let touches through to the map.
      child: SizedBox(
        height: WarangLayout.dockHeight + _raise,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot =
                (constraints.maxWidth -
                    2 * WarangDock._inset -
                    WarangDock._captureGap) /
                4;
            final iconTop = showLabels ? 12.0 : 23.0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: WarangLayout.dockHeight,
                  child: ClaySurface(
                    depth: ClayDepth.clay2,
                    borderRadius: BorderRadius.circular(WarangRadius.pill),
                  ),
                ),
                AnimatedBuilder(
                  animation: _travel,
                  builder: (context, _) {
                    final t = _travel.value;
                    final x =
                        _centre(_from, slot) +
                        (_centre(widget.selectedIndex, slot) -
                                _centre(_from, slot)) *
                            t;
                    final stretch =
                        1 + .3 * math.sin(math.pi * t.clamp(0.0, 1.0));
                    final width = WarangDock._blob.width * stretch;
                    return Positioned(
                      left: x - width / 2,
                      top: _raise + iconTop + 13 - WarangDock._blob.height / 2,
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: Container(
                            width: width,
                            height: WarangDock._blob.height,
                            decoration: BoxDecoration(
                              color: WarangKeepsake.amber.tint(brightness),
                              borderRadius: BorderRadius.circular(
                                WarangRadius.pill,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: WarangLayout.dockHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WarangDock._inset,
                    ),
                    child: Row(
                      // Full height, so `iconTop` is measured from the pill
                      // and the highlight sits behind the icon.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < 4; index++) ...[
                          if (index == 2)
                            const SizedBox(width: WarangDock._captureGap),
                          SizedBox(
                            width: slot,
                            child: _DockSlot(
                              item: widget.items[index],
                              selected: index == widget.selectedIndex,
                              showLabel: showLabels,
                              iconTop: iconTop,
                              onTap: () => _select(index),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: WarangCaptureButton(onPressed: widget.onCapture),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _select(int index) {
    if (index != widget.selectedIndex) WarangHaptic.selection.play();
    widget.onSelected(index);
  }
}

class _DockSlot extends StatelessWidget {
  const _DockSlot({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.iconTop,
    required this.onTap,
  });

  final DockItem item;
  final bool selected;
  final bool showLabel;
  final double iconTop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    return Tooltip(
      message: item.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.only(top: iconTop),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WarangIcon(item.glyph, selected: selected, size: 26),
                if (showLabel) ...[
                  const SizedBox(height: 6),
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.6,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: WarangType.caption.copyWith(
                        color: selected ? neutrals.ink : neutrals.inkSoft,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dock as a vertical clay rail on screens wider than 900, in the same
/// order: Map, Trips, capture, News, Search.
class WarangRail extends StatelessWidget {
  const WarangRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCapture,
  });

  final List<DockItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final neutrals = WarangNeutrals.of(context);
    Widget tab(int index) {
      final item = items[index];
      final selected = index == selectedIndex;
      return Tooltip(
        message: item.label,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          selected: selected,
          label: item.label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!selected) WarangHaptic.selection.play();
              onSelected(index);
            },
            child: SizedBox(
              width: 88,
              height: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: WarangMotion.fade,
                    width: 52,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? WarangKeepsake.amber.tint(brightness)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(WarangRadius.pill),
                    ),
                    child: WarangIcon(item.glyph, selected: selected, size: 26),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    maxLines: 1,
                    style: WarangType.caption.copyWith(
                      color: selected ? neutrals.ink : neutrals.inkSoft,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      right: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClaySurface(
          depth: ClayDepth.clay2,
          borderRadius: BorderRadius.circular(WarangRadius.pill),
          child: SizedBox(
            width: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                tab(0),
                tab(1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: WarangCaptureButton(onPressed: onCapture),
                ),
                tab(2),
                tab(3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
