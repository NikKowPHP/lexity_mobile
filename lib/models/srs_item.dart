class SrsItem {
  final String id;
  final String front;
  final String back;
  final String? context;
  final String type;

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
      front: json['frontContent'] ?? json['front'] ?? '',
      back: json['backContent'] ?? json['back'] ?? '',
      context: json['context'],
      type: json['type'] ?? 'TRANSLATION',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'frontContent': front,
      'backContent': back,
      'context': context,
      'type': type,
    };
  }
}
