import 'package:drop/features/admin/presentation/dashboard_mood.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DashboardMood mood({
    int reviews = 0,
    int overdue = 0,
    int unassigned = 0,
    int rejected = 0,
    int running = 0,
    int completedToday = 0,
    int hour = 10,
  }) =>
      dashboardMood(
        reviews: reviews,
        overdue: overdue,
        unassigned: unassigned,
        rejected: rejected,
        running: running,
        completedToday: completedToday,
        now: DateTime(2026, 7, 9, hour),
      );

  group('dashboardMood — calm states', () {
    test('running work with nothing waiting reads "running smoothly" (calm)', () {
      final m = mood(running: 3);
      expect(m.tone, MoodTone.calm);
      expect(m.headline, 'Everything’s running smoothly');
      expect(m.emphasised, isFalse);
    });

    test('idle but productive today reads "all caught up"', () {
      final m = mood(completedToday: 4);
      expect(m.tone, MoodTone.calm);
      expect(m.headline, contains('caught up'));
    });

    test('genuinely idle reads a time-aware quiet line', () {
      expect(mood(hour: 8).headline, 'Quiet morning');
      expect(mood(hour: 14).headline, 'Calm afternoon');
      expect(mood(hour: 23).headline, 'Quiet night');
    });
  });

  group('dashboardMood — attention states', () {
    test('a single dominant category reads specifically', () {
      expect(mood(reviews: 5).headline, '5 reviews waiting');
      expect(mood(reviews: 1).headline, '1 review waiting');
      expect(mood(overdue: 2).headline, '2 tasks overdue');
      expect(mood(unassigned: 1).headline, '1 task unassigned');
      expect(mood(rejected: 3).headline, '3 tasks sent back');
    });

    test('a single waiting item is attention tone with a warning pulse', () {
      final m = mood(reviews: 2);
      expect(m.tone, MoodTone.attention);
      expect(m.emphasised, isTrue);
    });

    test('several categories collapse into one total headline', () {
      final m = mood(reviews: 1, overdue: 1, unassigned: 1);
      expect(m.headline, '3 tasks need your attention');
      expect(m.tone, MoodTone.attention);
    });

    test('a heavy board escalates to the busy tone with the part of day', () {
      final m = mood(reviews: 3, overdue: 3, unassigned: 2, hour: 14);
      expect(m.tone, MoodTone.busy);
      expect(m.headline, startsWith('Busy afternoon'));
      expect(m.headline, contains('8 tasks need your attention'));
    });
  });

  test('partOfDay maps the clock to a human word', () {
    expect(partOfDay(6), 'morning');
    expect(partOfDay(13), 'afternoon');
    expect(partOfDay(19), 'evening');
    expect(partOfDay(23), 'night');
  });
}
