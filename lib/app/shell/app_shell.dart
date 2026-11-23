import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../features/capture/capture_screen.dart';
import '../../features/home_tab/home_tab_screen.dart';
import '../../features/news_tab/news_tab_screen.dart';
import '../../features/search/search_tab_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/travel_mode/travel_mode_screen.dart';
import '../app.dart';
import '../app_state.dart';
import '../theme/components.dart';
import '../theme/tokens.dart';
import 'dock.dart';
import 'you_sheet.dart';

/// The tab shell: Map, Trips, News, and Search behind the clay dock, with
/// capture in the middle of it and profile, Settings, and About in the You
/// sheet behind the avatar bubble.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _travelKey = GlobalKey<TravelModeScreenState>();

  static const _items = [
    DockItem(glyph: WarangGlyphs.map, label: 'Map'),
    DockItem(glyph: WarangGlyphs.trips, label: 'Trips'),
    DockItem(glyph: WarangGlyphs.news, label: 'News'),
    DockItem(glyph: WarangGlyphs.search, label: 'Search'),
  ];

  late final _tabs = [
    TravelModeScreen(key: _travelKey, onOpenYou: _openYou),
    const HomeTabScreen(),
    const NewsTabScreen(),
    const SearchTabScreen(),
  ];

  /// Opens the camera on release, with no delay, from any tab. A saved
  /// moment returns to the map, where its pin is shown.
  Future<void> _capture() async {
    final moment = await Navigator.of(
      context,
    ).push<Moment>(MaterialPageRoute(builder: (_) => const CaptureScreen()));
    if (moment == null || !mounted) return;
    ref.read(selectedMomentProvider.notifier).clear();
    ref.read(shellTabProvider.notifier).select(ShellTab.map);
    _travelKey.currentState?.showCaptured(moment);
  }

  void _openYou() => showYouSheet(
    context,
    repository: ref.read(repositoryProvider),
    onSettings: _openSettings,
    onAbout: _openAbout,
    onSelectStampPlace: _focusStampPlace,
  );

  void _focusStampPlace(String categoryKey, String placeId) {
    ref.read(mapCategoryFilterProvider.notifier).select(categoryKey);
    ref.read(shellTabProvider.notifier).select(ShellTab.map);
    _travelKey.currentState?.focusPlace(placeId);
  }

  void _openSettings() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  void _openAbout() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const AboutScreen()));

  /// Back closes the innermost thing first: an open moment, then a tab
  /// other than Map. Only an idle Map lets the route pop.
  void _handleBack() {
    if (ref.read(selectedMomentProvider) != null) {
      ref.read(selectedMomentProvider.notifier).clear();
    } else if (ref.read(shellTabProvider) != ShellTab.map) {
      ref.read(shellTabProvider.notifier).select(ShellTab.map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(shellTabProvider);
    final hasSelection = ref.watch(selectedMomentProvider) != null;
    final placing = ref.watch(placingMomentProvider) != null;
    // The dock steps aside for the moment sheet and pin placement (C1).
    final dockHidden =
        currentIndex == ShellTab.map && (hasSelection || placing);
    final reduced = WarangMotion.reduced(context);
    final tabs = IndexedStack(index: currentIndex, children: _tabs);
    return PopScope(
      canPop: currentIndex == ShellTab.map && !hasSelection,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: WarangLayout.usesRail(context)
            ? Row(
                children: [
                  WarangRail(
                    items: _items,
                    selectedIndex: currentIndex,
                    onSelected: _select,
                    onCapture: _capture,
                  ),
                  Expanded(child: tabs),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  tabs,
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: IgnorePointer(
                      ignoring: dockHidden,
                      child: ExcludeSemantics(
                        excluding: dockHidden,
                        child: AnimatedSlide(
                          offset: Offset(0, dockHidden && !reduced ? 1.2 : 0),
                          duration: reduced
                              ? WarangMotion.fade
                              : WarangMotion.slide.duration,
                          curve: reduced
                              ? Curves.linear
                              : WarangMotion.slide.settleCurve,
                          child: AnimatedOpacity(
                            opacity: dockHidden ? 0 : 1,
                            duration: WarangMotion.fade,
                            child: WarangDock(
                              items: _items,
                              selectedIndex: currentIndex,
                              onSelected: _select,
                              onCapture: _capture,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _select(int index) => ref.read(shellTabProvider.notifier).select(index);
}
