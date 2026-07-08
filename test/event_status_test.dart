import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/event_status.dart';

void main() {
  group('EventStatus lifecycle', () {
    test('has the seven expected states', () {
      expect(EventStatus.values.length, 7);
    });

    test('active vs terminal split', () {
      for (final s in [
        EventStatus.draft,
        EventStatus.planning,
        EventStatus.ready,
        EventStatus.live,
      ]) {
        expect(s.isActive, isTrue, reason: '$s should be active');
        expect(s.isTerminal, isFalse);
      }
      for (final s in [
        EventStatus.completed,
        EventStatus.archived,
        EventStatus.cancelled,
      ]) {
        expect(s.isActive, isFalse, reason: '$s should be terminal');
        expect(s.isTerminal, isTrue);
      }
    });

    test('preparing states are the pre-live active ones', () {
      expect(EventStatus.draft.isPreparing, isTrue);
      expect(EventStatus.planning.isPreparing, isTrue);
      expect(EventStatus.ready.isPreparing, isTrue);
      expect(EventStatus.live.isPreparing, isFalse);
      expect(EventStatus.completed.isPreparing, isFalse);
    });

    test('advanceTo walks the happy path forward, terminals stop', () {
      expect(EventStatus.draft.advanceTo, EventStatus.planning);
      expect(EventStatus.planning.advanceTo, EventStatus.ready);
      expect(EventStatus.ready.advanceTo, EventStatus.live);
      expect(EventStatus.live.advanceTo, EventStatus.completed);
      expect(EventStatus.completed.advanceTo, EventStatus.archived);
      expect(EventStatus.archived.advanceTo, isNull);
      expect(EventStatus.cancelled.advanceTo, isNull);
    });

    test('advanceLabel exists exactly where advanceTo does', () {
      for (final s in EventStatus.values) {
        expect(s.advanceLabel != null, s.advanceTo != null,
            reason: '$s label/target mismatch');
      }
    });

    test('cancel is possible only while active', () {
      expect(EventStatus.planning.canCancel, isTrue);
      expect(EventStatus.live.canCancel, isTrue);
      expect(EventStatus.completed.canCancel, isFalse);
      expect(EventStatus.cancelled.canCancel, isFalse);
    });

    test('fromString is lenient and defaults to draft', () {
      expect(EventStatus.fromString('live'), EventStatus.live);
      expect(EventStatus.fromString('archived'), EventStatus.archived);
      expect(EventStatus.fromString('nonsense'), EventStatus.draft);
      expect(EventStatus.fromString(null), EventStatus.draft);
    });
  });
}
