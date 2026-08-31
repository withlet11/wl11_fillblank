// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_preferences_notifier.dart';
import '../views/content_view.dart';
import '../providers/contents_notifier.dart';

class ReadPage extends StatefulWidget {
  const ReadPage({super.key});

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  late HiddenMode hiddenMode;

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentsNotifier>(
      builder: (context, notifier, child) {
        if (notifier.linkList.isNotEmpty &&
            notifier.currentParagraphList == null &&
            !notifier.isLoading &&
            notifier.error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifier.fetchCurrentContent();
          });
        }

        return Stack(
          children: [
            _buildContent(notifier),
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

  Widget _buildContent(ContentsNotifier notifier) {
    final l10n = AppLocalizations.of(context)!;
    final hiddenMode = context.watch<AppPreferencesNotifier>().hiddenMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            SizedBox(
              height: constraints.maxHeight * 0.9,
              child: ContentView(
                key: ValueKey(
                  '${notifier.currentParagraphIndex}_${notifier.currentParagraph}_$hiddenMode',
                ),
                paragraph:
                    (notifier.isLoading ||
                        (notifier.linkList.isNotEmpty &&
                            notifier.currentParagraph == null))
                    ? ''
                    : (notifier.currentParagraph ?? l10n.urlRequestMessage),
                hiddenMode: hiddenMode,
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: notifier.isNotFirstParagraph
                        ? () => notifier.moveToFirstParagraph()
                        : null,
                    icon: const Icon(Icons.first_page),
                  ),
                  IconButton(
                    onPressed: notifier.isNotFirstParagraph
                        ? () => notifier.movePreviousParagraph()
                        : null,
                    icon: const Icon(Icons.keyboard_arrow_left),
                  ),
                  DropdownButton<int>(
                    value: notifier.currentParagraphIndex,
                    items: List.generate(
                      notifier.currentParagraphList?.length ?? 0,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text((index + 1).toString()),
                      ),
                    ),
                    onChanged: (int? value) {
                      if (value != null) {
                        notifier.setCurrentParagraphIndex(value);
                      }
                    },
                  ),
                  IconButton(
                    onPressed: notifier.isNotLastParagraph
                        ? () => notifier.moveNextParagraph()
                        : null,
                    icon: const Icon(Icons.keyboard_arrow_right),
                  ),
                  IconButton(
                    onPressed: notifier.isNotLastParagraph
                        ? () => notifier.moveToLastParagraph()
                        : null,
                    icon: const Icon(Icons.last_page),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
