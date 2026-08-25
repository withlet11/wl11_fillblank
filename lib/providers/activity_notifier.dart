// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

enum ActivityViewMode { daily, weekly, monthly }

class ActivityNotifier extends ChangeNotifier {
  static const String _appId = 'io.github.withlet11.readblank';
  static const String _keyActivity = 'activity';
  static const String _keyAppId = 'app_id';
  static const String _keyTarget = 'target';
  static const String _keySchemaVersion = 'schema_version';
  static const String _keyBackupAt = 'backup_at';
  static const String _keyRecords = 'records';
  static const String _keyId = 'id';
  static const String _keyWord = 'word';
  static const String _keyTimestamp = 'timestamp';
  static const String _keyLinkId = 'link_id';

  bool _isLoading = false;

  // For database operations
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _wordLog = List.empty(growable: true);
  ActivityViewMode _viewMode = ActivityViewMode.daily;

  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  List<int> _currentChartData = List<int>.filled(48, 0);
  List<int> _previousChartData = List<int>.filled(48, 0);
  List<int> _nextChartData = List<int>.filled(48, 0);
  List<MapEntry<String, int>> _currentWordCounts = [];
  List<MapEntry<String, int>> _previousWordCounts = [];
  List<MapEntry<String, int>> _nextWordCounts = [];
  int _currentCount = 0;

  ActivityViewMode? _lastFetchedMode;
  int _refreshId = 0;

  // Cache
  final Map<String, List<int>> _chartCache = {};
  final Map<String, List<MapEntry<String, int>>> _wordCountsCache = {};
  final Map<String, int> _totalCountCache = {};

  ActivityNotifier() {
    _initSkeletons();
    refreshData();
  }

