import 'package:flutter_test/flutter_test.dart';
import 'package:lexity_mobile/models/book.dart';

void main() {
  group('UserBook Model Tests', () {
    test('fromJson should correctly parse a complete JSON map', () {
      final json = {
        'id': '123',
        'title': 'Test Book',
        'author': 'Test Author',
        'targetLanguage': 'spanish',
        'storagePath': 'books/test.epub',
        'coverImageUrl': 'https://example.com/cover.jpg',
        'currentCfi': 'epubcfi(/6/4[chap01]!/4/2/16/1:0)',
        'progressPct': 45.5,
        'createdAt': '2026-03-04T10:00:00Z',
        'signedUrl': 'https://signed-url.com',
      };

      final book = UserBook.fromJson(json);

      expect(book.id, '123');
      expect(book.title, 'Test Book');
      expect(book.author, 'Test Author');
      expect(book.targetLanguage, 'spanish');
      expect(book.progressPct, 45.5);
      expect(book.currentCfi, 'epubcfi(/6/4[chap01]!/4/2/16/1:0)');
      expect(book.signedUrl, 'https://signed-url.com');
    });

    test('fromJson should handle null author and default values', () {
      final json = {
        'id': '124',
        'storagePath': 'books/test2.epub',
        'createdAt': '2026-03-04T11:00:00Z',
      };

      final book = UserBook.fromJson(json);

      expect(book.id, '124');
      expect(book.title, 'Unknown Title');
      expect(book.author, isNull);
      expect(book.targetLanguage, 'spanish');
      expect(book.progressPct, 0.0);
    });
  });
}
