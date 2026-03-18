import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/srs_provider.dart';
import '../../providers/user_provider.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/liquid_components.dart';

class SrsItemsScreen extends ConsumerStatefulWidget {
  const SrsItemsScreen({super.key});

  @override
  ConsumerState<SrsItemsScreen> createState() => _SrsItemsScreenState();
}

class _SrsItemsScreenState extends ConsumerState<SrsItemsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = ref.read(activeLanguageProvider);
      ref.read(srsProvider.notifier).loadAllItems(lang);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(srsProvider);
    final lang = ref.watch(activeLanguageProvider);

    return GlassScaffold(
      title: 'Flashcards',
      subtitle: 'Manage your study deck',
      showBackButton: true,
      body: state.isLoading
          ? const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          : SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final item = state.allItems[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      isStatic: true,
                      padding: 16,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.front,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.back,
                                  style: TextStyle(
                                    color: Colors.greenAccent.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => ref
                                .read(srsProvider.notifier)
                                .deleteItem(item.id, lang),
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: state.allItems.length),
              ),
            ),
    );
  }
}
