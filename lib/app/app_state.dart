import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../data/files/photo_store.dart';
import '../features/map/map_tile_store.dart';
import 'app.dart';

/// The photo store wired in the composition root, shared by every screen.
final photoStoreProvider = Provider<PhotoStore>(
  (ref) => ref.watch(repositoryProvider).photoStore,
);

/// The offline tile cache. `main.dart` overrides this with the app instance.
final mapTileStoreProvider = Provider<MapTileStore>((ref) {
  final store = MapTileStore();
  ref.onDispose(store.close);
  return store;
});

/// Index of the visible shell tab: 0 Travel Mode, 1 Home, 2 News.
final shellTabProvider = NotifierProvider<ShellTabNotifier, int>(
  ShellTabNotifier.new,
);

class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

/// The moment open over the map. [focus] asks the map to move to it.
@immutable
class MomentSelection {
  const MomentSelection(this.momentId, {this.focus = false});
  final String momentId;
  final bool focus;
}

final selectedMomentProvider =
    NotifierProvider<SelectedMomentNotifier, MomentSelection?>(
      SelectedMomentNotifier.new,
    );

class SelectedMomentNotifier extends Notifier<MomentSelection?> {
  @override
  MomentSelection? build() => null;

  void select(Moment moment, {bool focus = false}) =>
      state = MomentSelection(moment.id, focus: focus);

  void clear() => state = null;
}

/// Opens [moment] over the Travel Mode map from anywhere in the app.
void showMomentOnMap(BuildContext context, WidgetRef ref, Moment moment) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  ref.read(shellTabProvider.notifier).select(0);
  ref.read(selectedMomentProvider.notifier).select(moment, focus: true);
}
