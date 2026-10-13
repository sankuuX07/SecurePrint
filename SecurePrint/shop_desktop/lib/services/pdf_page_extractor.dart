import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Exception thrown when a requested PDF page range is invalid,
/// out-of-bounds, reversed, empty, or cannot be processed.
class PdfPageRangeException implements Exception {
  final String message;
  const PdfPageRangeException(this.message);

  @override
  String toString() => 'PdfPageRangeException: $message';
}

/// Service responsible for validating page ranges and extracting
/// only the requested pages from a source PDF document.
class PdfPageExtractor {
  const PdfPageExtractor();

  /// Parses a user-facing 1-based page range string against the document's [totalPages].
  ///
  /// Returns a [Set] of 0-based PDF page indices.
  ///
  /// Supported formats:
  /// - Single page: "1", "4"
  /// - Hyphen range: "1-3", "2-5"
  /// - Comma-separated combination: "1, 3, 5-7"
  ///
  /// Whitespace around commas and hyphens is permitted.
  ///
  /// Throws [PdfPageRangeException] if:
  /// - [pageRange] is empty or whitespace
  /// - Any page number is < 1 (user pages are 1-based)
  /// - Any page number exceeds [totalPages]
  /// - Any range has end < start (e.g. "5-2")
  /// - Format is malformed (e.g. "1-2-3", "abc", "-")
  /// - Selection results in an empty set
  Set<int> parsePageRangeToZeroBasedIndices(String? pageRange, int totalPages) {
    if (totalPages <= 0) {
      throw const PdfPageRangeException('Total pages must be greater than zero.');
    }

    // null means no range was requested -> all pages selected
    if (pageRange == null) {
      return List.generate(totalPages, (i) => i).toSet();
    }

    final trimmedRange = pageRange.trim();
    if (trimmedRange.isEmpty) {
      throw const PdfPageRangeException('Page range cannot be empty.');
    }

    final parts = trimmedRange.split(',');
    final Set<int> selectedZeroBasedIndices = <int>{};

    for (final rawPart in parts) {
      final part = rawPart.trim();
      if (part.isEmpty) {
        throw PdfPageRangeException('Invalid empty component in page range: "$pageRange".');
      }

      if (part.contains('-')) {
        final bounds = part.split('-');
        if (bounds.length != 2) {
          throw PdfPageRangeException('Invalid page range format: "$part".');
        }

        final startStr = bounds[0].trim();
        final endStr = bounds[1].trim();

        final start = int.tryParse(startStr);
        final end = int.tryParse(endStr);

        if (start == null || end == null) {
          throw PdfPageRangeException('Invalid page numbers in range: "$part". Expected integers.');
        }

        if (start < 1) {
          throw PdfPageRangeException('Page number $start is invalid. Page numbers must be 1 or greater.');
        }

        if (end < start) {
          throw PdfPageRangeException('Reversed page range "$part" is invalid (start $start is greater than end $end).');
        }

        if (end > totalPages) {
          throw PdfPageRangeException('Page $end exceeds document total pages ($totalPages).');
        }

        for (int userPage = start; userPage <= end; userPage++) {
          // Explicit 1-based user number to 0-based PDF library index conversion
          final int zeroBasedIndex = userPage - 1;
          selectedZeroBasedIndices.add(zeroBasedIndex);
        }
      } else {
        final pageNum = int.tryParse(part);
        if (pageNum == null) {
          throw PdfPageRangeException('Invalid page number: "$part". Expected integer.');
        }

        if (pageNum < 1) {
          throw PdfPageRangeException('Page number $pageNum is invalid. Page numbers must be 1 or greater.');
        }

        if (pageNum > totalPages) {
          throw PdfPageRangeException('Page $pageNum exceeds document total pages ($totalPages).');
        }

        // Explicit 1-based user number to 0-based PDF library index conversion
        final int zeroBasedIndex = pageNum - 1;
        selectedZeroBasedIndices.add(zeroBasedIndex);
      }
    }

    if (selectedZeroBasedIndices.isEmpty) {
      throw const PdfPageRangeException('No pages selected in the specified range.');
    }

    return selectedZeroBasedIndices;
  }

  /// Extracts the requested pages from [sourcePdfBytes] according to [pageRange].
  ///
  /// If [pageRange] is null, or if all pages are requested, returns [sourcePdfBytes]
  /// directly without altering the original bytes.
  ///
  /// If [pageRange] specifies a valid subset, parses the PDF in-memory, removes unselected
  /// pages, and returns a new [Uint8List] containing ONLY the requested pages.
  /// The input [sourcePdfBytes] is never modified.
  ///
  /// Throws [PdfPageRangeException] if:
  /// - [sourcePdfBytes] is empty or invalid PDF
  /// - [pageRange] is invalid, reversed, out-of-bounds, or empty
  Uint8List extractPages(Uint8List sourcePdfBytes, String? pageRange) {
    if (sourcePdfBytes.isEmpty) {
      throw const PdfPageRangeException('Source PDF bytes cannot be empty.');
    }

    // Fast-path: if no page range is requested, return original bytes unmodified
    if (pageRange == null) {
      return sourcePdfBytes;
    }

    // Load PDF in-memory to validate page count and extract
    PdfDocument document;
    try {
      document = PdfDocument(inputBytes: sourcePdfBytes);
    } catch (e) {
      throw PdfPageRangeException('Failed to load PDF document: $e');
    }

    try {
      final int totalPages = document.pages.count;
      if (totalPages <= 0) {
        throw const PdfPageRangeException('PDF document contains no pages.');
      }

      final Set<int> selectedIndices = parsePageRangeToZeroBasedIndices(pageRange, totalPages);

      // If all pages are selected, no extraction/removal is necessary
      if (selectedIndices.length == totalPages) {
        return sourcePdfBytes;
      }

      // Collect 0-based indices that were NOT selected
      final List<int> unselectedIndices = <int>[];
      for (int i = 0; i < totalPages; i++) {
        if (!selectedIndices.contains(i)) {
          unselectedIndices.add(i);
        }
      }

      // Sort unselected indices in descending order so earlier removals do not shift later indices
      unselectedIndices.sort((a, b) => b.compareTo(a));
      for (final index in unselectedIndices) {
        document.pages.removeAt(index);
      }

      final List<int> savedBytes = document.saveSync();
      return Uint8List.fromList(savedBytes);
    } finally {
      document.dispose();
    }
  }
}
