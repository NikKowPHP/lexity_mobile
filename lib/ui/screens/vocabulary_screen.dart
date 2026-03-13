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
  String _search = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = ref.read(activeLanguageProvider);
      ref.read(vocabularyProvider.notifier).loadVocabulary(lang);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocabAsync = ref.watch(vocabularyProvider);
    final activeLang = ref.watch(activeLanguageProvider);

    return GlassScaffold(
      title: 'Vocabulary',
      subtitle: 'Manage saved words',
      body: vocabAsync.when(
        loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SliverFillRemaining(child: Center(child: Text("Error: $e", style: const TextStyle(color: Colors.white70)))),
        data: (vocab) {
          final words = vocab.entries
              .where((e) => e.key.contains(_search.toLowerCase()))
              .toList();

          return SliverList(
            delegate: SliverChildListDelegate([
              GlassInput(
                hint: "Search words...",
                controller: _searchController,
                onChanged: (val) => setState(() => _search = val),
              ),
              const SizedBox(height: 16),
              if (words.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text("No words found", style: TextStyle(color: Colors.white38))),
                ),
              ...words.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: GlassCard(
                  padding: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                            Text(e.value.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white54)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => ref.read(vocabularyProvider.notifier).deleteWord(e.key, activeLang),
                      ),
                    ],
                  ),
                ),
              )),
            ]),
          );
        },
      ),
    );
  }
}
