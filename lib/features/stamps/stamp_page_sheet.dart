import 'package:flutter/material.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatting.dart';
import '../../core/place_categories.dart';
import '../../core/stamps.dart';

/// Opens the FEAT-004 F6 stamp page sheet for [stamp].
///
/// Tapping a place row closes the sheet and invokes [onSelectPlace] with the
/// category key and place id so the map filters to that category and focuses
/// the place's moments.
Future<void> showStampPageSheet(
  BuildContext context, {
  required CategoryStamp stamp,
  required PlaceCategory category,
  required void Function(String categoryKey, String placeId) onSelectPlace,
}) => showWarangSheet<void>(
  context,
  builder: (sheetContext) => StampPageSheet(
    stamp: stamp,
    category: category,
    onSelectPlace: (placeId) {
      Navigator.of(sheetContext).pop();
      onSelectPlace(stamp.categoryKey, placeId);
    },
  ),
);

class StampPageSheet extends StatelessWidget {
  const StampPageSheet({
    super.key,
    required this.stamp,
    required this.category,
    required this.onSelectPlace,
  });

  final CategoryStamp stamp;
  final PlaceCategory category;
  final ValueChanged<String> onSelectPlace;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final tone = category.tone ?? WarangKeepsake.amber;
    final summary =
        '${countLabel(stamp.visits, 'visit')} to ${countLabel(stamp.places, 'place')}';
    final since =
        'Since ${formatDate(stamp.firstVisitDate)}, ${stamp.firstVisitPlaceName}';

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: WarangStamp.category(
                id: 'stamp-page-${stamp.categoryKey}-${stamp.tier}',
                glyph: category.glyph,
                word: stamp.title,
                tone: tone,
                tier: stamp.tier,
                large: true,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              stamp.title,
              textAlign: TextAlign.center,
              style: WarangType.displayM.copyWith(color: neutrals.ink),
            ),
            const SizedBox(height: 6),
            Text(
              summary,
              textAlign: TextAlign.center,
              style: WarangType.body.copyWith(color: neutrals.inkSoft),
            ),
            const SizedBox(height: 4),
            Text(
              since,
              textAlign: TextAlign.center,
              style: WarangType.meta.copyWith(color: neutrals.inkFaint),
            ),
            const SizedBox(height: 20),
            ClaySurface(
              depth: ClayDepth.clay1,
              borderRadius: BorderRadius.circular(WarangRadius.card),
              clipBehavior: Clip.antiAlias,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (var i = 0; i < stamp.placeVisits.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 60,
                          endIndent: 16,
                          color: neutrals.hairline,
                        ),
                      _PlaceVisitRow(
                        category: category,
                        visit: stamp.placeVisits[i],
                        onTap: () =>
                            onSelectPlace(stamp.placeVisits[i].placeId),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceVisitRow extends StatelessWidget {
  const _PlaceVisitRow({
    required this.category,
    required this.visit,
    required this.onTap,
  });

  final PlaceCategory category;
  final PlaceVisitCount visit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    final visitsText = countLabel(visit.visits, 'visit');
    return Semantics(
      button: true,
      label: '${visit.placeName}, $visitsText, show on map',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CategoryDisc(category: category, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        visit.placeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: WarangType.titleS.copyWith(color: neutrals.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visitsText,
                        style: WarangType.meta.copyWith(
                          color: neutrals.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const WarangIcon(WarangGlyphs.chevron, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
