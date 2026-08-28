// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_preferences_notifier.dart';
import '../providers/contents_notifier.dart';

class ContentSelectorDrawers extends StatefulWidget {
  const ContentSelectorDrawers({super.key});

  @override
  State<ContentSelectorDrawers> createState() => _ContentSelectorDrawersState();
}

class _ContentSelectorDrawersState extends State<ContentSelectorDrawers>
    with SingleTickerProviderStateMixin {
  static const String _keyUrl = 'url';
  static const String _keyTitle = 'title';
  static const String _keyOriginalTitle = 'original_title';
  static const String _keyFileSize = 'file_size';
  static const String _keyLocale = 'locale';
  static const String _keyTimestamp = 'timestamp';
  static const String _keyIsFavorite = 'isFavorite';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fontSizeFactor = context
        .watch<AppPreferencesNotifier>()
        .fontSizeFactor;

    return Consumer<ContentsNotifier>(
      builder: (context, contentsNotifier, child) {
        if (contentsNotifier.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        return NavigationDrawer(
          header: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.library_books),
                            Text(
                              l10n.contentListLabel,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        IconButton.filled(
                          icon: const Icon(Icons.add_link),
                          visualDensity: VisualDensity.comfortable,
                          onPressed: () =>
                              contentsNotifier.addLink(l10n, context),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                          ),
                          icon: Icon(
                            contentsNotifier.isFavoritesOnly
                                ? Icons.filter_alt
                                : Icons.filter_alt_off,
                          ),
                          label: Text(l10n.favoritesLabel),
                          onPressed: () {
                            contentsNotifier.isFavoritesOnly =
                                !contentsNotifier.isFavoritesOnly;
                            contentsNotifier.persist();
                          },
                        ),
                        DropdownButton<String?>(
                          value: contentsNotifier.targetLocale,
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l10n.allLanguage),
                            ),
                            for (final locale in contentsNotifier.locales)
                              DropdownMenuItem(
                                value: locale,
                                child: Text(
                                  '$locale ${_localeNameToEmoji(locale)}',
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            contentsNotifier.targetLocale = value;
                            contentsNotifier.persist();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                if (contentsNotifier.isLoading)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
          children: [
            for (final entry in contentsNotifier.sortedLinkList)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0.0,
                  vertical: 0.0,
                ),
                minLeadingWidth: 0,
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
                leading: IconButton(
                  isSelected: entry[_keyIsFavorite] ?? false,
                  icon: const Icon(Icons.star_outline),
                  selectedIcon: const Icon(Icons.star),
                  onPressed: () {
                    final isFavorite = entry[_keyIsFavorite] ?? false;
                    entry[_keyIsFavorite] = !isFavorite;
                    contentsNotifier.persist();
                  },
                  disabledColor: Theme.of(context).colorScheme.onSurface,
                ),
                title: Text(
                  entry[_keyTitle] ?? l10n.noTitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dns, size: 12 * fontSizeFactor),
                        Expanded(
                          child: Text(
                            Uri.parse(entry[_keyUrl]).host,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontFamily: 'monospace'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.calendar_month, size: 12 * fontSizeFactor),
                        Expanded(
                          child: Text(
                            DateFormat.yMMMd(l10n.localeName).add_jm().format(
                              DateTime.parse(entry[_keyTimestamp]),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.language, size: 12 * fontSizeFactor),
                        Text(
                          entry[_keyLocale] ?? '?',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.data_usage, size: 12 * fontSizeFactor),
                        Text(
                          entry[_keyFileSize] ?? '? B',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
                selected: contentsNotifier.isSelected(entry[_keyUrl]),
                onTap: () async {
                  contentsNotifier.select(entry[_keyUrl]);
                  Navigator.pop(context);
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditTitleDialog(entry, contentsNotifier);
                        break;
                      case 'refresh':
                        contentsNotifier.fetchContent(entry[_keyUrl]);
                        contentsNotifier.persist();
                        break;
                      case 'open':
                        _openWebPageInBrowser(entry[_keyUrl]);
                        break;
                      case 'delete':
                        if (entry[_keyIsFavorite]) {
                          _showFavoriteCannotDeleteDialog(
                            context,
                            entry,
                            contentsNotifier,
                          );
                        } else {
                          contentsNotifier.remove(entry[_keyUrl]);
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit),
                          const SizedBox(width: 8),
                          Text(l10n.editTitleLabel),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          const Icon(Icons.refresh),
                          const SizedBox(width: 8),
                          Text(l10n.refreshCacheLabel),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          const Icon(Icons.open_in_new),
                          const SizedBox(width: 8),
                          Text(l10n.openInBrowserLabel),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: contentsNotifier.linkList.length > 1,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.deleteLabel),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _clearAllHistory,
                    icon: const Icon(Icons.delete_sweep),
                    label: Text(l10n.allContentsClearButton),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _localeNameToEmoji(String localeName) {
    final parts = localeName.replaceAll('-', '_').split('_');

    String countryCode = '';
    if (parts.length > 1) {
      countryCode = parts.last.toUpperCase();
    } else {
      final languageCode = parts.first;
      countryCode = languageCode == 'en'
          ? 'US'
          : languageCode == 'ja'
          ? 'JP'
          : languageCode == 'zh'
          ? 'CN'
          : languageCode.toUpperCase();
    }

    if (countryCode.isEmpty) return '';

    final int firstChar = countryCode.codeUnitAt(0) + 0x1F1A5;
    final int secondChar = countryCode.codeUnitAt(1) + 0x1F1A5;

    return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
  }

  void _showFavoriteCannotDeleteDialog(
    BuildContext context,
    Map<String, dynamic> entry,
    ContentsNotifier contentsNotifier,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteLabel),
        content: Text(l10n.favoriteCannotDeleteConfirmation),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.commonOk),
          ),
        ],
      ),
    );
  }

  void _showEditTitleDialog(
    Map<String, dynamic> entry,
    ContentsNotifier contentsNotifier,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: entry[_keyTitle]);
    final originalTitle = entry[_keyOriginalTitle];

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.editTitleLabel),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.noTitle),
                maxLines: null,
                onChanged: (value) {
                  setState(() {});
                },
              ),
              actionsOverflowAlignment: OverflowBarAlignment.start,
              actions: [
                TextButton(
                  onPressed:
                      (originalTitle == null ||
                          originalTitle == controller.text)
                      ? null
                      : () {
                          setState(() {
                            controller.text = originalTitle;
                          });
                        },
                  child: Text(l10n.restoreOriginalButton),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.commonCancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: Text(l10n.commonSave),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (newTitle != null) {
      final trimmedTitle = newTitle.trim();
      if (trimmedTitle != entry[_keyTitle]) {
        entry[_keyTitle] = trimmedTitle.isEmpty ? null : trimmedTitle;
        contentsNotifier.persist();
      }
    }
  }

  Future<void> _openWebPageInBrowser(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $url');
    }
  }

  void _clearAllHistory() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<ContentsNotifier>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.allContentsClearButton),
        content: Text(l10n.allContentsClearConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonYes),
          ),
        ],
      ),
    );

    if (confirm == true) {
      settings.clearAll();
    }
  }
}
