import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/storages/daily_scores_storage.dart';
import 'package:storypad/core/types/calendar_system_option.dart';
import 'package:storypad/providers/daily_score_provider.dart';

/// Stands in for SharedPreferences so the provider can be exercised without a
/// binding at all. Only the two methods the provider calls are overridden.
class _MemoryStorage extends DailyScoresStorage {
  _MemoryStorage([Map<String, int>? initial]) : scores = {...?initial};

  final Map<String, int> scores;
  int writes = 0;

  @override
  Future<Map<String, int>> readScores() async => {...scores};

  @override
  Future<void> writeScores(Map<String, int> value) async {
    writes++;
    scores
      ..clear()
      ..addAll(value);
  }
}

void main() {
  setUp(CalendarConfig.reset);
  tearDown(CalendarConfig.reset);

  group('DailyScoresStorage', () {
    test('keys are zero-padded dates, so they sort as strings', () {
      expect(DailyScoresStorage.keyOf(DateTime(2026, 8, 5, 23, 59)), '2026-08-05');
      expect(DailyScoresStorage.keyOf(DateTime(2026, 11, 15)), '2026-11-15');
    });

    test('a key round-trips back to a date-only DateTime', () {
      expect(DailyScoresStorage.dateOf('2026-11-15'), DateTime(2026, 11, 15));
      expect(DailyScoresStorage.dateOf('nonsense'), isNull);
    });

    test('decode drops junk keys and values, and clamps out-of-range scores', () {
      final Map<String, int> decoded = DailyScoresStorage.decode({
        '2026-11-15': 72,
        '2026-11-16': 120,
        '2026-11-17': -5,
        '2026-11-18': 'not a number',
        'not-a-date': 40,
      });

      expect(decoded, {
        '2026-11-15': 72,
        '2026-11-16': 100,
        '2026-11-17': 0,
      });
    });

    test('a null object decodes to no scores, not to an error', () {
      expect(DailyScoresStorage.decode(null), isEmpty);
    });
  });

  group('DailyScoreProvider', () {
    test('loads what was persisted', () async {
      final storage = _MemoryStorage({'2026-11-15': 72});
      final provider = DailyScoreProvider(storage: storage);
      await provider.load();

      expect(provider.scoreOf(DateTime(2026, 11, 15)), 72);
      expect(provider.loaded, isTrue);
    });

    test('an unrated day is null — never a zero', () async {
      final provider = DailyScoreProvider(storage: _MemoryStorage());
      expect(provider.scoreOf(DateTime(2026, 11, 14)), isNull);
      expect(provider.scoresOfDisplayMonth(2026, 11), isEmpty);
    });

    test('setScore persists, clamps, and only writes real changes', () async {
      final storage = _MemoryStorage();
      final provider = DailyScoreProvider(storage: storage);
      await provider.load();

      await provider.setScore(DateTime(2026, 11, 15, 8), 140);
      expect(provider.scoreOf(DateTime(2026, 11, 15)), 100);
      expect(storage.scores['2026-11-15'], 100);

      final int writesAfterFirst = storage.writes;
      await provider.setScore(DateTime(2026, 11, 15), 100);
      expect(storage.writes, writesAfterFirst, reason: 'setting the same value is a no-op');
    });

    test('a null score removes the day entirely', () async {
      final storage = _MemoryStorage({'2026-11-15': 72});
      final provider = DailyScoreProvider(storage: storage);
      await provider.load();

      await provider.setScore(DateTime(2026, 11, 15), null);

      expect(provider.scoreOf(DateTime(2026, 11, 15)), isNull);
      expect(storage.scores, isEmpty);
    });

    test('setScore notifies listeners before the write completes', () async {
      final provider = DailyScoreProvider(storage: _MemoryStorage());
      await provider.load();

      int notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setScore(DateTime(2026, 11, 15), 40);
      expect(notifications, 1);
    });

    test('a month exposes only its rated days', () async {
      final provider = DailyScoreProvider(
        storage: _MemoryStorage({
          '2026-11-01': 10,
          '2026-11-15': 90,
          '2026-10-31': 50, // previous month
          '2026-12-01': 60, // next month
        }),
      );
      await provider.load();

      expect(provider.scoresOfDisplayMonth(2026, 11), {1: 10, 15: 90});
      expect(provider.averageOfDisplayMonth(2026, 11)?.average, 50.0);
      expect(provider.averageOfDisplayMonth(2026, 9), isNull);
    });

    test('monthly averages skip months without data and run oldest first', () async {
      final provider = DailyScoreProvider(
        storage: _MemoryStorage({
          '2026-09-10': 20,
          '2026-09-11': 40,
          '2026-11-10': 80,
        }),
      );
      await provider.load();

      final averages = provider.monthlyAverages();
      expect(averages.map((month) => month.id), ['2026-9', '2026-11']);
      expect(averages.first.average, 30.0);
      expect(averages.first.days, 2);
      expect(averages.last.average, 80.0);
    });

    test('monthly averages keep only the most recent months', () async {
      final provider = DailyScoreProvider(
        storage: _MemoryStorage({
          for (int month = 1; month <= 12; month++) '2026-${month.toString().padLeft(2, '0')}-05': month * 5,
        }),
      );
      await provider.load();

      final averages = provider.monthlyAverages(limit: 3);
      expect(averages.map((month) => month.id), ['2026-10', '2026-11', '2026-12']);
    });

    group('persian calendar', () {
      setUp(() => CalendarConfig.apply(system: CalendarSystemOption.persian));

      test('a stored Gregorian day is read as its Shamsi day', () async {
        // 2026-11-15 is 24 Aban 1405.
        final provider = DailyScoreProvider(storage: _MemoryStorage({'2026-11-15': 72}));
        await provider.load();

        expect(provider.scoresOfDisplayMonth(1405, 8), {24: 72});
        expect(provider.scoreOnDisplayDay(1405, 8, 24), 72);
        // ...and the Gregorian month it happens to fall in is not where it shows.
        expect(provider.scoresOfDisplayMonth(2026, 11), isEmpty);
      });

      test('months are grouped by the displayed calendar', () async {
        final provider = DailyScoreProvider(
          storage: _MemoryStorage({
            '2026-11-15': 72, // 24 Aban 1405
            '2026-11-03': 30, // 12 Aban 1405
            '2026-10-25': 50, // 3 Aban 1405
          }),
        );
        await provider.load();

        final averages = provider.monthlyAverages();
        expect(averages.length, 1, reason: 'all three days are in Aban, whatever Gregorian months they touch');
        expect(averages.single.year, 1405);
        expect(averages.single.month, 8);
        expect(averages.single.days, 3);
      });
    });
  });
}
