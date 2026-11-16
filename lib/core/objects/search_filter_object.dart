import 'dart:convert';
import 'package:storypad/core/services/calendar/calendar_display.dart';
import 'package:storypad/core/types/path_type.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'search_filter_object.g.dart';

@CopyWith()
@JsonSerializable()
class SearchFilterObject {
  final Set<int> years;
  final Set<int>? storyIds;
  final Set<int>? excludeYears;
  final String? query;
  final int? month;
  final int? day;
  final Set<PathType> types;
  final Set<int> tagIds;
  final String? galleryTemplateId;
  final int? templateId;
  final int? assetId;
  final bool? starred;
  final bool? pinned;
  final int? limit;
  final int? offset;

  SearchFilterObject({
    required this.years,
    required this.types,
    required this.assetId,
    this.storyIds,
    Set<int>? tagIds,
    this.query,
    this.galleryTemplateId,
    this.templateId,
    this.excludeYears,
    this.month,
    this.day,
    this.starred,
    this.pinned,
    this.limit,
    this.offset,
  }) : tagIds = tagIds ?? {};

  Map<String, dynamic>? toDatabaseFilter() {
    Map<String, dynamic> filters = {};

    if (query != null) filters['query'] = query;
    if (storyIds?.isNotEmpty == true) filters['ids'] = storyIds?.toList();
    // `years` holds *display* years (the chips the user picked). Gregorian mode
    // maps them straight to the `year` column; Shamsi mode also needs the exact
    // day ranges, since a Shamsi year spans two Gregorian years.
    if (years.isNotEmpty) filters.addAll(CalendarDisplay.yearsFilter(years));
    if (month != null) filters['month'] = month;
    if (day != null) filters['day'] = day;
    if (tagIds.isNotEmpty) filters['tags'] = tagIds.toList();
    if (excludeYears != null) filters['exclude_years'] = excludeYears?.toList();
    if (galleryTemplateId != null) filters['gallery_template_id'] = galleryTemplateId;
    if (templateId != null) filters['template'] = templateId;
    if (assetId != null) filters['asset'] = assetId;
    if (starred != null) filters['starred'] = starred;
    if (pinned != null) filters['pinned'] = pinned;
    if (types.isNotEmpty) filters['types'] = types.map((e) => e.name).toList();
    if (limit != null) filters['limit'] = limit;
    if (offset != null) filters['offset'] = offset;

    // Search whole database when has query.
    if (query?.trim().isNotEmpty == true) {
      filters['types'] = PathType.values.map((e) => e.name).toList();
      filters.remove('years');
      filters.remove('date_ranges');
      filters.remove('date_range');
    }

    return filters;
  }

  /// A JSON-safe string for a filter map — for widget keys and equality checks.
  ///
  /// [toDatabaseFilter] can carry `DateTime`s (the exact day range a Shamsi year
  /// resolves to; see `CalendarDisplay.yearsFilter`), which `jsonEncode` refuses
  /// to serialize and crashes on. Writing them as ISO-8601 keeps the key unique
  /// per filter without touching the filter itself.
  static String encode(Map<String, dynamic>? filters) {
    return jsonEncode(filters, toEncodable: (value) => value is DateTime ? value.toIso8601String() : value.toString());
  }

  Map<String, dynamic> toJson() => _$SearchFilterObjectToJson(this);
  factory SearchFilterObject.fromJson(Map<String, dynamic> json) => _$SearchFilterObjectFromJson(json);
}

/// A [SearchFilterObject] scoped to an exact Gregorian day range.
///
/// The calendar screens page months in the *display* calendar, and a Shamsi month
/// is not a value of the stored `month` column — it is a run of days spanning two
/// Gregorian months. The range is therefore the only exact way to say "this
/// month" (or "this day") without changing how anything is stored.
///
/// `years` still carries the display years the range touches, so the
/// filter-object contract (display years in, storage years + ranges out) holds and
/// the throwback tile keeps working for single-day filters.
class DateRangeFilterObject extends SearchFilterObject {
  DateRangeFilterObject({
    required this.start,
    required this.end,
    required Set<PathType> types,
    Set<int>? years,
    int? month,
    int? day,
    Set<int>? tagIds,
    Set<int>? storyIds,
  }) : super(
         years: years ?? const {},
         types: types,
         assetId: null,
         month: month,
         day: day,
         tagIds: tagIds,
         storyIds: storyIds,
       );

  /// First and last day of the range, inclusive.
  final DateTime start;
  final DateTime end;

  @override
  Map<String, dynamic> toDatabaseFilter() {
    return {
      ...super.toDatabaseFilter()!,
      'date_range': [start, end],
    };
  }
}
