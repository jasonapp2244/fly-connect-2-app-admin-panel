import 'package:cloud_firestore/cloud_firestore.dart';

/// Tiny helper that owns the bookkeeping for cursor-based Firestore
/// pagination — the page just tells it "give me the next chunk" and
/// it tracks the last doc, the page size, and the "no more pages"
/// flag.
///
/// # Why
///
/// Every admin list does the same shape of work: fetch one page,
/// remember the last DocumentSnapshot, fetch the next page using
/// `startAfterDocument`, stop when the result is short. Repeating
/// that across 5 pages produced three subtly-different bugs (one
/// would set `_hasMore = false` after an empty refresh, one would
/// not reset the cursor on filter change). Centralising it removes
/// the room for variation.
///
/// # Usage
///
/// ```dart
/// final _paginator = CursorPaginator(pageSize: 50);
///
/// Future<void> _fetchFirstPage() async {
///   _paginator.reset();
///   final snap = await _paginator.fetchFirst(
///     FirebaseFirestore.instance
///         .collection('reports')
///         .orderBy('createdAt', descending: true),
///   );
///   setState(() => _items = _toMaps(snap));
/// }
///
/// Future<void> _fetchMore() async {
///   final snap = await _paginator.fetchNext(
///     FirebaseFirestore.instance
///         .collection('reports')
///         .orderBy('createdAt', descending: true),
///   );
///   if (snap != null) setState(() => _items.addAll(_toMaps(snap)));
/// }
/// ```
///
/// The paginator is **not** a ChangeNotifier — page state lives where
/// it always did. This class only avoids re-implementing the cursor
/// arithmetic.
class CursorPaginator {
  final int pageSize;

  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _loading = false;

  CursorPaginator({this.pageSize = 50});

  bool get hasMore => _hasMore;
  bool get loading => _loading;

  /// Reset the cursor — call from your "refresh from top" path.
  void reset() {
    _lastDoc = null;
    _hasMore = true;
    _loading = false;
  }

  /// Fetch the first page using [baseQuery]. The query should NOT
  /// already have a `.limit()` — we add the page size here.
  Future<QuerySnapshot<Map<String, dynamic>>> fetchFirst(
    Query<Map<String, dynamic>> baseQuery,
  ) async {
    _loading = true;
    try {
      final snap = await baseQuery.limit(pageSize).get();
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      _hasMore = snap.docs.length == pageSize;
      return snap;
    } finally {
      _loading = false;
    }
  }

  /// Fetch the next page. Returns `null` when there's nothing more to
  /// load (either we've reached the end, we're already mid-fetch, or
  /// the previous fetch returned no documents).
  Future<QuerySnapshot<Map<String, dynamic>>?> fetchNext(
    Query<Map<String, dynamic>> baseQuery,
  ) async {
    if (_lastDoc == null || !_hasMore || _loading) return null;
    _loading = true;
    try {
      final snap = await baseQuery
          .startAfterDocument(_lastDoc!)
          .limit(pageSize)
          .get();
      if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
      _hasMore = snap.docs.length == pageSize;
      return snap;
    } finally {
      _loading = false;
    }
  }
}
