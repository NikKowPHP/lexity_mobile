class SrsItem {
  final String id;
  final String front;
  final String back;
  final String? context;
  final String type; // MISTAKE or TRANSLATION

  SrsItem({
    required this.id,
    required this.front,
    required this.back,
    this.context,
    required this.type,
  });

  factory SrsItem.fromJson(Map<String, dynamic> json) {
    return SrsItem(
      id: json['id'],
      // Note: Backend might return 'frontContent' or 'front' based on your prisma schema
      front: json['frontContent'] ?? '', 
      back: json['backContent'] ?? '',
      context: json['context'],
      type: json['type'] ?? 'TRANSLATION',
    );
  }
}
