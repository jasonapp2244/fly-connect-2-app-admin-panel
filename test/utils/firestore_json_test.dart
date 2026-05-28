import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyconnect/shared/utils/firestore_json.dart';

void main() {
  group('normaliseForJson', () {
    test('passes primitives through unchanged', () {
      expect(normaliseForJson(null), isNull);
      expect(normaliseForJson(42), 42);
      expect(normaliseForJson(3.14), 3.14);
      expect(normaliseForJson(true), true);
      expect(normaliseForJson('hello'), 'hello');
    });

    test('converts Timestamp to a parseable ISO 8601 string', () {
      final original = DateTime.utc(2026, 1, 15, 10, 30, 0);
      final ts = Timestamp.fromDate(original);
      final out = normaliseForJson(ts);
      expect(out, isA<String>());
      // Timestamp.toDate() yields a local DateTime; round-tripping
      // through DateTime.parse + .toUtc must equal the original UTC.
      expect(DateTime.parse(out as String).toUtc(), original);
    });

    test('converts DateTime to its ISO 8601 representation', () {
      final dt = DateTime.utc(2026, 5, 28, 9, 0, 0);
      expect(normaliseForJson(dt), dt.toIso8601String());
    });

    test('converts GeoPoint to lat/lng map', () {
      const gp = GeoPoint(40.7128, -74.0060);
      final out = normaliseForJson(gp) as Map;
      expect(out['lat'], 40.7128);
      expect(out['lng'], -74.0060);
    });

    test('converts DocumentReference to its full path string', () {
      final fake = FakeFirebaseFirestore();
      final ref = fake.collection('users').doc('abc123');
      expect(normaliseForJson(ref), 'users/abc123');
    });

    test('recurses into lists', () {
      final original = DateTime.utc(2026, 1, 1);
      final ts = Timestamp.fromDate(original);
      final out = normaliseForJson([1, 'a', ts, true]) as List;
      expect(out[0], 1);
      expect(out[1], 'a');
      expect(DateTime.parse(out[2] as String).toUtc(), original);
      expect(out[3], true);
    });

    test('recurses into maps and stringifies keys', () {
      final original = DateTime.utc(2026, 1, 1);
      final input = <dynamic, dynamic>{
        'name': 'Pat',
        42: 'numeric-key',
        'createdAt': Timestamp.fromDate(original),
        'loc': const GeoPoint(0, 0),
      };
      final out = normaliseForJson(input) as Map;
      expect(out['name'], 'Pat');
      expect(out['42'], 'numeric-key');
      expect(DateTime.parse(out['createdAt'] as String).toUtc(), original);
      expect((out['loc'] as Map)['lat'], 0);
    });

    test('recurses through nested structures', () {
      final original = DateTime.utc(2026, 1, 1);
      final input = {
        'user': {
          'id': 'u1',
          'history': [
            {'at': Timestamp.fromDate(original), 'event': 'x'},
          ],
        },
      };
      final out = normaliseForJson(input) as Map;
      final history = (out['user'] as Map)['history'] as List;
      expect(
          DateTime.parse((history[0] as Map)['at'] as String).toUtc(),
          original);
    });

    test('falls back to toString for unknown types', () {
      final out = normaliseForJson(_Opaque());
      expect(out, '<<opaque>>');
    });

    test('result is jsonEncode-able end to end', () {
      final fake = FakeFirebaseFirestore();
      final input = {
        'id': 'export-1',
        'when': Timestamp.fromDate(DateTime.utc(2026, 5, 28)),
        'loc': const GeoPoint(1.5, 2.5),
        'ref': fake.collection('reports').doc('r1'),
        'items': [
          1,
          {'nested': const GeoPoint(3, 4)},
        ],
      };
      // If anything is unencodable this throws.
      final s = jsonEncode(normaliseForJson(input));
      expect(s.contains('reports/r1'), isTrue);
      // GeoPoint nesting survived.
      expect(s.contains('"lat":3'), isTrue);
    });
  });
}

class _Opaque {
  @override
  String toString() => '<<opaque>>';
}
