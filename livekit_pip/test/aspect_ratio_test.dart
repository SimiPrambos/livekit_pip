import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip/src/aspect_ratio.dart';

void main() {
  group('clampPipAspectRatio', () {
    test('in-range ratio is unchanged', () {
      expect(clampPipAspectRatio(1280, 720), (width: 1280, height: 720));
    });

    test('zero or negative returns (0, 0)', () {
      expect(clampPipAspectRatio(0, 720), (width: 0, height: 0));
      expect(clampPipAspectRatio(1280, 0), (width: 0, height: 0));
      expect(clampPipAspectRatio(-1, -1), (width: 0, height: 0));
    });

    test('too-wide is clamped to 2.39:1', () {
      final r = clampPipAspectRatio(3000, 1000); // 3.0 ratio
      expect(r.height, 1000);
      expect(r.width / r.height, closeTo(2.39, 0.01));
    });

    test('too-tall is clamped to 1:2.39', () {
      final r = clampPipAspectRatio(1000, 3000); // 0.333 ratio
      expect(r.width, 1000);
      expect(r.width / r.height, closeTo(1 / 2.39, 0.01));
    });
  });
}
