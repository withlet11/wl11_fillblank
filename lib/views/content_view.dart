// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readblank/providers/app_preferences_notifier.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../providers/activity_notifier.dart';
import '../providers/contents_notifier.dart';
import '../services/text_to_speech_service.dart';
import '../style.dart';

class WordRange {
  final int start;
  final int end;
  final bool isHidden;

  const WordRange(this.start, this.end, this.isHidden);

  factory WordRange.fromMatch(RegExpMatch match, bool isHidden) =>
      WordRange(match.start, match.end, isHidden);

  WordRange copyWith({int? start, int? end, bool? isHidden}) => WordRange(
    start ?? this.start,
    end ?? this.end,
    isHidden ?? this.isHidden,
  );
}

class ContentView extends StatefulWidget {
  final String paragraph;
  final HiddenMode hiddenMode;
  final Locale locale;

  const ContentView({
    super.key,
    required this.paragraph,
    required this.hiddenMode,
    required this.locale,
  });

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  static const int _hiddenLetterCount = 3;

  late String _paragraph;
  late HiddenMode _hiddenMode;
  final List<WordRange> _hiddenWords = [];
  late List<int> _sortedIndexList;
  int _currentIndex = 0;

  // for scrollbar
  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  final GlobalKey _targetKey = GlobalKey();

  final TextToSpeechService _ttsService = TextToSpeechService();

  // bool _isPlaying = false;

  void _prepareWordList() {
    final regex = RegExp(r'\p{L}+', unicode: true);
    final matches = regex.allMatches(_paragraph).toList();
    matches.shuffle();
    int count = matches.length < 2 ? 0 : (matches.length / 5 + 1).toInt();
    for (final match in matches.sublist(0, count)) {
      switch (_hiddenMode) {
        case HiddenMode.wholeWords:
          _hiddenWords.add(WordRange.fromMatch(match, true));
          break;
        case HiddenMode.beginningOfWords:
          _hiddenWords.add(
            WordRange(
              match.start,
              min(match.start + _hiddenLetterCount, match.end),
              true,
            ),
          );
          break;
        case HiddenMode.endOfWords:
          _hiddenWords.add(
            WordRange(
              max(match.end - _hiddenLetterCount, match.start),
              match.end,
              true,
            ),
          );
          break;
      }
    }
    _hiddenWords.sort((a, b) => a.start.compareTo(b.start));
    _currentIndex = 0;

    _sortedIndexList = List.generate(_hiddenWords.length, (index) => index);
    _sortedIndexList.sort(
      (a, b) => _paragraph
          .substring(_hiddenWords[a].start, _hiddenWords[a].end)
          .toLowerCase()
          .compareTo(
            _paragraph
                .substring(_hiddenWords[b].start, _hiddenWords[b].end)
                .toLowerCase(),
          ),
    );
  }

