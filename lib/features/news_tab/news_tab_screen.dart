import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/theme/tokens.dart';

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
  final IconData icon;
  final DateTime date;

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    title: json['title'] as String,
    body: json['body'] as String,
    category: json['category'] as String? ?? 'NEWS',
    icon: _iconFor(json['icon'] as String?),
    date: DateTime.parse(json['date'] as String),
  );
}

/// Structural seam for a future curated entry. It is intentionally unused in
/// this phase and renders no content when a future caller supplies one.
final class NewsAdSlot extends NewsListEntry {
  const NewsAdSlot();
}

class NewsTabScreen extends StatefulWidget {
  const NewsTabScreen({super.key});

  @override
  State<NewsTabScreen> createState() => _NewsTabScreenState();
}

class _NewsTabScreenState extends State<NewsTabScreen> {
  late Future<List<NewsListEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _loadEntries();
  }

  Future<List<NewsListEntry>> _loadEntries() async {
    final raw = await rootBundle.loadString('assets/data/news_items.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(NewsArticle.fromJson)
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    // Content is bundled and offline-only in this phase; refresh only rereads
    // the local asset. A future remote source must be an explicit product change.
    final next = _loadEntries();
    setState(() => _entries = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: SafeArea(
      child: FutureBuilder<List<NewsListEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <NewsListEntry>[];
          final bottomPadding = WarangLayout.navigationHeight(context) + 24.0;
          return RefreshIndicator(
            onRefresh: _refresh,
            color: Theme.of(context).colorScheme.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 22, 20, bottomPadding),
              children: [
                Text('News', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 7),
                Text(
                  'Small notes for going out and exploring.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 30),
                if (entries.isEmpty)
                  const _NewsEmptyState()
                else
                  ...entries.map((entry) => _entryWidget(context, entry)),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _entryWidget(BuildContext context, NewsListEntry entry) =>
      switch (entry) {
        NewsArticle article => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _NewsArticleCard(article: article),
        ),
        NewsAdSlot _ => const SizedBox.shrink(),
      };
}

class _NewsArticleCard extends StatelessWidget {
  const _NewsArticleCard({required this.article});
  final NewsArticle article;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            article.icon,
            size: 21,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .68),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.category,
                style: const TextStyle(
                  fontFamily: 'DM Mono',
                  fontSize: 9,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                article.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 7),
              Text(article.body, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 11),
              Text(
                DateFormat('dd MMM yyyy').format(article.date).toUpperCase(),
                style: TextStyle(
                  fontFamily: 'DM Mono',
                  fontSize: 9,
                  letterSpacing: 1.2,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .54),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NewsEmptyState extends StatelessWidget {
  const _NewsEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Column(
      children: [
        Image.asset('design/warang-maya.png', width: 100, height: 100),
        const SizedBox(height: 18),
        Text(
          'Nothing here yet.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'New notes will appear here when they are bundled with the app.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}

IconData _iconFor(String? name) => switch (name) {
  'camera_alt' => Icons.camera_alt_outlined,
  'auto_stories' => Icons.auto_stories_outlined,
  _ => Icons.explore_outlined,
};
