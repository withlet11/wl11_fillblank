// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  ActivityNotifier() {
    fetchLog();
  }

  bool get isLoading => _isLoading;

  ActivityViewMode get viewMode => _viewMode;

  set viewMode(ActivityViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  List<Map<String, dynamic>> get wordLog => _wordLog;

  Future<void> fetchLog() async {
    _isLoading = true;
    notifyListeners();

    final log = await _db.getAllEntries();
    _wordLog = List<Map<String, dynamic>>.from(log);

    _isLoading = false;
    notifyListeners();
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

    notifyListeners();
  }

  List<Map<String, dynamic>> extractLogForDuration(
    DateTime date,
    int duration,
  ) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(Duration(days: duration));
    return _wordLog.where((log) {
      final logDate = DateTime.parse(log[_keyTimestamp] as String);
      return logDate.isAfter(startOfDay) && logDate.isBefore(endOfDay);
    }).toList();
  }

  List<MapEntry<String, int>> getWordCountsForDuration(
    DateTime date,
    int duration,
  ) {
    final studyLog = extractLogForDuration(date, duration);
    final result = <String, int>{};
    for (var log in studyLog) {
      final word = log[_keyWord] as String;
      result[word] = (result[word] ?? 0) + 1;
    }
    List<MapEntry<String, int>> temp = result.entries.toList();
    temp.sort((a, b) => b.value.compareTo(a.value));
    return temp;
  }

  int getDailyWordCount(DateTime date) => extractLogForDuration(date, 1).length;

  int getWeeklyWordCount(DateTime date) =>
      extractLogForDuration(date, 7).length;

  int getMonthlyWordCount(DateTime date) => extractLogForDuration(
    DateTime(date.year, date.month, 1),
    DateTime(date.year, date.month + 1, 0).day,
  ).length;

  List<int> getHalfHourlyCountsPerDay(DateTime date) {
    final studyLog = extractLogForDuration(date, 1);
    final result = List<int>.filled(48, 0);
    for (var log in studyLog) {
      final logDate = DateTime.parse(log[_keyTimestamp] as String);
      final hour = logDate.hour;
      final minute = logDate.minute;
      result[hour * 2 + (minute >= 30 ? 1 : 0)] += 1;
    }
    return result;
  }

  List<int> getDailyCountsPerWeek(DateTime date) {
    final studyLog = extractLogForDuration(date, 7);
    final result = List<int>.filled(7, 0);
    for (var log in studyLog) {
      final logDate = DateTime.parse(log[_keyTimestamp] as String);
      final weekday = logDate.weekday - 1;
      result[weekday] += 1;
    }
    return result;
  }

  List<int> getDailyCountsPerMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final duration = DateTime(date.year, date.month + 1, 0).day;

    final studyLog = extractLogForDuration(firstDay, duration);
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
        for (var entry in entries) {
          final elem = entry as Map<String, dynamic>;
          String? word = elem[_keyWord];
          String? timestamp = elem[_keyTimestamp];
          String? linkId = elem[_keyLinkId];
          if (word != null && timestamp != null && !listWords.contains(word)) {
            addWord(word, timestamp: timestamp, linkId: linkId ?? '');
            ++count;
          }
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
