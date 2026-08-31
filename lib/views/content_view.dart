// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readblank/providers/app_preferences_notifier.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../providers/activity_notifier.dart';
import '../providers/contents_notifier.dart';
import '../style.dart';

class ContentView extends StatefulWidget {
  final String paragraph;
  final HiddenMode hiddenMode;

  const ContentView({
    super.key,
    required this.paragraph,
    required this.hiddenMode,
  });

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  static const int _hiddenLetterCount = 3;

  late String _paragraph;
  late HiddenMode _hiddenMode;
  final List<(int, int, bool)> _wordList = [];
  late List<int> _sortedIndexList;
  int _currentIndex = 0;

  // for scrollbar
  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  final GlobalKey _targetKey = GlobalKey();

  void _prepareWordList() {
    final regex = RegExp(r'\p{L}+', unicode: true);
    final matches = regex.allMatches(_paragraph).toList();
    matches.shuffle();
    int count = matches.length < 2 ? 0 : (matches.length / 5 + 1).toInt();
    for (final match in matches.sublist(0, count)) {
      switch (_hiddenMode) {
        case HiddenMode.wholeWords:
          _wordList.add((match.start, match.end, true));
          break;
        case HiddenMode.beginningOfWords:
          _wordList.add((
            match.start,
            min(match.start + _hiddenLetterCount, match.end),
            true,
          ));
          break;
        case HiddenMode.endOfWords:
          _wordList.add((
            max(match.end - _hiddenLetterCount, match.start),
            match.end,
            true,
          ));
          break;
      }
    }
    _wordList.sort((a, b) => a.$1.compareTo(b.$1));
    _currentIndex = 0;

    _sortedIndexList = List.generate(_wordList.length, (index) => index);
    _sortedIndexList.sort(
      (a, b) => _paragraph
          .substring(_wordList[a].$1, _wordList[a].$2)
          .toLowerCase()
          .compareTo(
            _paragraph
                .substring(_wordList[b].$1, _wordList[b].$2)
                .toLowerCase(),
          ),
    );
  }

  void _moveNextWord() {
    if (_currentIndex < _wordList.length - 1) {
      ++_currentIndex;
    }
    _scrollToTarget();
  }

  void _movePreviousWord() {
    if (_currentIndex > 0) {
      --_currentIndex;
    }
    _scrollToTarget();
  }

  void _selectWordWithStart(int start) {
    int index = _wordList.indexWhere((element) => element.$1 == start);
    if (index != -1) {
      _currentIndex = index;
    }
  }

