import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/components.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatting.dart';

sealed class NewsListEntry {
  const NewsListEntry();
}

final class NewsArticle extends NewsListEntry {
  const NewsArticle({
    required this.title,
    required this.body,
    required this.category,
    required this.icon,
    required this.date,
  });

  final String title;
  final String body;
  final String category;
  final WarangGlyph icon;
  final DateTime date;

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    title: json['title'] as String,
    body: json['body'] as String,
    category: json['category'] as String? ?? 'News',
    icon: _iconFor(json['icon'] as String?),
    date: DateTime.parse(json['date'] as String),
  );
}

/// Structural seam for a future curated entry. It is intentionally unused in
/// this phase and renders no content when a future caller supplies one.
final class NewsAdSlot extends NewsListEntry {
  const NewsAdSlot();
}

/// The News tab (S10): each bundled note is a postcard. Content is bundled
/// and offline; nothing is fetched.
class NewsTabScreen extends StatefulWidget {
  const NewsTabScreen({super.key, this.entries});

  /// The notes to show; the bundled ones when null. Tests use this to show
  /// the loading and empty states.
  final Future<List<NewsListEntry>>? entries;

  @override
  State<NewsTabScreen> createState() => _NewsTabScreenState();
}

class _NewsTabScreenState extends State<NewsTabScreen> {
  late Future<List<NewsListEntry>> _entries = widget.entries ?? _loadEntries();

  Future<List<NewsListEntry>> _loadEntries() async {
    final raw = await rootBundle.loadString('assets/data/news_items.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(NewsArticle.fromJson)
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    // Refresh only rereads the bundled notes. A remote source would be an
    // explicit product change.
    final next = widget.entries ?? _loadEntries();
    setState(() => _entries = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<NewsListEntry>>(
          future: _entries,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final entries = snapshot.data ?? const <NewsListEntry>[];
            return RefreshIndicator(
              onRefresh: _refresh,
              color: WarangColors.accentText(Theme.of(context).brightness),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  22,
                  20,
                  WarangLayout.dockClearance(context) + 16,
                ),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'News',
                      style: WarangType.displayL.copyWith(color: neutrals.ink),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Small notes for going out and exploring.',
                    style: WarangType.body.copyWith(color: neutrals.inkSoft),
                  ),
                  const SizedBox(height: 24),
                  if (loading)
                    const _NewsMessage(
                      title: 'Unpacking the postcards',
                      line: 'Just a moment.',
                    )
                  else if (entries.isEmpty)
                    const _NewsMessage(
                      title: 'No postcards yet',
                      line: 'New notes arrive with app updates.',
                    )
                  else
                    for (final (index, entry) in entries.indexed)
                      switch (entry) {
                        NewsArticle article => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _Postcard(article: article, index: index),
                        ),
                        NewsAdSlot _ => const SizedBox.shrink(),
                      },
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A postcard: `surfaceRaised` clay with a stamp in the top-right corner.
class _Postcard extends StatelessWidget {
  const _Postcard({required this.article, required this.index});
  final NewsArticle article;
  final int index;

  static const _tones = [
    WarangKeepsake.dagat,
    WarangKeepsake.gumamela,
    WarangKeepsake.ube,
  ];

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    return MergeSemantics(
      child: ClaySurface(
        depth: ClayDepth.clay1,
        color: neutrals.surfaceRaised,
        borderRadius: BorderRadius.circular(WarangRadius.card),
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.category,
                    style: WarangType.meta.copyWith(color: neutrals.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.title,
                    style: WarangType.titleS.copyWith(color: neutrals.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.body,
                    style: WarangType.body.copyWith(color: neutrals.inkSoft),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formatDate(article.date),
                    style: WarangType.meta.copyWith(color: neutrals.inkFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            WarangStamp.postage(
              id: 'news-${article.title}',
              glyph: article.icon,
              tone: _tones[index % _tones.length],
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading and empty: the maya with a blank postcard and a plain message,
/// in place of a lone spinner.
class _NewsMessage extends StatelessWidget {
  const _NewsMessage({required this.title, required this.line});
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    final neutrals = WarangNeutrals.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Image.asset(
              'design/warang-maya.png',
              width: 120,
              height: 120,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: WarangType.titleS.copyWith(color: neutrals.ink),
          ),
          const SizedBox(height: 6),
          Text(
            line,
            textAlign: TextAlign.center,
            style: WarangType.body.copyWith(color: neutrals.inkSoft),
          ),
        ],
      ),
    );
  }
}

WarangGlyph _iconFor(String? name) => switch (name) {
  'camera_alt' => WarangGlyphs.capture,
  'auto_stories' => WarangGlyphs.news,
  _ => WarangGlyphs.explore,
};
