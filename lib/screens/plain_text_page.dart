// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../style.dart';

class PlainTextPage extends StatefulWidget {
  final String title;
  final String domain;
  final List<String> paragraphs;
  final String? searchWord;
  final bool isExactMatch;

  const PlainTextPage({
    super.key,
    required this.title,
    required this.domain,
    required this.paragraphs,
    this.searchWord,
    this.isExactMatch = false,
  });

  @override
  State<PlainTextPage> createState() => _PlainTextPageState();
}

class _PlainTextPageState extends State<PlainTextPage> {
  late String _title;
  late String _domain;
  late List<String> _paragraphs;
  late String? _searchWord;
  late bool _isExactMatch;

  final _textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _title = widget.title;
    _domain = widget.domain;
    _paragraphs = widget.paragraphs;
    _searchWord = widget.searchWord;
    _textEditingController.text = _searchWord ?? '';
    _isExactMatch = widget.isExactMatch;
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ContentViewPalette.of(context);
    final highlightColor = palette.accent;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _domain,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsGeometry.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textEditingController,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        visualDensity: VisualDensity.compact,
                        value: _isExactMatch,
                        onChanged: (value) {
                          setState(() {
                            _isExactMatch = value ?? false;
                          });
                        },
                      ),
                      Text(
                        l10n.exactMatchLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, paragraph) in _paragraphs.indexed)
                      if (_textEditingController.text.isEmpty ||
                          (_isExactMatch
                              ? containsWholeWord(
                                  paragraph,
                                  _textEditingController.text,
                                )
                              : paragraph.toLowerCase().contains(
                                  _textEditingController.text.toLowerCase(),
                                )))
                        Padding(
                          padding: const EdgeInsetsGeometry.symmetric(
                            vertical: 0,
                            horizontal: 16,
                          ),
                          child: Card(
                            surfaceTintColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('[${index + 1}]'),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          SharePlus.instance.share(
                                            ShareParams(text: paragraph),
                                          );
                                        },
                                        icon: Icon(Icons.share),
                                      ),
                                    ],
                                  ),
                                  RichText(
                                    text: TextSpan(
                                      children: highlightSearchWord(
                                        paragraph,
                                        highlightColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> highlightSearchWord(String text, Color highlightColor) {
    final normalStyle = Theme.of(context).textTheme.bodyLarge;
    final searchWord = _textEditingController.text.toLowerCase();
    if (searchWord.isEmpty) {
      return [TextSpan(style: normalStyle, text: text)];
    }

    final highlightStyle = normalStyle?.copyWith(
      backgroundColor: highlightColor,
    );

    final lowerCaseText = text.toLowerCase();
    List<InlineSpan> spans = [];
    int end = 0;

    while (end < lowerCaseText.length) {
      int begin = lowerCaseText.indexOf(searchWord, end);
      if (begin == -1) {
        spans.add(TextSpan(text: text.substring(end), style: normalStyle));
        break;
      } else {
        spans.add(
          TextSpan(text: text.substring(end, begin), style: normalStyle),
        );
        end = begin + searchWord.length;
        if (!_isExactMatch ||
            ((begin == 0 || !isLatinChar(text[begin - 1])) &&
                (end >= lowerCaseText.length || !isLatinChar(text[end])))) {
          spans.add(
            TextSpan(text: text.substring(begin, end), style: highlightStyle),
          );
        } else {
          spans.add(
            TextSpan(text: text.substring(begin, end), style: normalStyle),
          );
        }
      }
    }

    return spans;
  }

  bool containsWholeWord(String source, String word) {
    if (word.isEmpty) return false;
    final regex = RegExp(
      r'(?<!\p{L})' + RegExp.escape(word) + r'(?!\p{L})',
      caseSensitive: false,
      unicode: true,
    );
    return regex.hasMatch(source);
  }

  bool isLatinChar(String char) {
    return RegExp(r'^\p{Script=Latin}$', unicode: true).hasMatch(char);
  }
}