  void _initSkeletons() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _currentChartData = _getSkeleton(ActivityViewMode.daily, today);
    _previousChartData = _getSkeleton(
      ActivityViewMode.daily,
      _getPreviousPeriodDate(ActivityViewMode.daily, today),
    );
    _nextChartData = _getSkeleton(
      ActivityViewMode.daily,
      _getNextPeriodDate(ActivityViewMode.daily, today),
    );
  }

  bool get isLoading => _isLoading;

  ActivityViewMode get viewMode => _viewMode;

  set viewMode(ActivityViewMode mode) {
    if (_viewMode == mode) return;
    final oldMode = _viewMode;
    _viewMode = mode;
    refreshData(oldMode: oldMode);
  }

  DateTime get selectedDate => _selectedDate;

  set selectedDate(DateTime date) {
    final newDate = DateTime(date.year, date.month, date.day);
    if (_selectedDate.isAtSameMomentAs(newDate)) return;
    final oldDate = _selectedDate;
    _selectedDate = newDate;
    refreshData(oldDate: oldDate);
  }

  List<int> get currentChartData => _currentChartData;

  List<int> get previousChartData => _previousChartData;

  List<int> get nextChartData => _nextChartData;

  List<MapEntry<String, int>> get currentWordCounts => _currentWordCounts;

  int get currentCount => _currentCount;

  List<Map<String, dynamic>> get wordLog => _wordLog;

  List<int> _getSkeleton(ActivityViewMode mode, DateTime date) {
    switch (mode) {
      case ActivityViewMode.daily:
        return List<int>.filled(48, 0);
      case ActivityViewMode.weekly:
        return List<int>.filled(7, 0);
      case ActivityViewMode.monthly:
        return List<int>.filled(DateTime(date.year, date.month + 1, 0).day, 0);
    }
  }

  String _getCacheKey(ActivityViewMode mode, DateTime date) {
    switch (mode) {
      case ActivityViewMode.daily:
        return 'daily_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case ActivityViewMode.weekly:
        final firstDay = date.subtract(Duration(days: date.weekday - 1));
        return 'weekly_${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}';
      case ActivityViewMode.monthly:
        return 'monthly_${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
  }

  bool _isWordCountsEqual(
    List<MapEntry<String, int>> a,
    List<MapEntry<String, int>> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key || a[i].value != b[i].value) return false;
    }
    return true;
  }

  Future<void> refreshData({
    DateTime? oldDate,
    ActivityViewMode? oldMode,
  }) async {
    final currentRefreshId = ++_refreshId;
    final key = _getCacheKey(_viewMode, _selectedDate);

    bool promoted = false;
    if (oldMode == _viewMode &&
        oldDate != null &&
        _lastFetchedMode == _viewMode) {
      if (_selectedDate.isAtSameMomentAs(
        _getPreviousPeriodDate(_viewMode, oldDate),
      )) {
        // Moved to previous
        _nextChartData = _currentChartData;
        _nextWordCounts = _currentWordCounts;
        _currentChartData = _previousChartData;
        _currentWordCounts = _previousWordCounts;
        final prevDate = _getPreviousPeriodDate(_viewMode, _selectedDate);
        final prevKey = _getCacheKey(_viewMode, prevDate);
        _previousChartData =
            _chartCache[prevKey] ?? _getSkeleton(_viewMode, prevDate);
        _previousWordCounts = _wordCountsCache[prevKey] ?? [];
        promoted = true;
      } else if (_selectedDate.isAtSameMomentAs(
        _getNextPeriodDate(_viewMode, oldDate),
      )) {
        // Moved to next
        _previousChartData = _currentChartData;
        _previousWordCounts = _currentWordCounts;
        _currentChartData = _nextChartData;
        _currentWordCounts = _nextWordCounts;
        final nextDate = _getNextPeriodDate(_viewMode, _selectedDate);
        final nextKey = _getCacheKey(_viewMode, nextDate);
        _nextChartData =
            _chartCache[nextKey] ?? _getSkeleton(_viewMode, nextDate);
        _nextWordCounts = _wordCountsCache[nextKey] ?? [];
        promoted = true;
      }
    }

    final cachedChart = _chartCache[key];
    final cachedWordCounts = _wordCountsCache[key];
    final isCached = cachedChart != null && cachedWordCounts != null;

    if (promoted) {
      _currentCount = _currentWordCounts.fold(
        0,
        (sum, entry) => sum + entry.value,
      );
      _isLoading = false;
    } else if (isCached) {
      _currentChartData = cachedChart;
      _currentWordCounts = cachedWordCounts;
      _currentCount = _currentWordCounts.fold(
        0,
        (sum, entry) => sum + entry.value,
      );
      final prevDate = _getPreviousPeriodDate(_viewMode, _selectedDate);
      final nextDate = _getNextPeriodDate(_viewMode, _selectedDate);
      final prevKey = _getCacheKey(_viewMode, prevDate);
      final nextKey = _getCacheKey(_viewMode, nextDate);
      _previousChartData =
          _chartCache[prevKey] ?? _getSkeleton(_viewMode, prevDate);
      _nextChartData =
          _chartCache[nextKey] ?? _getSkeleton(_viewMode, nextDate);
      _isLoading = false;
    } else {
      _currentChartData = _getSkeleton(_viewMode, _selectedDate);
      _currentWordCounts = [];
      _currentCount = 0;
      final prevDate = _getPreviousPeriodDate(_viewMode, _selectedDate);
      final nextDate = _getNextPeriodDate(_viewMode, _selectedDate);
      final prevKey = _getCacheKey(_viewMode, prevDate);
      final nextKey = _getCacheKey(_viewMode, nextDate);
      _previousChartData =
          _chartCache[prevKey] ?? _getSkeleton(_viewMode, prevDate);
      _nextChartData =
          _chartCache[nextKey] ?? _getSkeleton(_viewMode, nextDate);
      _previousWordCounts = _wordCountsCache[prevKey] ?? [];
      _nextWordCounts = _wordCountsCache[nextKey] ?? [];
      _isLoading = true;
    }

    // Always notify once synchronously if properties changed to update labels/view
    notifyListeners();

    try {
      final prevDate = _getPreviousPeriodDate(_viewMode, _selectedDate);
      final nextDate = _getNextPeriodDate(_viewMode, _selectedDate);

      final results = await Future.wait([
        _getChartData(_viewMode, _selectedDate),
        _getChartData(_viewMode, prevDate),
        _getChartData(_viewMode, nextDate),
        _getWordCounts(_viewMode, _selectedDate),
        _getWordCounts(_viewMode, prevDate),
        _getWordCounts(_viewMode, nextDate),
      ]);

      if (currentRefreshId != _refreshId) return;

      final newCurrentChart = results[0] as List<int>;
      final newPrevChart = results[1] as List<int>;
      final newNextChart = results[2] as List<int>;
      final newWordCounts = results[3] as List<MapEntry<String, int>>;
      final newPrevWordCounts = results[4] as List<MapEntry<String, int>>;
      final newNextWordCounts = results[5] as List<MapEntry<String, int>>;

      bool dataUpdated = false;
      if (!listEquals(_currentChartData, newCurrentChart)) {
        _currentChartData = newCurrentChart;
        dataUpdated = true;
      }
      if (!listEquals(_previousChartData, newPrevChart)) {
        _previousChartData = newPrevChart;
        dataUpdated = true;
      }
      if (!listEquals(_nextChartData, newNextChart)) {
        _nextChartData = newNextChart;
        dataUpdated = true;
      }
      if (!_isWordCountsEqual(_currentWordCounts, newWordCounts)) {
        _currentWordCounts = newWordCounts;
        _currentCount = _currentWordCounts.fold(
          0,
          (sum, entry) => sum + entry.value,
        );
        dataUpdated = true;
      }
      if (!_isWordCountsEqual(_previousWordCounts, newPrevWordCounts)) {
        _previousWordCounts = newPrevWordCounts;
        dataUpdated = true;
      }
      if (!_isWordCountsEqual(_nextWordCounts, newNextWordCounts)) {
        _nextWordCounts = newNextWordCounts;
        dataUpdated = true;
      }

      _lastFetchedMode = _viewMode;

      if (dataUpdated || _isLoading) {
        _isLoading = false;
        notifyListeners();
      }

      // Trigger prefetch in background
      _prefetch(_selectedDate);
    } catch (e) {
      if (currentRefreshId == _refreshId && _isLoading) {
        _isLoading = false;
        notifyListeners();
      }
      rethrow;
    }
  }

  DateTime _getPreviousPeriodDate(ActivityViewMode mode, DateTime date) {
    switch (mode) {
      case ActivityViewMode.daily:
        return date.subtract(const Duration(days: 1));
      case ActivityViewMode.weekly:
        return date.subtract(const Duration(days: 7));
      case ActivityViewMode.monthly:
        return DateTime(date.year, date.month - 1, 1);
    }
  }

  DateTime _getNextPeriodDate(ActivityViewMode mode, DateTime date) {
    switch (mode) {
      case ActivityViewMode.daily:
        return date.add(const Duration(days: 1));
      case ActivityViewMode.weekly:
        return date.add(const Duration(days: 7));
      case ActivityViewMode.monthly:
        return DateTime(date.year, date.month + 1, 1);
    }
  }

  Future<List<int>> _getChartData(ActivityViewMode mode, DateTime date) async {
    final key = _getCacheKey(mode, date);
    if (_chartCache.containsKey(key)) return _chartCache[key]!;

    List<int> data;
    switch (mode) {
      case ActivityViewMode.daily:
        data = await _getHalfHourlyCountsPerDay(date);
        break;
      case ActivityViewMode.weekly:
        final firstDay = date.subtract(Duration(days: date.weekday - 1));
        data = await _getDailyCountsPerWeek(firstDay);
        break;
      case ActivityViewMode.monthly:
        data = await _getDailyCountsPerMonth(date);
        break;
    }
    _chartCache[key] = data;
    return data;
  }

  Future<List<MapEntry<String, int>>> _getWordCounts(
    ActivityViewMode mode,
    DateTime date,
  ) async {
    final key = _getCacheKey(mode, date);
    if (_wordCountsCache.containsKey(key)) return _wordCountsCache[key]!;

    List<MapEntry<String, int>> data;
    switch (mode) {
      case ActivityViewMode.daily:
        data = await _getWordCountsForDuration(date, 1);
        break;
      case ActivityViewMode.weekly:
        final firstDay = date.subtract(Duration(days: date.weekday - 1));
        data = await _getWordCountsForDuration(firstDay, 7);
        break;
      case ActivityViewMode.monthly:
        final firstDay = DateTime(date.year, date.month, 1);
        final lastDay = DateTime(date.year, date.month + 1, 0);
        data = await _getWordCountsForDuration(firstDay, lastDay.day);
        break;
    }
    _wordCountsCache[key] = data;
    return data;
  }

  void _prefetch(DateTime date) async {
    // Cross-mode prefetch
    final modesToFetch = ActivityViewMode.values.where((m) => m != _viewMode);
    for (final mode in modesToFetch) {
      _getChartData(mode, date);
      _getWordCounts(mode, date);
    }

    // Neighbors of neighbors (e.g. +/- 2 days)
    final prevPrevDate = _getPreviousPeriodDate(
      _viewMode,
      _getPreviousPeriodDate(_viewMode, date),
    );
    final nextNextDate = _getNextPeriodDate(
      _viewMode,
      _getNextPeriodDate(_viewMode, date),
    );
    _getChartData(_viewMode, prevPrevDate);
    _getChartData(_viewMode, nextNextDate);
    _getWordCounts(_viewMode, prevPrevDate);
    _getWordCounts(_viewMode, nextNextDate);
  }

  void _invalidateCacheForDate(DateTime date) {
    final dailyKey = _getCacheKey(ActivityViewMode.daily, date);
    final weeklyKey = _getCacheKey(ActivityViewMode.weekly, date);
    final monthlyKey = _getCacheKey(ActivityViewMode.monthly, date);

    _chartCache.remove(dailyKey);
    _chartCache.remove(weeklyKey);
    _chartCache.remove(monthlyKey);

    _wordCountsCache.remove(dailyKey);
    _wordCountsCache.remove(weeklyKey);
    _wordCountsCache.remove(monthlyKey);

    _totalCountCache.remove(dailyKey);
    _totalCountCache.remove(weeklyKey);
    _totalCountCache.remove(monthlyKey);
  }

  Future<void> fetchLog() async {
    _isLoading = true;
    notifyListeners();

    _chartCache.clear();
    _wordCountsCache.clear();
    _totalCountCache.clear();

    final log = await _db.getAllEntries();
    _wordLog = List<Map<String, dynamic>>.from(log);

    await refreshData();
  }

  Future<void> addWord(
    String word, {
    String? timestamp,
    required String linkId,
  }) async {
    timestamp = timestamp ?? DateTime.now().toIso8601String();
    await _db.addEntry(word, timestamp: timestamp, linkId: linkId);

    _wordLog.insert(0, {
      _keyWord: word,
      _keyTimestamp: timestamp,
      _keyLinkId: linkId,
    });
    if (_wordLog.length > 10000) _wordLog.removeLast();

    _invalidateCacheForDate(DateTime.parse(timestamp));
    await refreshData();
  }

  Future<List<MapEntry<String, int>>> _getWordCountsForDuration(
    DateTime date,
    int duration,
  ) async {
    final log = await _db.getSummaryList(date, duration);
    return log.map((e) {
      return MapEntry(e[_keyWord] as String, e['count'] as int);
    }).toList();
  }

  Future<List<int>> _getHalfHourlyCountsPerDay(DateTime date) async {
    final studyLog = await _db.getEntries(date, 1);
    final result = List<int>.filled(48, 0);
    for (var log in studyLog) {
      final logDate = DateTime.parse(log[_keyTimestamp] as String);
      final hour = logDate.hour;
      final minute = logDate.minute;
      result[hour * 2 + (minute >= 30 ? 1 : 0)] += 1;
    }
    return result;
  }

  Future<List<int>> _getDailyCountsPerWeek(DateTime date) async {
    final studyLog = await _db.getEntries(date, 7);
    final result = List<int>.filled(7, 0);
    for (var log in studyLog) {
      final logDate = DateTime.parse(log[_keyTimestamp] as String);
      final weekday = logDate
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;
      if (weekday >= 0 && weekday < 7) {
        result[weekday] += 1;
      }
    }
    return result;
  }

  Future<List<int>> _getDailyCountsPerMonth(DateTime date) async {
    final firstDay = DateTime(date.year, date.month, 1);
    final duration = DateTime(date.year, date.month + 1, 0).day;

    final studyLog = await _db.getEntries(firstDay, duration);
    final result = List<int>.filled(duration, 0);
    for (var log in studyLog) {
      final logDate = DateTime.parse(log[_keyTimestamp] as String);
      final day = logDate.day - 1;
      result[day] += 1;
    }
    return result;
  }

  Future<String?> exportActivity() async {
    final log = await _db.getAllEntries();
    final records = log.map((row) {
      final entry = Map<String, Object?>.from(row);
      entry.remove(_keyId); // unnecessary field
      return entry;
    }).toList();
    final timestamp = DateTime.now().toIso8601String();
    final backupData = {
      _keyAppId: _appId,
      _keyTarget: _keyActivity,
      _keySchemaVersion: 1,
      _keyBackupAt: timestamp,
      _keyRecords: records,
    };

    final jsonData = jsonEncode(backupData);

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export activity',
      fileName: 'Activity-backup-${timestamp.substring(0, 10)}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(jsonData),
    );

    return path;
  }

  Future<int?> importActivity(String path) async {
    final file = File(path);
    if (await file.exists()) {
      String jsonData = await file.readAsString();
      Map<String, dynamic> data = jsonDecode(jsonData);

      if (data[_keyAppId] != _appId ||
          data[_keyTarget] != _keyActivity ||
          data[_keySchemaVersion] != 1) {
        return null;
      }

      List<Object?> entries = data[_keyRecords] as List<dynamic>;
      int count = 0;

      if (entries.isNotEmpty) {
        final list = await _db.getAllEntries();
        final listWords = list.map((e) => e[_keyWord]).toList();
        final newEntries = <Map<String, dynamic>>[];

        for (var entry in entries) {
          final elem = entry as Map<String, dynamic>;
          String? word = elem[_keyWord];
          String? timestamp = elem[_keyTimestamp];
          String? linkId = elem[_keyLinkId];
          if (word != null && timestamp != null && !listWords.contains(word)) {
            newEntries.add({
              _keyWord: word,
              _keyTimestamp: timestamp,
              _keyLinkId: linkId ?? '',
            });
            _invalidateCacheForDate(DateTime.parse(timestamp));
            ++count;
          }
        }

        if (newEntries.isNotEmpty) {
          await _db.batchInsert(newEntries);
          await fetchLog(); // Refreshes everything once
        }
      }

      return count;
    } else {
      throw Exception("File not found: $path");
    }
  }
}

