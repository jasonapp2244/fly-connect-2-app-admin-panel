import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyconnect/features/admin/cursor_paginator.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    // Seed 7 docs so a page size of 3 yields 3 + 3 + 1 (last partial).
    for (var i = 0; i < 7; i++) {
      await db.collection('reports').doc('r${i.toString().padLeft(2, '0')}').set({
        'order': i,
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(1700000000 + i),
      });
    }
  });

  Query<Map<String, dynamic>> query() => db.collection('reports').orderBy('order');

  group('CursorPaginator', () {
    test('fetchFirst returns the first page and sets hasMore=true if full',
        () async {
      final p = CursorPaginator(pageSize: 3);
      final snap = await p.fetchFirst(query());
      expect(snap.docs.length, 3);
      expect(snap.docs.map((d) => d.id),
          ['r00', 'r01', 'r02']);
      expect(p.hasMore, isTrue);
    });

    test('fetchNext walks through subsequent pages and stops on partial',
        () async {
      final p = CursorPaginator(pageSize: 3);
      await p.fetchFirst(query());

      final page2 = await p.fetchNext(query());
      expect(page2, isNotNull);
      expect(page2!.docs.map((d) => d.id), ['r03', 'r04', 'r05']);
      expect(p.hasMore, isTrue);

      final page3 = await p.fetchNext(query());
      expect(page3, isNotNull);
      expect(page3!.docs.map((d) => d.id), ['r06']);
      // Short page → no more after this.
      expect(p.hasMore, isFalse);

      final page4 = await p.fetchNext(query());
      expect(page4, isNull); // hasMore=false short-circuits
    });

    test('fetchNext returns null before fetchFirst has set a cursor', () async {
      final p = CursorPaginator(pageSize: 3);
      final result = await p.fetchNext(query());
      expect(result, isNull);
    });

    test('reset clears state so the next fetchFirst starts from the top',
        () async {
      final p = CursorPaginator(pageSize: 3);
      await p.fetchFirst(query());
      await p.fetchNext(query());
      p.reset();
      expect(p.hasMore, isTrue);
      final reread = await p.fetchFirst(query());
      expect(reread.docs.first.id, 'r00');
    });

    test('exact-multiple page count keeps hasMore=true until the empty page',
        () async {
      // 6 docs / pageSize=3 → 2 full pages, then a 0-doc third page.
      // The current implementation marks hasMore=false only when a fetched
      // page is short. After exactly N*pageSize docs, the *next* fetch
      // returns 0 docs and hasMore flips to false then.
      await db.collection('reports').doc('r06').delete();
      final p = CursorPaginator(pageSize: 3);
      await p.fetchFirst(query());
      expect(p.hasMore, isTrue);
      await p.fetchNext(query());
      expect(p.hasMore, isTrue);
      final tail = await p.fetchNext(query());
      expect(tail, isNotNull);
      expect(tail!.docs, isEmpty);
      expect(p.hasMore, isFalse);
    });
  });
}
