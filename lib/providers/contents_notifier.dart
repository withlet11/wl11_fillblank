// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

class CachedContent {
  final String? title;
  final String? originalTitle;
  final List<String> paragraphs;
  final String? locale;
  final int size;
  final bool isFavorite;

  CachedContent({
    required this.title,
    required this.originalTitle,
    required this.paragraphs,
    required this.locale,
    required this.size,
    required this.isFavorite,
  });
}

class ContentsNotifier extends ChangeNotifier {
  static const String _appId = 'io.github.withlet11.readblank';
  static const String _keyContents = 'contents';
  static const String _keyAppId = 'app_id';
  static const String _keyTarget = 'target';
  static const String _keySchemaVersion = 'schema_version';
  static const String _keyBackupAt = 'backup_at';
  static const String _keyRecords = 'records';
  static const String _keyUrl = 'url';
  static const String _keyLinkId = 'link_id';
  static const String _keyTitle = 'title';
  static const String _keyOriginalTitle = 'original_title';
  static const String _keyFileSize = 'file_size';
  static const String _keyLocale = 'locale';
  static const String _keyTimestamp = 'timestamp';
  static const String _keyLastViewedParagraphIndex =
      'last_viewed_paragraph_index';
  static const String _keyIsFavorite = 'isFavorite';

  // For storing and retrieving data from SharedPreferences
  final SharedPreferences sharedPrefs;

  // For fetching data from the web
  http.Client? _client;
  String? _data;
  String? _error;

  // For storing data
  List<Map<String, dynamic>> _linkList = [];
  final Map<String, CachedContent> _cachedContents = {};
  final List<String> _locales = [];

  // Other properties
  int _currentParagraphIndex = 0;
  bool isFavoritesOnly = false;
  String? targetLocale;

  ContentsNotifier(this.sharedPrefs) {
    _retrieveFromSharedPreferences();
  }

  // Link data handling
  void _retrieveFromSharedPreferences() {
    try {
      final linkListJson = sharedPrefs.getString(_keyContents);
      if (linkListJson != null) {
        final decoded = jsonDecode(linkListJson);
        if (decoded is List) {
          _linkList = List<Map<String, dynamic>>.from(decoded);
          _currentParagraphIndex =
              _selectedEntry?[_keyLastViewedParagraphIndex] ?? 0;
        }
        for (final entry in _linkList) {
          final locale = entry[_keyLocale]?.toLowerCase().replaceAll('-', '_');
          if (!_locales.contains(locale)) {
            _locales.add(locale ?? '');
          }
        }
      } else {
        _linkList = [];
      }
    } catch (e) {
      _linkList = [];
    }
  }

  Future<void> persist() async {
    notifyListeners();
    await sharedPrefs.setString(_keyContents, linkListJsonData);
  }

  List<Map<String, dynamic>> get linkList => _linkList;

  List<Map<String, dynamic>> get sortedLinkList {
    return (targetLocale != null
            ? _linkList.where(_functionForFilteringWithFavoritesAndLocale)
            : _linkList.where(_functionForFilteringWithFavorites))
        .toList();
  }

  bool _functionForFilteringWithFavoritesAndLocale(Map<String, dynamic> e) {
    return (!isFavoritesOnly || (e[_keyIsFavorite] ?? false)) &&
        (e[_keyLocale]?.toLowerCase().replaceAll('-', '_') == targetLocale);
  }

  bool _functionForFilteringWithFavorites(Map<String, dynamic> e) {
    return !isFavoritesOnly || (e[_keyIsFavorite] ?? false);
  }

  List<String> get locales => _locales;

  String get linkListJsonData => jsonEncode(_linkList);

  bool contains(String entry) {
    return _linkList.any((e) => e[_keyUrl] == entry);
  }

