class UserBook {
  final String id;
  final String title;
  final String? author;
  final String targetLanguage;
  final String storagePath;
  final String? coverImageUrl;
  final String? currentCfi;
  final double progressPct;
  final DateTime createdAt;
  final String? signedUrl;

  UserBook({
    required this.id,
    required this.title,
    this.author,
    required this.targetLanguage,
    required this.storagePath,
    this.coverImageUrl,
    this.currentCfi,
    required this.progressPct,
    required this.createdAt,
    this.signedUrl,
  });

  factory UserBook.fromJson(Map<String, dynamic> json) {
    return UserBook(
      id: json['id'],
      title: json['title'] ?? 'Unknown Title',
      author: json['author'],
      targetLanguage: json['targetLanguage'] ?? 'spanish',
      storagePath: json['storagePath'] ?? '',
      coverImageUrl: json['coverImageUrl'],
      currentCfi: json['currentCfi'],
      progressPct: (json['progressPct'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      signedUrl: json['signedUrl'],
    );
  }
}
