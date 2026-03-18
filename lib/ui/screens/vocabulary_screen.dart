import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/user_provider.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/liquid_components.dart';

class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _search = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = ref.read(activeLanguageProvider);
      ref.read(paginatedVocabularyProvider.notifier).loadVocabulary(lang);
    });
    
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedVocabularyProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> _filterItems(Map<String, String> items, String search) {
    if (search.isEmpty) return items.entries.toList();
    return items.entries.where((e) => e.key.toLowerCase().contains(search.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vocabData = ref.watch(paginatedVocabularyProvider);
    final activeLang = ref.watch(activeLanguageProvider);
    final filteredItems = _filterItems(vocabData.items, _search);

    return GlassScaffold(
      title: 'Vocabulary',
      subtitle: 'Manage saved words',
      showBackButton: true,
      body: SliverFillRemaining(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  _VocabularyCountsCard(counts: vocabData.counts),
                  const SizedBox(height: 16),
                  GlassInput(
                    hint: "Search words...",
                    controller: _searchController,
                    onChanged: (val) => setState(() => _search = val),
                  ),
                ],
              ),
            ),
            Expanded(
              child: vocabData.isLoading && vocabData.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredItems.isEmpty
                      ? const Center(child: Text("No words found", style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filteredItems.length + (vocabData.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= filteredItems.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final entry = filteredItems[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: GlassCard(
                                padding: 12,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                          Text(entry.value.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white54)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () => ref.read(paginatedVocabularyProvider.notifier).deleteWord(entry.key, activeLang),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VocabularyCountsCard extends StatelessWidget {
  final VocabularyCounts counts;

  const _VocabularyCountsCard({required this.counts});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _CountItem(label: 'Total', value: counts.total, color: Colors.white),
          _CountItem(label: 'Known', value: counts.known, color: Colors.greenAccent),
          _CountItem(label: 'Learning', value: counts.learning, color: Colors.orangeAccent),
          _CountItem(label: 'Unknown', value: counts.unknown, color: Colors.redAccent),
        ],
      ),
    );
  }
}

class _CountItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CountItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