  void _scrollToTarget() {
    Scrollable.ensureVisible(
      _targetKey.currentContext!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
  }

  @override
  void initState() {
    super.initState();
    _paragraph = widget.paragraph.trim();
    _hiddenMode = widget.hiddenMode;
    _prepareWordList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ContentViewPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(
          left: BorderSide.none,
          right: BorderSide.none,
          top: BorderSide.none,
          bottom: BorderSide(
            color: palette.border,
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextView(constraints.maxHeight * 0.45, palette),
              _buildWordSelectorView(constraints.maxHeight * 0.12, palette),
              _buildWordSelectionView(constraints.maxHeight * 0.43, palette),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextView(double height, ContentViewPalette palette) {
    final (selectedStart, selectedEnd, _) = _wordList.isNotEmpty
        ? _wordList[_currentIndex]
        : const (0, 0, true);
    final textScaler = MediaQuery.textScalerOf(context);
    final textStyle = Theme.of(context).textTheme.bodyLarge!;
    final scaledTextStyle = textStyle.copyWith(
      fontSize: textScaler.scale(textStyle.fontSize ?? 16.0),
    );

    return Scrollbar(
      controller: _scrollController1,
      thumbVisibility: true,
      interactive: false,
      child: Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(color: palette.textField),
        child: SingleChildScrollView(
          controller: _scrollController1,
          // Auto-scaling doesn't work well with text.
          child: MediaQuery.withNoTextScaling(
            child: Text.rich(
              TextSpan(
                style: scaledTextStyle,
                children: [
                  ...() {
                    int index = 0;
                    List<InlineSpan> spans = [];
                    for (final (start, end, isActive) in _wordList) {
                      String visibleText = _paragraph.substring(index, start);
                      String invisibleText = _paragraph.substring(start, end);
                      if (visibleText.isNotEmpty) {
                        spans.add(TextSpan(text: visibleText));
                      }
                      if (invisibleText.isNotEmpty) {
                        spans.add(
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectWordWithStart(start);
                                });
                              },
                              child: SizedBox(
                                key: start == selectedStart ? _targetKey : null,
                                child: Text(
                                  invisibleText,
                                  style: scaledTextStyle.copyWith(
                                    color: isActive
                                        ? Colors.transparent
                                        : palette.text,
                                    backgroundColor: start == selectedStart
                                        ? palette.accent
                                        : palette.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      index = end;
                    }
                    if (index < _paragraph.length) {
                      spans.add(TextSpan(text: _paragraph.substring(index)));
                    }
                    return spans;
                  }(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordSelectorView(double height, ContentViewPalette palette) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton.filled(
            onPressed: _currentIndex > 0
                ? () {
                    setState(() {
                      _movePreviousWord();
                    });
                  }
                : null,
            icon: const Icon(Icons.keyboard_arrow_left),
          ),
          IconButton.filled(
            onPressed: _currentIndex < _wordList.length - 1
                ? () {
                    setState(() {
                      _moveNextWord();
                    });
                  }
                : null,
            icon: const Icon(Icons.keyboard_arrow_right),
          ),
          IconButton.filled(
            onPressed:
                (_currentIndex >= _wordList.length ||
                    _wordList[_currentIndex].$3)
                ? null
                : () async {
                    SharePlus.instance.share(
                      ShareParams(
                        text: _paragraph
                            .substring(
                              _wordList[_currentIndex].$1,
                              _wordList[_currentIndex].$2,
                            )
                            .toLowerCase(),
                      ),
                    );
                  },
            icon: const Icon(Icons.share),
          ),
        ],
      ),
    );
  }

  Widget _buildWordSelectionView(double height, ContentViewPalette palette) {
    return Scrollbar(
      controller: _scrollController2,
      thumbVisibility: true,
      interactive: false,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          controller: _scrollController2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                for (final index in _sortedIndexList)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      textStyle: Theme.of(context).textTheme.bodyMedium,
                      backgroundColor: palette.textField,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                    ),
                    onPressed: _wordList[index].$3 ? _checkAnswer(index) : null,
                    child: Text(
                      _paragraph
                          .substring(_wordList[index].$1, _wordList[index].$2)
                          .toLowerCase(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void Function() _checkAnswer(int index) {
    return () {
      if (!_wordList[_currentIndex].$3) {
        // Selected field is already filled.
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.fieldAlreadyFilledMessage),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (index == _currentIndex) {
        // Selected field index is correct.
        _wordList[index] = (_wordList[index].$1, _wordList[index].$2, false);
        setState(() {
          _moveNextWord();
        });
        final linkId = context.read<ContentsNotifier>().currentLinkId;
        context.read<ActivityNotifier>().addWord(
          _getWholeWord(_wordList[index].$1, _wordList[index].$2),
          linkId: linkId,
        );
      } else if (_paragraph
              .substring(_wordList[index].$1, _wordList[index].$2)
              .toLowerCase() ==
          _paragraph
              .substring(
                _wordList[_currentIndex].$1,
                _wordList[_currentIndex].$2,
              )
              .toLowerCase()) {
        // Selected field word is correct.
        setState(() {
          int index1 = _sortedIndexList.indexOf(index);
          int index2 = _sortedIndexList.indexOf(_currentIndex);
          _sortedIndexList[index1] = _currentIndex;
          _sortedIndexList[index2] = index;
          _wordList[_currentIndex] = (
            _wordList[_currentIndex].$1,
            _wordList[_currentIndex].$2,
            false,
          );
          _moveNextWord();
        });
        final linkId = context.read<ContentsNotifier>().currentLinkId;
        context.read<ActivityNotifier>().addWord(
          _getWholeWord(_wordList[index].$1, _wordList[index].$2),
          linkId: linkId,
        );
      }
    };
  }

  String _getWholeWord(int start, int end) {
    if (start == end) return '';

    if (_hiddenMode == HiddenMode.wholeWords) {
      return _paragraph.substring(start, end);
    }

    final regex = RegExp(r'\p{L}+', unicode: true);
    final String temp;
    final RegExpMatch match;

    if (_hiddenMode == HiddenMode.beginningOfWords) {
      temp = _paragraph.substring(start - _hiddenLetterCount, end);
      match = regex.allMatches(temp).toList().last;
    } else {
      temp = _paragraph.substring(start, end + _hiddenLetterCount);
      match = regex.allMatches(temp).toList().first;
    }

    return temp.substring(match.start, match.end);
  }
}
