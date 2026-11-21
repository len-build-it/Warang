import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../features/home_tab/home_tab_screen.dart';
import '../../features/news_tab/news_tab_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/travel_mode/travel_mode_screen.dart';
import '../app.dart';
import '../app_state.dart';
import '../theme/components.dart';
import '../theme/tokens.dart';
import 'warang_drawer.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _drawerOpen = false;

  static const _items = [
    _ShellItem(
      unselectedIcon: Icons.map_outlined,
      selectedIcon: Icons.map,
      label: 'Travel Mode',
    ),
    _ShellItem(
      unselectedIcon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    _ShellItem(
      unselectedIcon: Icons.article_outlined,
      selectedIcon: Icons.article,
      label: 'News',
    ),
  ];

  late final _tabs = [
    TravelModeScreen(onOpenMenu: _openDrawer),
    HomeTabScreen(onSearch: _openSearch),
    const NewsTabScreen(),
  ];

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _closeDrawer() => _scaffoldKey.currentState?.closeDrawer();

  Future<void> _openSearch() async {
    _closeDrawer();
    final repository = ref.read(repositoryProvider);
    final moment = await showSearch<Moment?>(
      context: context,
      delegate: MomentSearchDelegate(
        repository,
        photoStore: ref.read(photoStoreProvider),
      ),
    );
    if (moment != null && mounted) showMomentOnMap(context, ref, moment);
  }

  void _openSettings() {
    _closeDrawer();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openAbout() {
    _closeDrawer();
    showAboutDialog(
      context: context,
      applicationName: 'Warang',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Aklanon. To go out and explore.',
    );
  }

  /// Back closes the innermost thing first: drawer, open moment, then a
  /// non-map tab. Only an idle Travel Mode lets the route pop.
  void _handleBack() {
    if (_drawerOpen) {
      _closeDrawer();
    } else if (ref.read(selectedMomentProvider) != null) {
      ref.read(selectedMomentProvider.notifier).clear();
    } else if (ref.read(shellTabProvider) != 0) {
      ref.read(shellTabProvider.notifier).select(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(shellTabProvider);
    final hasSelection = ref.watch(selectedMomentProvider) != null;
    final repository = ref.watch(repositoryProvider);
    return PopScope(
      canPop: currentIndex == 0 && !hasSelection && !_drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          return Scaffold(
            key: _scaffoldKey,
            drawerScrimColor: WarangColors.scrim(Theme.of(context).brightness),
            drawerEdgeDragWidth: 24,
            drawerEnableOpenDragGesture: currentIndex == 0,
            onDrawerChanged: (open) => setState(() => _drawerOpen = open),
            drawer: Drawer(
              width: constraints.maxWidth * .82,
              shape: const RoundedRectangleBorder(),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: AnimatedBuilder(
                animation: repository,
                builder: (context, _) => WarangDrawer(
                  repository: repository,
                  onSearch: _openSearch,
                  onSettings: _openSettings,
                  onAbout: _openAbout,
                ),
              ),
            ),
            body: desktop
                ? Row(
                    children: [
                      _DesktopNavigation(
                        items: _items,
                        selectedIndex: currentIndex,
                        onSelected: _select,
                      ),
                      Expanded(child: _tabStack(currentIndex)),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      _tabStack(currentIndex),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _MobileNavigation(
                          items: _items,
                          selectedIndex: currentIndex,
                          onSelected: _select,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _tabStack(int index) => IndexedStack(index: index, children: _tabs);

  void _select(int index) => ref.read(shellTabProvider.notifier).select(index);
}

class _ShellItem {
  const _ShellItem({
    required this.unselectedIcon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData unselectedIcon;
  final IconData selectedIcon;
  final String label;
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ShellItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTravelMode = selectedIndex == 0;
    final navContent = SizedBox(
      height: WarangLayout.mobileNavHeight,
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: _NavigationItem(
                item: items[index],
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );

    final navBar = isTravelMode
        ? WarangGlassSurface(
            borderRadius: BorderRadius.circular(14),
            child: navContent,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: theme.brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.30)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: navContent,
          );

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        WarangLayout.mobileNavMarginHorizontal,
        WarangLayout.mobileNavMarginVertical,
        WarangLayout.mobileNavMarginHorizontal,
        WarangLayout.mobileNavMarginVertical,
      ),
      child: navBar,
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ShellItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Warang',
                      style: WarangType.meta.copyWith(
                        color: WarangNeutrals.of(context).inkFaint,
                      ),
                    ),
                  ),
                ),
                for (var index = 0; index < items.length; index++)
                  _NavigationItem(
                    item: items[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                    horizontal: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.horizontal = false,
  });

  final _ShellItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = selected
        ? (dark ? WarangColors.darkAccentText : WarangColors.lightAccentText)
        : WarangNeutrals.of(context).inkSoft;
    final background = selected
        ? WarangColors.accent.withValues(alpha: dark ? .22 : .16)
        : Colors.transparent;
    final iconData = selected ? item.selectedIcon : item.unselectedIcon;

    return Semantics(
      selected: selected,
      label: item.label,
      button: true,
      child: Padding(
        padding: horizontal
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
            : const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            focusColor: WarangColors.accent.withValues(alpha: .18),
            hoverColor: theme.colorScheme.onSurface.withValues(alpha: .06),
            splashColor: WarangColors.accent.withValues(alpha: .20),
            child: Padding(
              padding: horizontal
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 13)
                  : const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: horizontal
                  ? Row(
                      children: [
                        Icon(iconData, color: color, size: 21),
                        const SizedBox(width: 12),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(iconData, color: color, size: 21),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
