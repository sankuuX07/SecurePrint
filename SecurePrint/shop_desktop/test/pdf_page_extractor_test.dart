import 'dart:typed_data';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:shop_desktop/services/pdf_page_extractor.dart';

/// Helper to generate an in-memory sample PDF with [pageCount] pages,
/// where each page contains distinct text "Page $i".
Uint8List createSamplePdf(int pageCount) {
  final document = PdfDocument();
  for (int i = 1; i <= pageCount; i++) {
    final page = document.pages.add();
    page.graphics.drawString(
      'Document Content - Page $i',
      PdfStandardFont(PdfFontFamily.helvetica, 18),
      bounds: const Rect.fromLTWH(40, 40, 400, 40),
    );
  }
  final List<int> bytes = document.saveSync();
  document.dispose();
  return Uint8List.fromList(bytes);
}

/// Helper to extract text from a specific 0-based page index of a PDF.
String extractTextFromPage(Uint8List pdfBytes, int zeroBasedPageIndex) {
  final doc = PdfDocument(inputBytes: pdfBytes);
  try {
    return PdfTextExtractor(doc).extractText(
      startPageIndex: zeroBasedPageIndex,
      endPageIndex: zeroBasedPageIndex,
    );
  } finally {
    doc.dispose();
  }
}

/// Helper to get page count of a PDF.
int getPdfPageCount(Uint8List pdfBytes) {
  final doc = PdfDocument(inputBytes: pdfBytes);
  try {
    return doc.pages.count;
  } finally {
    doc.dispose();
  }
}

