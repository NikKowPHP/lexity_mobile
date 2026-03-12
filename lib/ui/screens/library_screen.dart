import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/logger_service.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isUploading = false;

  Future<void> _handleUpload() async {
    final activeLang = ref.read(activeLanguageProvider);
    final logger = ref.read(loggerProvider);
    
    logger.info('LibraryScreen: User triggered EPUB upload');
    
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );

    if (result != null && result.files.single.path != null) {
      final fileName = result.files.single.name;
      logger.info('LibraryScreen: File selected: $fileName');
      
      setState(() => _isUploading = true);
      File file = File(result.files.single.path!);
      
      try {
        await ref.read(bookNotifierProvider.notifier).uploadBook(
          file, 
          activeLang, 
          fileName.replaceAll('.epub', '')
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book uploaded successfully!')));
        }
      } catch (e, st) {
        logger.error('LibraryScreen: Upload failed', e, st);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    } else {
      logger.info('LibraryScreen: File selection cancelled');
    }
  }

  void _promptDelete(String bookId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Book?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to remove "$title" from your library?', style: const TextStyle(color: Colors.white70)),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              ref.read(bookNotifierProvider.notifier).deleteBook(bookId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);

    return GlassScaffold(
      title: 'My Library',
      subtitle: 'Read and translate your EPUBs',
      showBackButton: false,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: _isUploading ? null : _handleUpload,
          backgroundColor: LiquidTheme.primaryAccent,
          icon: _isUploading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Icon(Icons.book, color: Colors.white),
          label: Text(_isUploading ? "Uploading..." : "Upload EPUB", style: const TextStyle(color: Colors.white)),
        ),
      ),
      body: booksAsync.when(
        loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SliverFillRemaining(child: Center(child: Text("Error: $e", style: const TextStyle(color: Colors.white)))),
        data: (books) {
          if (books.isEmpty) {
            return const SliverFillRemaining(
              child: Center(
                child: Text("Your library is empty. Upload an EPUB to start reading.", style: TextStyle(color: Colors.white54)),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final book = books[index];
                  return GestureDetector(
                    onTap: () => context.push('/library/book/${book.id}'),
                    onLongPress: () => _promptDelete(book.id, book.title),
                    child: GlassCard(
                      padding: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:[
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.menu_book, size: 48, color: Colors.white38),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(book.author ?? "Unknown", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: book.progressPct / 100,
                            backgroundColor: Colors.white10,
                            color: LiquidTheme.primaryAccent,
                            minHeight: 4,
                          ),
                          const SizedBox(height: 6),
                          Text("${book.progressPct.round()}% Read", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                },
                childCount: books.length,
              ),
            ),
          );
        },
      ),
    );
  }
}
      