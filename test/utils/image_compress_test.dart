import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flyconnect/shared/utils/image_compress.dart';

void main() {
  // Headless tests cannot reliably decode actual images via `dart:ui`
  // in flutter_test — `instantiateImageCodec` needs the platform's
  // image backend. So these tests focus on the **fallback contract**:
  // when decode fails, we return the original bytes unchanged.

  group('compressForUpload (fallback path)', () {
    test('empty bytes returns the same empty Uint8List', () async {
      final input = Uint8List(0);
      final out = await compressForUpload(input);
      expect(out, isA<Uint8List>());
      expect(out.length, 0);
    });

    test('corrupt / non-image bytes fall back to the original bytes',
        () async {
      // "hello world" is obviously not a valid image. The codec
      // must throw and the function must return our input untouched.
      final input = Uint8List.fromList(
          'hello world this is not an image'.codeUnits);
      final out = await compressForUpload(input);
      expect(out, equals(input));
    });

    test('honours a custom maxDimension without throwing on garbage input',
        () async {
      final input = Uint8List.fromList(List.filled(64, 0));
      final out = await compressForUpload(input, maxDimension: 256);
      // Garbage -> codec fails -> original returned.
      expect(out, equals(input));
    });

    test('returns a Uint8List (never null) even on totally bogus input',
        () async {
      final input = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      final out = await compressForUpload(input);
      expect(out, isNotNull);
      expect(out, isA<Uint8List>());
    });
  });
}