void main() {
  const extractor = PdfPageExtractor();

  group('PdfPageExtractor - parsePageRangeToZeroBasedIndices', () {
    test('returns all zero-based indices when pageRange is null', () {
      final indices = extractor.parsePageRangeToZeroBasedIndices(null, 5);
      expect(indices, equals({0, 1, 2, 3, 4}));
    });

    test('parses single page (user 1-based to library 0-based)', () {
      // First page: user page 1 -> index 0
      final first = extractor.parsePageRangeToZeroBasedIndices('1', 5);
      expect(first, equals({0}));

      // Middle page: user page 3 -> index 2
      final middle = extractor.parsePageRangeToZeroBasedIndices('3', 5);
      expect(middle, equals({2}));

      // Last page: user page 5 -> index 4
      final last = extractor.parsePageRangeToZeroBasedIndices('5', 5);
      expect(last, equals({4}));
    });

    test('parses contiguous multi-page ranges', () {
      final indices = extractor.parsePageRangeToZeroBasedIndices('2-4', 5);
      expect(indices, equals({1, 2, 3}));
    });

    test('parses full document range explicitly specified', () {
      final indices = extractor.parsePageRangeToZeroBasedIndices('1-5', 5);
      expect(indices, equals({0, 1, 2, 3, 4}));
    });

    test('parses single-page range notation like 3-3', () {
      final indices = extractor.parsePageRangeToZeroBasedIndices('3-3', 5);
      expect(indices, equals({2}));
    });

    test('parses comma-separated pages and mixed ranges with whitespace', () {
      final indices = extractor.parsePageRangeToZeroBasedIndices(' 1 , 3 - 4 , 5 ', 5);
      expect(indices, equals({0, 2, 3, 4}));
    });

    test('throws when totalPages <= 0', () {
      expect(
        () => extractor.parsePageRangeToZeroBasedIndices('1', 0),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('Total pages must be greater than zero'),
        )),
      );
    });

    test('rejects empty or whitespace-only pageRange', () {
      expect(
        () => extractor.parsePageRangeToZeroBasedIndices('', 5),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('cannot be empty'),
        )),
      );

      expect(
        () => extractor.parsePageRangeToZeroBasedIndices('   ', 5),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('cannot be empty'),
        )),
      );
    });

    test('rejects page numbers less than 1 (1-based constraint)', () {
      expect(
        () => extractor.parsePageRangeToZeroBasedIndices('0', 5),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('must be 1 or greater'),
        )),
      );

      expect(
        () => extractor.parsePageRangeToZeroBasedIndices('0-3', 5),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('must be 1 or greater'),
        )),
      );
    });

    test('rejects reversed ranges (e.g. 5-2)', () {
      expect(
        () => extractor.parsePageRangeToZeroBasedIndices('5-2', 5),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('Reversed page range "5-2" is invalid'),
        )),
      );
    });

    test('rejects out-of-bounds page numbers', () {
      expect(
        () => extractor.parsePageRangeToZeroBasedIndices('6', 5),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('exceeds document total pages (5)'),
        )),
      );

      expect(
        () => extractor.parsePageRangeToZeroBasedIndices('1-6', 5),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('exceeds document total pages (5)'),
        )),
      );

      expect(
        () => extractor.parsePageRangeToZeroBasedIndices('7-9', 5),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('exceeds document total pages (5)'),
        )),
      );
    });

    test('rejects malformed page range syntax', () {
      final malformedInputs = ['abc', '1-2-3', '1-', '-3', '1,', ',1', '1,,2', 'one'];
      for (final input in malformedInputs) {
        expect(
          () => extractor.parsePageRangeToZeroBasedIndices(input, 5),
          throwsA(isA<PdfPageRangeException>()),
          reason: 'Failed to reject malformed input: $input',
        );
      }
    });
  });

  group('PdfPageExtractor - extractPages', () {
    late Uint8List samplePdf;
    late String originalHash;

    setUp(() {
      samplePdf = createSamplePdf(5);
      originalHash = sha256.convert(samplePdf).toString();
    });

    test('returns full document untouched when no page range is requested (null)', () {
      final result = extractor.extractPages(samplePdf, null);

      // Verify exact byte identity and length
      expect(result, same(samplePdf));
      expect(getPdfPageCount(result), equals(5));

      // Verify original bytes were not modified
      expect(sha256.convert(samplePdf).toString(), equals(originalHash));
    });

    test('returns full document when all pages are explicitly requested (1-5)', () {
      final result = extractor.extractPages(samplePdf, '1-5');

      expect(result, same(samplePdf));
      expect(getPdfPageCount(result), equals(5));
      expect(sha256.convert(samplePdf).toString(), equals(originalHash));
    });

    test('extracts a single page (Page 2)', () {
      final extracted = extractor.extractPages(samplePdf, '2');

      expect(getPdfPageCount(extracted), equals(1));
      final text = extractTextFromPage(extracted, 0);
      expect(text, contains('Page 2'));
      expect(text, isNot(contains('Page 1')));
      expect(text, isNot(contains('Page 3')));

      // Verify original PDF bytes are not modified
      expect(sha256.convert(samplePdf).toString(), equals(originalHash));
      expect(getPdfPageCount(samplePdf), equals(5));
    });

    test('extracts first valid page (Page 1)', () {
      final extracted = extractor.extractPages(samplePdf, '1');

      expect(getPdfPageCount(extracted), equals(1));
      final text = extractTextFromPage(extracted, 0);
      expect(text, contains('Page 1'));
      expect(text, isNot(contains('Page 2')));

      expect(sha256.convert(samplePdf).toString(), equals(originalHash));
      expect(getPdfPageCount(samplePdf), equals(5));
    });

    test('extracts last valid page (Page 5)', () {
      final extracted = extractor.extractPages(samplePdf, '5');

      expect(getPdfPageCount(extracted), equals(1));
      final text = extractTextFromPage(extracted, 0);
      expect(text, contains('Page 5'));
      expect(text, isNot(contains('Page 4')));

      expect(sha256.convert(samplePdf).toString(), equals(originalHash));
      expect(getPdfPageCount(samplePdf), equals(5));
    });

    test('extracts a multi-page contiguous range (2-4)', () {
      final extracted = extractor.extractPages(samplePdf, '2-4');

      expect(getPdfPageCount(extracted), equals(3));
      expect(extractTextFromPage(extracted, 0), contains('Page 2'));
      expect(extractTextFromPage(extracted, 1), contains('Page 3'));
      expect(extractTextFromPage(extracted, 2), contains('Page 4'));

      expect(sha256.convert(samplePdf).toString(), equals(originalHash));
      expect(getPdfPageCount(samplePdf), equals(5));
    });

    test('extracts non-contiguous page range (1, 3, 5)', () {
      final extracted = extractor.extractPages(samplePdf, '1, 3, 5');

      expect(getPdfPageCount(extracted), equals(3));
      expect(extractTextFromPage(extracted, 0), contains('Page 1'));
      expect(extractTextFromPage(extracted, 1), contains('Page 3'));
      expect(extractTextFromPage(extracted, 2), contains('Page 5'));

      expect(sha256.convert(samplePdf).toString(), equals(originalHash));
      expect(getPdfPageCount(samplePdf), equals(5));
    });

    test('rejects out-of-bounds page range and does not print', () {
      expect(
        () => extractor.extractPages(samplePdf, '99'),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('exceeds document total pages (5)'),
        )),
      );

      // Confirm original bytes still intact
      expect(sha256.convert(samplePdf).toString(), equals(originalHash));
    });

    test('rejects reversed page range', () {
      expect(
        () => extractor.extractPages(samplePdf, '4-2'),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('Reversed page range "4-2" is invalid'),
        )),
      );

      expect(sha256.convert(samplePdf).toString(), equals(originalHash));
    });

    test('rejects empty page range selection', () {
      expect(
        () => extractor.extractPages(samplePdf, ''),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('cannot be empty'),
        )),
      );

      expect(
        () => extractor.extractPages(samplePdf, '   '),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('cannot be empty'),
        )),
      );

      expect(sha256.convert(samplePdf).toString(), equals(originalHash));
    });

    test('rejects invalid range syntax', () {
      expect(
        () => extractor.extractPages(samplePdf, 'abc-xyz'),
        throwsA(isA<PdfPageRangeException>()),
      );

      expect(
        () => extractor.extractPages(samplePdf, '1-2-3'),
        throwsA(isA<PdfPageRangeException>()),
      );

      expect(sha256.convert(samplePdf).toString(), equals(originalHash));
    });

    test('rejects empty input byte array', () {
      expect(
        () => extractor.extractPages(Uint8List(0), '1'),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('Source PDF bytes cannot be empty'),
        )),
      );
    });

    test('rejects corrupt/non-PDF input bytes', () {
      final corruptBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(
        () => extractor.extractPages(corruptBytes, '1'),
        throwsA(isA<PdfPageRangeException>().having(
          (e) => e.message,
          'message',
          contains('Failed to load PDF document'),
        )),
      );
    });

    test('rigorously confirms original PDF is completely unmodified after extraction', () {
      final originalSnapshot = List<int>.from(samplePdf);

      // Perform extraction
      final extracted = extractor.extractPages(samplePdf, '2-3');
      expect(getPdfPageCount(extracted), equals(2));

      // 1. Length identical
      expect(samplePdf.length, equals(originalSnapshot.length));

      // 2. Exact byte contents match
      for (int i = 0; i < samplePdf.length; i++) {
        expect(samplePdf[i], equals(originalSnapshot[i]));
      }

      // 3. SHA-256 hash unchanged
      expect(sha256.convert(samplePdf).toString(), equals(originalHash));

      // 4. In-memory parse confirms all 5 pages remain present
      final reloadDoc = PdfDocument(inputBytes: samplePdf);
      expect(reloadDoc.pages.count, equals(5));
      reloadDoc.dispose();
    });
  });
}