  // Modify link list
  Future<void> add(String url) async {
    try {
      if (!_isCached(url)) {
        _client = http.Client();
        _error = null;
        notifyListeners();
        await _fetchContent(url);
      }
      _currentParagraphIndex = 0;
      final now = DateTime.now();
      _linkList.insert(0, {
        _keyUrl: url,
        _keyLinkId: _intToBase64(now.microsecondsSinceEpoch),
        _keyTitle: _getCachedTitle(url),
        _keyOriginalTitle: _getCachedOriginalTitle(url),
        _keyFileSize: getCachedContentSize(url),
        _keyLocale: getCachedContentLocale(url),
        _keyTimestamp: now.toIso8601String(),
        _keyLastViewedParagraphIndex: _currentParagraphIndex,
        _keyIsFavorite: false,
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      _client = null;
      persist();
    }
  }

  Future<void> removeAt(int index) async {
    if (_linkList.length > 1) {
      if (index >= 0 && index < _linkList.length) {
        _linkList.removeAt(index);
        if (index == 0) {
          _currentParagraphIndex =
              _selectedEntry?[_keyLastViewedParagraphIndex] ?? 0;
        }
        persist();
      }
    }
  }

  Future<void> remove(String url) async {
    final index = _linkList.indexWhere((e) => e[_keyUrl] == url);
    removeAt(index);
  }

  Future<void> clearAll() async {
    _linkList = [];
    persist();
  }

  // Select page from list
  bool isSelected(String url) =>
      _linkList.isNotEmpty && _linkList.first[_keyUrl] == url;

  Future<void> select(String url) async {
    _error = null;
    final index = _linkList.indexWhere((e) => e[_keyUrl] == url);
    if (index > 0) {
      _linkList.first[_keyLastViewedParagraphIndex] = _currentParagraphIndex;
      final entry = _linkList[index];
      entry[_keyTimestamp] = DateTime.now().toIso8601String();
      _enrichEntry(entry, url);
      _linkList.removeAt(index);
      _linkList.insert(0, entry);
      _currentParagraphIndex = entry[_keyLastViewedParagraphIndex] ?? 0;
      persist();
    } else if (index != 0) {
      add(url);
    } else {
      notifyListeners();
    }
  }

  Map<String, dynamic>? get _selectedEntry {
    return _linkList.isEmpty ? null : _linkList.first;
  }

  void _enrichEntry(Map<String, dynamic> entry, String url) {
    // link_id: default to base64(timestamp) if missing
    if (entry[_keyLinkId] == null) {
      entry[_keyLinkId] = _intToBase64(
        DateTime.parse(entry[_keyTimestamp]).microsecondsSinceEpoch,
      );
    }

    // title: default to cached title if missing
    if (entry[_keyTitle] == null) {
      entry[_keyTitle] = _getCachedTitle(url);
    }

    // title: default to cached original title if missing
    if (entry[_keyOriginalTitle] == null) {
      entry[_keyOriginalTitle] = _getCachedOriginalTitle(url);
    }

    // file size: default to cached file size if missing
    if (entry[_keyFileSize] == null) {
      entry[_keyFileSize] = getCachedContentSize(url);
    }

    // locale: default to cached locale if missing
    if (entry[_keyLocale] == null) {
      entry[_keyLocale] = getCachedContentLocale(url);
    }

    // timestamp: default to current time if missing
    if (entry[_keyTimestamp] == null) {
      entry[_keyTimestamp] = DateTime.now().toIso8601String();
    }

    // last_viewed_paragraph_index: default to 0 if missing
    if (entry[_keyLastViewedParagraphIndex] == null) {
      entry[_keyLastViewedParagraphIndex] = 0;
    }

    // bookmarked: default to false if missing
    if (entry[_keyIsFavorite] == null) {
      entry[_keyIsFavorite] = false;
    }
  }

  String _intToBase64(int number) {
    final byteData = ByteData(8)..setInt64(0, number);
    final bytes = byteData.buffer.asUint8List();
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // Fetch and cache data from the web
  bool get isLoading => _client != null;

  String? get data => _data;

  String? get error => _error;

  void cancelLoading() {
    _client?.close();
    _client = null;
    notifyListeners();
  }

  Future<void> fetchCurrentContent() async {
    if (currentParagraphList != null || isLoading) return;

    try {
      _client = http.Client();
      _error = null;
      notifyListeners();
      await _fetchContent(currentUrl);
      _selectedEntry![_keyOriginalTitle] = _getCachedOriginalTitle(currentUrl);
      _selectedEntry![_keyFileSize] = getCachedContentSize(currentUrl);
      _selectedEntry![_keyLocale] = getCachedContentLocale(currentUrl);
    } catch (e) {
      _error = e.toString();
    } finally {
      _client = null;
      persist(); // instead of notifyListeners();
    }
  }

  Future<void> fetchContent(String url) async {
    if (isLoading) return;

    try {
      _client = http.Client();
      _error = null;
      notifyListeners();
      await _fetchContent(url);
      _selectedEntry![_keyOriginalTitle] = _getCachedOriginalTitle(url);
      _selectedEntry![_keyFileSize] = getCachedContentSize(url);
      _selectedEntry![_keyLocale] = getCachedContentLocale(url);
    } catch (e) {
      _error = e.toString();
    } finally {
      _client = null;
      persist(); // instead of notifyListeners();
    }
  }

  Future<void> _fetchContent(String url) async {
    if (_client == null) throw Exception('Client is null');

    final response = await _client!.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final document = parser.parse(response.body);
      final lang = document.documentElement?.attributes['lang'];
      final originalTitle = document.querySelector('title')?.text;
      final pElements = document.getElementsByTagName('p');
      final locale = lang?.toLowerCase().replaceAll('-', '_');
      final title = _cachedContents[url]?.title ?? originalTitle;
      print('set original title: $originalTitle');
      _cachedContents[url] = CachedContent(
        title: title,
        originalTitle: originalTitle,
        paragraphs: pElements
            .map((element) => element.text.trim())
            .where((text) => text.isNotEmpty)
            .toList(),
        locale: locale,
        size: pElements
            .map((element) => element.text.codeUnits.length)
            .reduce((a, b) => a + b),
        isFavorite: false,
      );
    } else {
      throw Exception('Failed to fetch a page');
    }
  }

  bool _isCached(String url) => _cachedContents.containsKey(url);

  List<String>? _getCachedParagraphList(String url) =>
      _cachedContents[url]?.paragraphs;

  String? _getCachedTitle(String url) => _cachedContents[url]?.title;

  String? _getCachedOriginalTitle(String url) =>
      _cachedContents[url]?.originalTitle;

  String getCachedContentSize(String url) {
    final size = _cachedContents[url]?.size;
    return size == null
        ? '? B'
        : size < 1000
        ? '$size B'
        : '${(size / 1024).round().toString()} KB';
  }

  String? getCachedContentLocale(String url) {
    return _cachedContents[url]?.locale?.toLowerCase().replaceAll('-', '_');
  }

  // Getters of current page properties
  String get currentUrl => _selectedEntry?[_keyUrl] ?? '';

  String get currentLinkId => _selectedEntry?[_keyLinkId];

  String get currentTimestamp {
    return _selectedEntry == null
        ? ''
        : DateFormat.yMd().add_jm().format(
            DateTime.parse(_selectedEntry![_keyTimestamp]),
          );
  }

  String get currentDomainName =>
      Uri.parse(currentUrl).host.replaceFirst('www.', '');

  String? get currentTitle => _selectedEntry?[_keyTitle];

  List<String>? get currentParagraphList => _getCachedParagraphList(currentUrl);

  bool get isFavorite => _selectedEntry?[_keyIsFavorite] ?? false;

  // Current paragraph
  String? get currentParagraph => currentParagraphList?[_currentParagraphIndex];

  int get currentParagraphIndex => _currentParagraphIndex;

  Future<void> setCurrentParagraphIndex(int index) async {
    if (_currentParagraphIndex != index) {
      _currentParagraphIndex = index;
      _linkList.first[_keyLastViewedParagraphIndex] = _currentParagraphIndex;
      persist();
    }
  }

  bool get isNotFirstParagraph => _currentParagraphIndex > 0;

  bool get isNotLastParagraph =>
      currentParagraphList != null &&
      _currentParagraphIndex != currentParagraphList!.length - 1;

  Future<void> movePreviousParagraph() async {
    if (isNotFirstParagraph) {
      _currentParagraphIndex--;
      _linkList.first[_keyLastViewedParagraphIndex] = _currentParagraphIndex;
      persist();
    }
  }

  Future<void> moveNextParagraph() async {
    if (isNotLastParagraph) {
      _currentParagraphIndex++;
      _linkList.first[_keyLastViewedParagraphIndex] = _currentParagraphIndex;
      persist();
    }
  }

  Future<void> moveToFirstParagraph() async {
    if (isNotFirstParagraph) {
      _currentParagraphIndex = 0;
      _linkList.first[_keyLastViewedParagraphIndex] = _currentParagraphIndex;
      persist();
    }
  }

  Future<void> moveToLastParagraph() async {
    if (isNotLastParagraph) {
      _currentParagraphIndex = currentParagraphList!.length - 1;
      _linkList.first[_keyLastViewedParagraphIndex] = _currentParagraphIndex;
      persist();
    }
  }

  Future<void> addLink(AppLocalizations l10n, BuildContext context) async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? copiedText = data?.text;
    if (copiedText != null && copiedText.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(copiedText));
        if (response.statusCode == 200) {
          final document = parser.parse(response.body);
          final pElements = document.getElementsByTagName('p');
          if (pElements.any((element) => element.text.trim().isNotEmpty)) {
            if (contains(copiedText)) {
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.alreadyExistsMessage),
                    content: Text(l10n.existingLinkOpenConfirmation),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.commonCancel),
                      ),
                      FilledButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          select(copiedText);
                        },
                        child: Text(l10n.commonOpen),
                      ),
                    ],
                  ),
                );
              }
            } else {
              add(copiedText);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.linkAdditionSuccessMessage),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          } else {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.noTextLabel),
                  content: Text(l10n.notContainsParagraphMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.commonOk),
                    ),
                  ],
                ),
              );
            }
          }
        } else {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.invalidUrlLabel),
                content: Text(l10n.urlCopyRequest),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonOk),
                  ),
                ],
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          final colorScheme = Theme.of(context).colorScheme;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: colorScheme.errorContainer,
              title: Row(
                children: [
                  Icon(Icons.error, color: colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Text(
                    l10n.errorLabel,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ],
              ),
              content: Text(e.toString(), maxLines: 5),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonOk),
                ),
              ],
            ),
          );
        }
      }
    } else {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.noCopiedUrlLabel),
            content: Text(l10n.urlCopyRequest),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<String?> exportContents() async {
    final linkIds = <String>{};
    final normalizedList = _linkList
        .map(_completeEntry)
        .where((e) => linkIds.add(e?[_keyLinkId] ?? ''))
        .toList();
    final timestamp = DateTime.now().toIso8601String();
    final data = {
      _keyAppId: _appId,
      _keyTarget: _keyContents,
      _keySchemaVersion: 1,
      _keyBackupAt: timestamp,
      _keyRecords: normalizedList,
    };

    final jsonData = jsonEncode(data);

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export contents',
      fileName: 'Contents-backup-${timestamp.substring(0, 10)}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(jsonData),
    );

    return path;
  }

  Map<String, dynamic>? _completeEntry(Map<String, dynamic> entry) {
    final normalizedEntry = <String, dynamic>{};
    final String? url = entry[_keyUrl];
    final String? linkId = entry[_keyLinkId];

    if (url == null || url.isEmpty || linkId == null || linkId.isEmpty) {
      return null;
    }

    normalizedEntry[_keyUrl] = url;
    normalizedEntry[_keyLinkId] = linkId;
    normalizedEntry[_keyTitle] = entry[_keyTitle] ?? _getCachedTitle(url);
    normalizedEntry[_keyOriginalTitle] =
        entry[_keyOriginalTitle] ?? _getCachedOriginalTitle(url);
    normalizedEntry[_keyFileSize] =
        entry[_keyFileSize] ?? getCachedContentSize(url);
    normalizedEntry[_keyLocale] =
        entry[_keyLocale] ?? getCachedContentLocale(url);
    normalizedEntry[_keyTimestamp] =
        entry[_keyTimestamp] ?? DateTime.now().toIso8601String();
    normalizedEntry[_keyLastViewedParagraphIndex] =
        entry[_keyLastViewedParagraphIndex] ?? 0;
    normalizedEntry[_keyIsFavorite] = entry[_keyIsFavorite] ?? false;

    return normalizedEntry;
  }

  Future<int?> importContents(String path) async {
    final file = File(path);
    if (await file.exists()) {
      String jsonData = await file.readAsString();
      Map<String, dynamic> data = jsonDecode(jsonData);

      if (data[_keyAppId] != _appId ||
          data[_keyTarget] != _keyContents ||
          data[_keySchemaVersion] != 1) {
        return null;
      }

      final List<dynamic> list = data[_keyRecords] as List<dynamic>;
      int count = 0;

      if (list.isNotEmpty) {
        for (var value in list) {
          final entry = value as Map<String, dynamic>;
          final url = entry[_keyUrl];
          final linkId = entry[_keyLinkId];
          if (url != null && linkId != null) {
            if (!contains(url)) {
              _linkList.insert(0, _cleanEntry(entry, url, linkId));
              ++count;
            }
          }
        }
      }

      return count;
    } else {
      throw Exception("File not found: $path");
    }
  }

  Map<String, dynamic> _cleanEntry(
    Map<String, dynamic> entry,
    String url,
    String linkId,
  ) {
    return {
      _keyUrl: url,
      _keyLinkId: linkId,
      _keyTitle: entry[_keyTitle],
      _keyOriginalTitle: entry[_keyOriginalTitle],
      _keyFileSize: entry[_keyFileSize] ?? '? B',
      _keyLocale: entry[_keyLocale] ?? '',
      _keyTimestamp: entry[_keyTimestamp] ?? DateTime.now().toIso8601String(),
      _keyLastViewedParagraphIndex: entry[_keyLastViewedParagraphIndex] ?? 0,
      _keyIsFavorite: entry[_keyIsFavorite] ?? false,
    };
  }
}