  void _moveNextWord() {
    if (_currentIndex < _hiddenWords.length - 1) {
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
    int index = _hiddenWords.indexWhere((element) => element.start == start);
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

  void _toggleSpeak() async {
    if (_ttsService.state == TtsState.playing) {
      await _ttsService.stop();
    } else {
      await _ttsService.speak(_paragraph);
    }
  }

  @override
  void initState() {
    super.initState();
    _paragraph = widget.paragraph.trim();
    _hiddenMode = widget.hiddenMode;
    _prepareWordList();
    _ttsService.initTts(language: widget.locale.languageCode);

    _ttsService.onStart = () {
      if (mounted) setState(() {});
    };

    _ttsService.onComplete = () {
      if (mounted) setState(() {});
    };

    _ttsService.onError = (msg) {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
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
    final selectedWord = _hiddenWords.isNotEmpty
        ? _hiddenWords[_currentIndex]
        : const WordRange(0, 0, true);
    final textScaler = MediaQuery.textScalerOf(context);
    final textStyle = Theme.of(context).textTheme.bodyLarge!;
    final scaledTextStyle = textStyle.copyWith(
      fontSize: textScaler.scale(textStyle.fontSize ?? 16.0),
    );

    int index = 0;
    List<InlineSpan> spans = [];
    for (final word in _hiddenWords) {
      String visibleText = _paragraph.substring(index, word.start);
      String invisibleText = _paragraph.substring(word.start, word.end);
      if (visibleText.isNotEmpty) {
        spans.add(TextSpan(text: visibleText));
      }
      if (invisibleText.isNotEmpty) {
        final invisiblePart = TextSpan(
          text: invisibleText,
          style: scaledTextStyle.copyWith(
            color: word.isHidden ? Colors.transparent : palette.text,
            backgroundColor: word.start == selectedWord.start
                ? palette.accent
                : palette.muted,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              setState(() {
                _selectWordWithStart(word.start);
              });
            },
        );

        if (word.start == selectedWord.start) {
          final anchor = WidgetSpan(
            child: SizedBox(key: _targetKey, height: 0, width: 0),
          );

          if (_hiddenMode == HiddenMode.endOfWords) {
            spans.add(invisiblePart);
            spans.add(anchor);
          } else {
            spans.add(anchor);
            spans.add(invisiblePart);
          }
        } else {
          spans.add(invisiblePart);
        }
      }

      index = word.end;
    }

    if (index < _paragraph.length) {
      spans.add(TextSpan(text: _paragraph.substring(index)));
    }

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
            child: Text.rich(TextSpan(style: scaledTextStyle, children: spans)),
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
            onPressed: _currentIndex < _hiddenWords.length - 1
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
                (_currentIndex >= _hiddenWords.length ||
                    _hiddenWords[_currentIndex].isHidden)
                ? null
                : () async {
                    SharePlus.instance.share(
                      ShareParams(
                        text: _getWholeWord(_hiddenWords[_currentIndex]),
                      ),
                    );
                  },
            icon: const Icon(Icons.share),
          ),
          IconButton.filled(
            icon: Icon(
              _ttsService.state == TtsState.playing
                  ? Icons.stop
                  : Icons.volume_up,
            ),
            onPressed: _toggleSpeak,
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
                    onPressed: _hiddenWords[index].isHidden
                        ? _checkAnswer(index)
                        : null,
                    child: Text(
                      _paragraph
                          .substring(
                            _hiddenWords[index].start,
                            _hiddenWords[index].end,
                          )
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
    final word = _hiddenWords[index];
    final currentWord = _hiddenWords[_currentIndex];
    return () {
      if (!currentWord.isHidden) {
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
        _hiddenWords[index] = currentWord.copyWith(isHidden: false);
        setState(() {
          _moveNextWord();
        });
        final linkId = context.read<ContentsNotifier>().currentLinkId;
        context.read<ActivityNotifier>().addWord(
          _getWholeWord(_hiddenWords[index]),
          linkId: linkId,
        );
      } else if (_paragraph.substring(word.start, word.end).toLowerCase() ==
          _paragraph
              .substring(currentWord.start, currentWord.end)
              .toLowerCase()) {
        // Selected field word is correct.
        setState(() {
          int index1 = _sortedIndexList.indexOf(index);
          int index2 = _sortedIndexList.indexOf(_currentIndex);
          _sortedIndexList[index1] = _currentIndex;
          _sortedIndexList[index2] = index;
          _hiddenWords[_currentIndex] = currentWord.copyWith(isHidden: false);
          _moveNextWord();
        });
        final linkId = context.read<ContentsNotifier>().currentLinkId;
        context.read<ActivityNotifier>().addWord(
          _getWholeWord(word),
          linkId: linkId,
        );
      }
    };
  }

  String _getWholeWord(WordRange word) {
    final start = word.start;
    final end = word.end;
    if (start == end) return '';

    if (_hiddenMode == HiddenMode.wholeWords) {
      return _paragraph.substring(start, end);
    }

    final (regex, temp) = _hiddenMode == HiddenMode.beginningOfWords
        ? (RegExp(r'^\p{L}+', unicode: true), _paragraph.substring(start))
        : (RegExp(r'\p{L}+$', unicode: true), _paragraph.substring(0, end));

    final match = regex.firstMatch(temp);
    return match == null
        ? _paragraph.substring(start, end)
        : temp.substring(match.start, match.end);
  }
}
