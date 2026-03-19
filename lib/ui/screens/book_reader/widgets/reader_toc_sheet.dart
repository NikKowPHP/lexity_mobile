import 'package:flutter/material.dart';

/// Callback when a chapter is selected
typedef OnChapterSelected = void Function(String href);

/// A bottom sheet widget for displaying the table of contents.
/// Allows users to navigate to different chapters in the book.
class ReaderTocSheet extends StatelessWidget {
  final List<dynamic> toc;
  final OnChapterSelected onChapterSelected;

  const ReaderTocSheet({
    super.key,
    required this.toc,
    required this.onChapterSelected,
  });

  /// Shows the TOC bottom sheet.
  static void show({
    required BuildContext context,
    required List<dynamic> toc,
    required OnChapterSelected onChapterSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) =>
            ReaderTocSheet(toc: toc, onChapterSelected: onChapterSelected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Table of Contents",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(color: Colors.white10),
        Expanded(
          child: ListView.separated(
            itemCount: toc.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final chapter = toc[index];
              final int level = chapter['level'] ?? 0;

              return ListTile(
                contentPadding: EdgeInsets.only(
                  left: 16.0 + (level * 16.0),
                  right: 16.0,
                ),
                title: Text(
                  chapter['label'].toString().trim(),
                  style: TextStyle(
                    color: level == 0 ? Colors.white : Colors.white70,
                    fontWeight: level == 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: level == 0 ? 15 : 14,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white24,
                  size: 16,
                ),
                onTap: () {
                  final href = chapter['href'].toString();
                  onChapterSelected(href);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
