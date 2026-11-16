import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/search_filter_object.dart';
import 'package:storypad/core/services/calendar/calendar_config.dart';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/types/calendar_system_option.dart';
import 'package:storypad/core/types/path_type.dart';

/// `SearchFilterObject` is the boundary between what the user sees and what the
/// database is asked for (D-025…D-029): display years go in, storage years plus
/// exact day ranges come out. The calendar tests cover the conversions that sit
/// behind it; these cover the object itself — which fields survive, what a query
/// clears, and that `encode` can always be used for a widget key.
///
/// The regression they exist for: `jsonEncode` on a raw filter map threw
/// `Converting object to an encodable object failed: Instance of 'DateTime'`
/// once Shamsi mode put `DateTime`s into it (D-028 §6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(CalendarConfig.reset);
  tearDown(CalendarConfig.reset);

  SearchFilterObject empty({Set<PathType>? types}) => SearchFilterObject(
    years: {},
    types: types ?? {PathType.docs},
    assetId: null,
  );

  group('toDatabaseFilter', () {
    test('only carries the fields that were set', () {
      final filters = empty().toDatabaseFilter()!;

      expect(filters, {
        'types': ['docs'],
      });
    });

    test('maps every supported field to its query key', () {
      final filter = SearchFilterObject(
        years: {2026},
        types: {PathType.docs, PathType.archives},
        assetId: 12,
        storyIds: {3, 4},
        tagIds: {7},
        excludeYears: {2020},
        galleryTemplateId: 'gallery',
        templateId: 9,
        month: 11,
        day: 15,
        starred: true,
        pinned: false,
        limit: 60,
        offset: 120,
      );

      final filters = filter.toDatabaseFilter()!;

      expect(filters['years'], [2026]);
      expect(filters['types'], containsAll(<String>['docs', 'archives']));
      expect(filters['asset'], 12);
      expect(filters['ids'], containsAll(<int>[3, 4]));
      expect(filters['tags'], [7]);
      expect(filters['exclude_years'], [2020]);
      expect(filters['gallery_template_id'], 'gallery');
      expect(filters['template'], 9);
      expect(filters['month'], 11);
      expect(filters['day'], 15);
      expect(filters['starred'], true);
      expect(filters['pinned'], false);
      expect(filters['limit'], 60);
      expect(filters['offset'], 120);
    });

    test('skips empty collections instead of sending meaningless conditions', () {
      final filter = SearchFilterObject(
        years: {},
        types: {},
        assetId: null,
        tagIds: {},
        storyIds: {},
      );

      expect(filter.toDatabaseFilter(), isEmpty);
    });

    test('a query searches the whole database and drops every date scope', () {
      // Gregorian on purpose: this test is about the query-clearing rule, and a
      // display year here would pull the calendar conversion into it as well.
      final filter = SearchFilterObject(
        years: {2026},
        types: {PathType.docs},
        assetId: null,
        query: '  آبان  ',
      );

      final filters = filter.toDatabaseFilter()!;

      expect(filters['query'], '  آبان  ', reason: 'the query is stored verbatim; trimming is the view\'s job');
      expect(filters['years'], isNull);
      expect(filters['date_ranges'], isNull);
      expect(filters['date_range'], isNull);
      expect(
        filters['types'],
        PathType.values.map((e) => e.name).toList(),
        reason: 'a text search must not be limited to the current tab (docs/bins/archives)',
      );
    });

    test('a blank query is not a search', () {
      final filter = SearchFilterObject(years: {2026}, types: {PathType.docs}, assetId: null, query: '   ');

      final filters = filter.toDatabaseFilter()!;

      expect(filters['query'], '   ');
      expect(filters['years'], [2026], reason: 'only a non-blank query widens the search');
    });
  });

  group('Shamsi display years', () {
    setUp(() => CalendarConfig.apply(system: CalendarSystemOption.persian));

    test('become Gregorian years plus an exact day range', () {
      final filters = SearchFilterObject(years: {1405}, types: {PathType.docs}, assetId: null).toDatabaseFilter()!;

      expect(filters['years'], [2026, 2027]);
      final ranges = filters['date_ranges'] as List;
      expect(ranges, hasLength(1));
      expect(ranges.single, [DateTime(2026, 3, 21), DateTime(2027, 3, 20)]);
    });

    test('a DateRangeFilterObject still converts its display years', () {
      final start = CalendarDisplay.firstDayOfMonth(1405, 8);
      final end = CalendarDisplay.lastDayOfMonth(1405, 8);
      final filter = DateRangeFilterObject(
        start: start,
        end: end,
        types: {PathType.docs},
        years: {1405},
      );

      final filters = filter.toDatabaseFilter()!;

      expect(filters['years'], [2026, 2027], reason: 'the inherited conversion must not be bypassed');
      expect(filters['date_range'], [start, end]);
    });

    test('two display years produce two ranges, in input-independent order', () {
      final filters = SearchFilterObject(
        years: {1405, 1404},
        types: {PathType.docs},
        assetId: null,
      ).toDatabaseFilter()!;

      expect(filters['years'], [2025, 2026, 2027]);
      expect((filters['date_ranges'] as List), hasLength(2));
    });
  });

  group('encode', () {
    test('is stable for equal filters and different for different ones', () {
      final a = empty().toDatabaseFilter();
      final b = empty().toDatabaseFilter();
      final c = SearchFilterObject(years: {2026}, types: {PathType.docs}, assetId: null).toDatabaseFilter();

      expect(SearchFilterObject.encode(a), SearchFilterObject.encode(b));
      expect(SearchFilterObject.encode(a), isNot(SearchFilterObject.encode(c)));
    });

    test('survives DateTime values that jsonEncode alone cannot serialize', () {
      CalendarConfig.apply(system: CalendarSystemOption.persian);
      final filters = SearchFilterObject(years: {1405}, types: {PathType.docs}, assetId: null).toDatabaseFilter();

      expect(
        () => jsonEncode(filters),
        throwsA(anything),
        reason: 'this is the crash D-028 fixed; the test documents it',
      );
      expect(() => SearchFilterObject.encode(filters), returnsNormally);
      expect(SearchFilterObject.encode(filters), contains('2026-03-21'));
    });

    test('a null or empty map encodes without throwing', () {
      expect(SearchFilterObject.encode(null), 'null');
      expect(SearchFilterObject.encode({}), '{}');
    });
  });

  group('DateRangeFilterObject', () {
    test('appends its own range after the inherited filters (Gregorian)', () {
      final start = DateTime(2026, 10, 1);
      final end = DateTime(2026, 10, 31);
      final filter = DateRangeFilterObject(
        start: start,
        end: end,
        types: {PathType.docs},
        years: {2026},
        month: 10,
        day: 15,
        tagIds: {2},
      );

      final filters = filter.toDatabaseFilter()!;

      expect(filters['date_range'], [start, end]);
      expect(filters['years'], [2026], reason: 'Gregorian years pass through untouched');
      expect(filters['types'], ['docs']);
      expect(filters['month'], 10, reason: 'kept so "on this day in another year" still works');
      expect(filters['day'], 15);
      expect(filters['tags'], [2]);
    });

    test('is JSON-safe through encode like any other filter', () {
      final filter = DateRangeFilterObject(
        start: DateTime(2026, 10, 23),
        end: DateTime(2026, 11, 21),
        types: {PathType.docs},
      );

      expect(SearchFilterObject.encode(filter.toDatabaseFilter()), contains('2026-10-23'));
    });
  });
}
