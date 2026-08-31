// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readblank/l10n/app_localizations.dart';
import 'package:readblank/screens/plain_text_page.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/activity_notifier.dart';
import '../providers/app_preferences_notifier.dart';
import '../providers/contents_notifier.dart';
import '../views/daily_chart_view.dart';
import '../views/monthly_chart_view.dart';
import '../views/weekly_chart_view.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  static const String _keyCount = 'count';
  static const String _keyLinkId = 'link_id';
  static const String _keyLocale = 'locale';
  static const String _keyTitle = 'title';
  static const String _keyUrl = 'url';
  static const String _keyWords = 'words';

  static final DateTime _startDate = DateTime(2026, 1, 1);
  final DailyChartViewController _dailyChartController =
      DailyChartViewController();
  final WeeklyChartViewController _weeklyChartController =
      WeeklyChartViewController();
  final MonthlyChartViewController _monthlyChartController =
      MonthlyChartViewController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Consumer2<ActivityNotifier, ContentsNotifier>(
        builder: (context, activityNotifier, contentsNotifier, child) {
          if (activityNotifier.isLoading &&
              activityNotifier.wordLog.isEmpty &&
              activityNotifier.currentChartData.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final viewedContents = _getViewedContents(
            activityNotifier,
            contentsNotifier,
          );

          final view = activityNotifier.viewMode == ActivityViewMode.daily
              ? _buildDailyView(
                  activityNotifier,
                  contentsNotifier,
                  viewedContents,
                )
              : activityNotifier.viewMode == ActivityViewMode.weekly
              ? _buildWeeklyView(
                  activityNotifier,
                  contentsNotifier,
                  viewedContents,
                )
              : _buildMonthlyView(
                  activityNotifier,
                  contentsNotifier,
                  viewedContents,
                );

          return Stack(
            children: [
              view,
              if (activityNotifier.isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          );
        },
      ),
    );
  }

  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _getStartDayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  DateTime _geEndDayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 7));
  }

  DateTime _getStartDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _getOneDayAgo(DateTime date) {
    return date.subtract(const Duration(days: 1));
  }

  DateTime _getOneDayLater(DateTime date) {
    return date.add(const Duration(days: 1));
  }

  DateTime _getSevenDaysAgo(DateTime date) {
    return date.subtract(const Duration(days: 7));
  }

  DateTime _getSevenDaysLater(DateTime date) {
    return date.add(const Duration(days: 7));
  }

  DateTime _getOneMonthAgo(DateTime date) {
    final temp = DateTime(date.year, date.month - 1, date.day);
    return temp.day == date.day ? temp : DateTime(date.year, date.month, 0);
  }

  DateTime _getOneMonthLater(DateTime date) {
    final temp = DateTime(date.year, date.month + 1, date.day);
    return temp.day == date.day ? temp : DateTime(date.year, date.month + 2, 0);
  }

  bool _isInSameWeek(DateTime date1, DateTime date2) {
    return _getStartDayOfWeek(
      date1,
    ).isAtSameMomentAs(_getStartDayOfWeek(date2));
  }

  bool _isInSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }

  bool _isInSameYear(DateTime date1, DateTime date2) {
    return date1.year == date2.year;
  }

  bool _isOnOrBeforeStartDate(DateTime date) {
    return date.isAtSameMomentAs(_startDate) || _isBeforeStartDate(date);
  }

  bool _isInOrBeforeStartWeek(DateTime date) {
    return _isInSameWeek(date, _startDate) || _isBeforeStartDate(date);
  }

  bool _isInOrBeforeStartMonth(DateTime date) {
    return _isInSameMonth(date, _startDate) || _isBeforeStartDate(date);
  }

  bool _isBeforeStartDate(DateTime date) {
    return date.isBefore(_startDate);
  }

  bool _isBeforeStartWeek(DateTime date) {
    return _getStartDayOfWeek(date).isBefore(_getStartDayOfWeek(_startDate));
  }

  bool _isOnOrAfterToday(DateTime date) {
    return date.isAtSameMomentAs(today) || _isAfterToday(date);
  }

  bool _isInOrAfterThisWeek(DateTime date) {
    return _isInSameWeek(date, today) || _isAfterToday(date);
  }

  bool _isInOrAfterThisMonth(DateTime date) {
    return _isInSameMonth(date, today) || _isAfterToday(date);
  }

  bool _isAfterToday(DateTime date) {
    return date.isAfter(today);
  }

  bool _isAfterThisWeek(DateTime date) {
    return _getStartDayOfWeek(date).isAfter(_getStartDayOfWeek(today));
  }

  bool _isNotInRange(DateTime date) {
    return _isBeforeStartDate(date) || _isAfterToday(date);
  }

  Widget _buildContentList(List<Map<String, dynamic>> contents) {
    final l10n = AppLocalizations.of(context)!;

    return ListView.separated(
      itemCount: contents.length,
      itemBuilder: (context, index) {
        final content = contents[index];
        final title = content[_keyTitle] ?? l10n.noTitle;
        final url = content[_keyUrl] ?? '';
        final words = content[_keyWords] as List<String>? ?? [];
        final count = content[_keyCount] as int? ?? 0;
        final locale = content[_keyLocale] as String? ?? '';
        final domain = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';

        return ListTile(
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text(
            count.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (domain.isNotEmpty) Text('$domain [$locale]'),
              if (words.isNotEmpty)
                Text(
                  words.join(', '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      },
      separatorBuilder: (context, index) {
        return const Divider(height: 1, thickness: 1);
      },
    );
  }

  Widget _buildWordList(
    String keyString,
    List<WordSummary> entries,
    ContentsNotifier contentsNotifier,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return ListView.separated(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final uniqueLinkIds = entry.linkIds.toSet().toList();
        final linkedContents = uniqueLinkIds.map((id) {
          return contentsNotifier.linkList.firstWhere(
            (c) => c[_keyLinkId] == id,
            orElse: () => {_keyLinkId: id, _keyTitle: l10n.noTitle},
          );
        }).toList();

        return ExpansionTile(
          key: PageStorageKey('${keyString}_${entry.word}'),
          controlAffinity: ListTileControlAffinity.leading,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(entry.word, maxLines: 1, overflow: TextOverflow.ellipsis),
              IconButton(
                icon: Icon(Icons.share),
                onPressed: () async {
                  SharePlus.instance.share(ShareParams(text: entry.word));
                },
              ),
            ],
          ),
          trailing: Text(
            entry.count.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          children: linkedContents.map((content) {
            final title = content[_keyTitle] ?? l10n.noTitle;
            final url = content[_keyUrl] ?? '';
            final domain =
                Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
            final locale = content[_keyLocale] as String? ?? '';

            return ListTile(
              title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: domain.isNotEmpty ? Text('$domain [$locale]') : null,
              trailing: IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (BuildContext context) {
                        return PlainTextPage(
                          title: title,
                          domain: domain,
                          paragraphs:
                              contentsNotifier.currentParagraphList ??
                              <String>[],
                          searchWord: entry.word,
                        );
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.text_snippet),
              ),
            );
          }).toList(),
        );
      },
      separatorBuilder: (context, index) {
        return const Divider(height: 1, thickness: 1);
      },
    );
  }

  List<Map<String, dynamic>> _getViewedContents(
    ActivityNotifier activityNotifier,
    ContentsNotifier contentsNotifier,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final linkIds = activityNotifier.currentWordEntries
        .expand((summary) => summary.linkIds)
        .toSet();

    return linkIds.map((id) {
      final matchingSummaries = activityNotifier.currentWordEntries.where(
        (s) => s.linkIds.contains(id),
      );

      final words = matchingSummaries.map((s) => s.word).toList()..sort();

      final count = matchingSummaries.fold(0, (sum, s) {
        return sum + s.linkIds.where((lid) => lid == id).length;
      });

      final content = contentsNotifier.linkList.firstWhere(
        (c) => c[_keyLinkId] == id,
        orElse: () => {_keyLinkId: id, _keyTitle: l10n.noTitle, _keyUrl: ''},
      );

      return {...content, _keyWords: words, _keyCount: count};
    }).toList();
  }

  Widget _buildNestedScrollView({
    required Widget header,
    required String keyString,
    required List<WordSummary> entries,
    required ContentsNotifier contentsNotifier,
    required List<Map<String, dynamic>> viewedContents,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(child: header),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                labelStyle: Theme.of(context).textTheme.bodySmall,
                tabs: [
                  Tab(
                    text: l10n.contentsViewedLabel,
                    icon: const Icon(Icons.library_books),
                  ),
                  Tab(
                    text: l10n.wordsEncounteredLabel,
                    icon: const Icon(Icons.abc),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        children: [
          _buildContentList(viewedContents),
          _buildWordList(keyString, entries, contentsNotifier),
        ],
      ),
    );
  }

  Widget _buildDailyView(
    ActivityNotifier activityNotifier,
    ContentsNotifier contentsNotifier,
    List<Map<String, dynamic>> viewedContents,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final fontSizeFactor = context
        .watch<AppPreferencesNotifier>()
        .fontSizeFactor;
    final selectedDate = activityNotifier.selectedDate;

    if (_isBeforeStartDate(selectedDate)) {
      activityNotifier.selectedDate = _startDate;
    } else if (_isAfterToday(selectedDate)) {
      activityNotifier.selectedDate = today;
    }

    final currentData = activityNotifier.currentChartData;
    final previousData = activityNotifier.previousChartData;
    final nextData = activityNotifier.nextChartData;

    final entries = activityNotifier.currentWordEntries;

    return _buildNestedScrollView(
      header: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_left),
                onPressed: _isOnOrBeforeStartDate(selectedDate)
                    ? null
                    : () {
                        activityNotifier.selectedDate = _getOneDayAgo(
                          selectedDate,
                        );
                      },
              ),
              Text(
                l10n.dateFormatForDailyChart(selectedDate),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_right),
                onPressed: _isOnOrAfterToday(selectedDate)
                    ? null
                    : () {
                        activityNotifier.selectedDate = _getOneDayLater(
                          selectedDate,
                        );
                      },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.abc),
              Text(l10n.wordCount(activityNotifier.currentCount)),
            ],
          ),
          DailyChartView(
            key: UniqueKey(),
            controller: _dailyChartController,
            currentData: currentData,
            previousData: previousData,
            nextData: nextData,
            barColor: Theme.of(context).colorScheme.tertiary,
            textColor: Theme.of(context).colorScheme.onSurface,
            fontSize: 12.0 * fontSizeFactor,
            onSwipeLeft: _isOnOrAfterToday(selectedDate)
                ? null
                : () {
                    activityNotifier.selectedDate = _getOneDayLater(
                      selectedDate,
                    );
                  },
            onSwipeRight: _isOnOrBeforeStartDate(selectedDate)
                ? null
                : () {
                    activityNotifier.selectedDate = _getOneDayAgo(
                      selectedDate,
                    );
                  },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
        ],
      ),
      keyString: 'Daily_$selectedDate',
      entries: entries,
      contentsNotifier: contentsNotifier,
      viewedContents: viewedContents,
    );
  }

  String _dateLabelForWeeklyChart(DateTime selectedDate) {
    final l10n = AppLocalizations.of(context)!;
    final startDay = _getStartDayOfWeek(selectedDate);
    final endDay = _geEndDayOfWeek(selectedDate);
    return (_isInSameMonth(startDay, endDay)
        ? l10n.dateFormatForWeeklyChartInSameMonth
        : _isInSameYear(startDay, endDay)
        ? l10n.dateFormatForWeeklyChartInSameYear
        : l10n.dateFormatForWeeklyChart)(startDay, endDay);
  }

  Widget _buildWeeklyView(
    ActivityNotifier activityNotifier,
    ContentsNotifier contentsNotifier,
    List<Map<String, dynamic>> viewedContents,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final fontSizeFactor = context
        .watch<AppPreferencesNotifier>()
        .fontSizeFactor;
    final selectedDate = activityNotifier.selectedDate;

    if (_isBeforeStartWeek(selectedDate)) {
      activityNotifier.selectedDate = _startDate;
    } else if (_isAfterThisWeek(selectedDate)) {
      activityNotifier.selectedDate = today;
    }

    final currentData = activityNotifier.currentChartData;
    final previousData = activityNotifier.previousChartData;
    final nextData = activityNotifier.nextChartData;

    final entries = activityNotifier.currentWordEntries;

    return _buildNestedScrollView(
      header: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_left),
                onPressed: _isInOrBeforeStartWeek(selectedDate)
                    ? null
                    : () {
                        activityNotifier.selectedDate = _getSevenDaysAgo(
                          selectedDate,
                        );
                      },
              ),
              Expanded(
                child: Text(
                  _dateLabelForWeeklyChart(selectedDate),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_right),
                onPressed: _isInOrAfterThisWeek(selectedDate)
                    ? null
                    : () {
                        activityNotifier.selectedDate = _getSevenDaysLater(
                          selectedDate,
                        );
                      },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.abc),
              Text(l10n.wordCount(activityNotifier.currentCount)),
            ],
          ),
          WeeklyChartView(
            key: UniqueKey(),
            controller: _weeklyChartController,
            currentData: currentData,
            previousData: previousData,
            nextData: nextData,
            barColor: Theme.of(context).colorScheme.tertiary,
            textColor: Theme.of(context).colorScheme.onSurface,
            fontSize: 12.0 * fontSizeFactor,
            onSwipeLeft: _isInOrAfterThisWeek(selectedDate)
                ? null
                : () {
                    activityNotifier.selectedDate = _getSevenDaysLater(
                      selectedDate,
                    );
                  },
            onSwipeRight: _isInOrBeforeStartWeek(selectedDate)
                ? null
                : () {
                    activityNotifier.selectedDate = _getSevenDaysAgo(
                      selectedDate,
                    );
                  },
            onDailyViewSelected: (int index) {
              final tappedDate = _getStartDayOfWeek(
                selectedDate,
              ).add(Duration(days: index));

              if (_isNotInRange(tappedDate)) return;

              activityNotifier.selectedDate = tappedDate;
              activityNotifier.viewMode = ActivityViewMode.daily;
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
        ],
      ),
      keyString: 'Weekly_$selectedDate',
      entries: entries,
      contentsNotifier: contentsNotifier,
      viewedContents: viewedContents,
    );
  }

  Widget _buildMonthlyView(
    ActivityNotifier activityNotifier,
    ContentsNotifier contentsNotifier,
    List<Map<String, dynamic>> viewedContents,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final fontSizeFactor = context
        .watch<AppPreferencesNotifier>()
        .fontSizeFactor;
    final selectedDate = activityNotifier.selectedDate;

    final currentData = activityNotifier.currentChartData;
    final previousData = activityNotifier.previousChartData;
    final nextData = activityNotifier.nextChartData;

    final entries = activityNotifier.currentWordEntries;

    return _buildNestedScrollView(
      header: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_left),
                onPressed: _isInOrBeforeStartMonth(selectedDate)
                    ? null
                    : () {
                        activityNotifier.selectedDate = _getOneMonthAgo(
                          selectedDate,
                        );
                      },
              ),
              Expanded(
                child: Text(
                  l10n.dateFormatForMonthlyChart(selectedDate),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_right),
                onPressed: _isInOrAfterThisMonth(selectedDate)
                    ? null
                    : () {
                        activityNotifier.selectedDate = _getOneMonthLater(
                          selectedDate,
                        );
                      },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.abc),
              Text(l10n.wordCount(activityNotifier.currentCount)),
            ],
          ),
          MonthlyChartView(
            key: UniqueKey(),
            controller: _monthlyChartController,
            currentData: currentData,
            previousData: previousData,
            nextData: nextData,
            startWeekDay: _getStartDayOfMonth(selectedDate).weekday - 1,
            circleColor: Theme.of(context).colorScheme.tertiary,
            textColor: Theme.of(context).colorScheme.onSurface,
            fontSize: 12.0 * fontSizeFactor,
            onSwipeLeft: _isInOrAfterThisMonth(selectedDate)
                ? null
                : () {
                    activityNotifier.selectedDate = _getOneMonthLater(
                      selectedDate,
                    );
                  },
            onSwipeRight: _isInOrBeforeStartMonth(selectedDate)
                ? null
                : () {
                    activityNotifier.selectedDate = _getOneMonthAgo(
                      selectedDate,
                    );
                  },
            onDailyViewSelected: (int index) {
              final startOffset = _getStartDayOfMonth(selectedDate).weekday - 1;
              final tappedDate = DateTime(
                selectedDate.year,
                selectedDate.month,
                index - startOffset + 1,
              );

              if (!_isInSameMonth(tappedDate, selectedDate) ||
                  _isNotInRange(tappedDate)) {
                return;
              }

              activityNotifier.selectedDate = tappedDate;
              activityNotifier.viewMode = ActivityViewMode.daily;
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
        ],
      ),
      keyString: 'Monthly_$selectedDate',
      entries: entries,
      contentsNotifier: contentsNotifier,
      viewedContents: viewedContents,
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
