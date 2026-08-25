// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readblank/l10n/app_localizations.dart';

import '../providers/activity_notifier.dart';
import '../providers/app_preferences_notifier.dart';
import '../views/daily_chart_view.dart';
import '../views/monthly_chart_view.dart';
import '../views/weekly_chart_view.dart';

class ActivityPage extends StatefulWidget {
  final String title;

  const ActivityPage({super.key, required this.title});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  static final DateTime _startDate = DateTime(2026, 1, 1);
  final DailyChartViewController _dailyChartController =
      DailyChartViewController();
  final WeeklyChartViewController _weeklyChartController =
      WeeklyChartViewController();
  final MonthlyChartViewController _monthlyChartController =
      MonthlyChartViewController();

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityNotifier>(
      builder: (context, notifier, child) {
        if (notifier.isLoading &&
            notifier.wordLog.isEmpty &&
            notifier.currentChartData.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final view = notifier.viewMode == ActivityViewMode.daily
            ? _buildDailyView(notifier)
            : notifier.viewMode == ActivityViewMode.weekly
            ? _buildWeeklyView(notifier)
            : _buildMonthlyView(notifier);

        return Stack(
          children: [
            view,
            if (notifier.isLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        );
      },
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

  Widget _buildDailyView(ActivityNotifier notifier) {
    final l10n = AppLocalizations.of(context)!;
    final fontSizeFactor = context
        .watch<AppPreferencesNotifier>()
        .fontSizeFactor;
    final selectedDate = notifier.selectedDate;

    if (_isBeforeStartDate(selectedDate)) {
      notifier.selectedDate = _startDate;
    } else if (_isAfterToday(selectedDate)) {
      notifier.selectedDate = today;
    }

    final currentData = notifier.currentChartData;
    final previousData = notifier.previousChartData;
    final nextData = notifier.nextChartData;

    final entries = notifier.currentWordCounts;

    return Column(
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_left),
                  onPressed: _isOnOrBeforeStartDate(selectedDate)
                      ? null
                      : () {
                          notifier.selectedDate = _getOneDayAgo(selectedDate);
                        },
                ),
                Text(
                  l10n.dateFormatForDailyChart(selectedDate),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_right),
                  onPressed: _isOnOrAfterToday(selectedDate)
                      ? null
                      : () {
                          notifier.selectedDate = _getOneDayLater(selectedDate);
                        },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.abc),
                Text(l10n.wordCount(notifier.currentCount)),
              ],
            ),
            DailyChartView(
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
                      notifier.selectedDate = _getOneDayLater(selectedDate);
                    },
              onSwipeRight: _isOnOrBeforeStartDate(selectedDate)
                  ? null
                  : () {
                      notifier.selectedDate = _getOneDayAgo(selectedDate);
                    },
            ),
            SizedBox(height: 16),
            Divider(height: 1),
            Text(
              'Read Words',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                title: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  entry.value.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            },
            separatorBuilder: (context, index) {
              return const Divider(height: 1, thickness: 1);
            },
          ),
        ),
      ],
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

  Widget _buildWeeklyView(ActivityNotifier notifier) {
    final l10n = AppLocalizations.of(context)!;
    final fontSizeFactor = context
        .watch<AppPreferencesNotifier>()
        .fontSizeFactor;
    final selectedDate = notifier.selectedDate;

    if (_isBeforeStartWeek(selectedDate)) {
      notifier.selectedDate = _startDate;
    } else if (_isAfterThisWeek(selectedDate)) {
      notifier.selectedDate = today;
    }

    final currentData = notifier.currentChartData;
    final previousData = notifier.previousChartData;
    final nextData = notifier.nextChartData;

    final entries = notifier.currentWordCounts;

    return Column(
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_left),
                  onPressed: _isInOrBeforeStartWeek(selectedDate)
                      ? null
                      : () {
                          notifier.selectedDate = _getSevenDaysAgo(
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
                  icon: Icon(Icons.keyboard_arrow_right),
                  onPressed: _isInOrAfterThisWeek(selectedDate)
                      ? null
                      : () {
                          notifier.selectedDate = _getSevenDaysLater(
                            selectedDate,
                          );
                        },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.abc),
                Text(l10n.wordCount(notifier.currentCount)),
              ],
            ),
            WeeklyChartView(
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
                      notifier.selectedDate = _getSevenDaysLater(selectedDate);
                    },
              onSwipeRight: _isInOrBeforeStartWeek(selectedDate)
                  ? null
                  : () {
                      notifier.selectedDate = _getSevenDaysAgo(selectedDate);
                    },
              onDailyViewSelected: (int index) {
                final tappedDate = _getStartDayOfWeek(
                  selectedDate,
                ).add(Duration(days: index));

                if (_isNotInRange(tappedDate)) return;

                notifier.selectedDate = tappedDate;
                notifier.viewMode = ActivityViewMode.daily;
              },
            ),
            SizedBox(height: 16),
            Divider(height: 1),
            Text(
              'Read Words',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                title: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  entry.value.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            },
            separatorBuilder: (context, index) {
              return const Divider(height: 1, thickness: 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyView(ActivityNotifier notifier) {
    final l10n = AppLocalizations.of(context)!;
    final fontSizeFactor = context
        .watch<AppPreferencesNotifier>()
        .fontSizeFactor;
    final selectedDate = notifier.selectedDate;

    final currentData = notifier.currentChartData;
    final previousData = notifier.previousChartData;
    final nextData = notifier.nextChartData;

    final entries = notifier.currentWordCounts;

    return Column(
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_left),
                  onPressed: _isInOrBeforeStartMonth(selectedDate)
                      ? null
                      : () {
                          notifier.selectedDate = _getOneMonthAgo(selectedDate);
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
                  icon: Icon(Icons.keyboard_arrow_right),
                  onPressed: _isInOrAfterThisMonth(selectedDate)
                      ? null
                      : () {
                          notifier.selectedDate = _getOneMonthLater(
                            selectedDate,
                          );
                        },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.abc),
                Text(l10n.wordCount(notifier.currentCount)),
              ],
            ),
            MonthlyChartView(
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
                      notifier.selectedDate = _getOneMonthLater(selectedDate);
                    },
              onSwipeRight: _isInOrBeforeStartMonth(selectedDate)
                  ? null
                  : () {
                      notifier.selectedDate = _getOneMonthAgo(selectedDate);
                    },
              onDailyViewSelected: (int index) {
                final startOffset =
                    _getStartDayOfMonth(selectedDate).weekday - 1;
                final tappedDate = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  index - startOffset + 1,
                );

                if (!_isInSameMonth(tappedDate, selectedDate) ||
                    _isNotInRange(tappedDate)) {
                  return;
                }

                notifier.selectedDate = tappedDate;
                notifier.viewMode = ActivityViewMode.daily;
              },
            ),
            SizedBox(height: 16),
            Divider(height: 1),
            Text(
              'Read Words',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                title: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  entry.value.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            },
            separatorBuilder: (context, index) {
              return const Divider(height: 1, thickness: 1);
            },
          ),
        ),
      ],
    );
  }
}