class DatabaseHelper {
  static const String _dbName = 'fillblank.db';
  static const String _tableName = 'logs';
  static const String _keyWord = 'word';
  static const String _keyTimestamp = 'timestamp';
  static const String _keyLinkId = 'link_id';

  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE logs ADD COLUMN link_id TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        link_id TEXT NOT NULL
      )
    ''');
  }

  Future<void> addEntry(
    String word, {
    required String timestamp,
    required String linkId,
  }) async {
    final db = await database;
    await db.insert(_tableName, {
      _keyWord: word,
      _keyTimestamp: timestamp,
      _keyLinkId: linkId,
    });

    // Optional: Auto-trim database size
    await db.execute(
      'DELETE FROM logs WHERE id <= (SELECT id FROM logs ORDER BY id DESC LIMIT 1 OFFSET 10000)',
    );
  }

  Future<void> batchInsert(List<Map<String, dynamic>> entries) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var entry in entries) {
        await txn.insert(_tableName, entry);
      }
    });

    // Trim once at the end
    await db.execute(
      'DELETE FROM logs WHERE id <= (SELECT id FROM logs ORDER BY id DESC LIMIT 1 OFFSET 10000)',
    );
  }

  Future<void> clearAllEntries() async {
    final db = await database;
    await db.delete(_tableName);
  }

  Future<List<Map<String, dynamic>>> getAllEntries() async {
    final db = await database;
    return await db.query(_tableName, orderBy: 'id DESC', limit: 10000);
  }

  Future<List<Map<String, dynamic>>> getEntries(
    DateTime date,
    int duration,
  ) async {
    final db = await database;
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(days: duration)).toIso8601String();
    return await db.query(
      _tableName,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getWholeSummaryList() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT LOWER(word) as word, COUNT(*) as count 
      FROM logs 
      GROUP BY LOWER(word) 
      ORDER BY count DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getSummaryList(
    DateTime date,
    int duration,
  ) async {
    final db = await database;
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(days: duration)).toIso8601String();
    return await db.rawQuery(
      '''
      SELECT LOWER(word) as word, COUNT(*) as count 
      FROM logs 
      WHERE timestamp >= ? AND timestamp < ?
      GROUP BY LOWER(word) 
      ORDER BY count DESC
    ''',
      [startOfDay, endOfDay],
    );
  }
}
