// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_preferences_notifier.dart';
import '../providers/contents_notifier.dart';
import '../screens/backup_page.dart';
import '../screens/plain_text_page.dart';

class SettingDrawer extends StatefulWidget {
  const SettingDrawer({super.key});

  @override
  State<SettingDrawer> createState() => _SettingDrawer();
}

class _SettingDrawer extends State<SettingDrawer> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pref = context.watch<AppPreferencesNotifier>();
    final contentsNotifier = context.watch<ContentsNotifier>();

    return NavigationDrawer(
      header: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Text('ReadBlank', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Image.asset('assets/images/app_icon.png', width: 64, height: 64),
            const SizedBox(height: 16),
            const Divider(),
          ],
        ),
      ),
      children: [
        ListTile(
          leading: const Icon(Icons.add_link),
          title: Text(l10n.openPageLabel),
          subtitle: Text(l10n.openPageDescription),
          onTap: () {
            Navigator.of(context).pop();

            contentsNotifier.addLink(l10n, context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.visibility_off),
          title: Text(l10n.hiddenPartLabel),
          subtitle: Text(l10n.hiddenPartDescription),
          trailing: DropdownButton<HiddenMode>(
            value: pref.hiddenMode,
            onChanged: (HiddenMode? hiddenMode) {
              if (hiddenMode != null) pref.setHiddenMode(hiddenMode);
            },
            items: [
              DropdownMenuItem(
                value: HiddenMode.wholeWords,
                child: Text(l10n.wholeWordsLabel),
              ),
              DropdownMenuItem(
                value: HiddenMode.beginningOfWords,
                child: Text(l10n.beginningOfWordsLabel),
              ),
              DropdownMenuItem(
                value: HiddenMode.endOfWords,
                child: Text(l10n.endOfWordsLabel),
              ),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: Text(l10n.refreshCacheLabel),
          subtitle: Text(l10n.refreshCacheDescription),
          onTap: () {
            Navigator.of(context).pop();

            contentsNotifier.fetchCurrentContent();
            contentsNotifier.persist();
          },
        ),
        ListTile(
          leading: const Icon(Icons.text_snippet),
          title: Text(l10n.viewPlainTextLabel),
          subtitle: Text(l10n.viewPlainTextDescription),
          onTap: () {
            Navigator.of(context).pop();

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  return PlainTextPage(
                    title: contentsNotifier.currentTitle ?? l10n.noTitle,
                    domain: contentsNotifier.currentDomainName,
                    paragraphs:
                        contentsNotifier.currentParagraphList ?? <String>[],
                  );
                },
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.open_in_new),
          title: Text(l10n.openInBrowserLabel),
          subtitle: Text(l10n.openInBrowserDescription),
          onTap: () {
            Navigator.of(context).pop();

            _openWebPageInBrowser(contentsNotifier.currentUrl);
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l10n.languageLabel),
          trailing: DropdownButton<Locale>(
            value: pref.locale,
            onChanged: (Locale? locale) {
              if (locale != null) pref.setLocale(locale);
            },
            items: const [
              DropdownMenuItem(value: Locale('en'), child: Text('English')),
              DropdownMenuItem(value: Locale('hu'), child: Text('Magyar')),
              DropdownMenuItem(value: Locale('ja'), child: Text('日本語')),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode),
          title: Text(l10n.darkModeLabel),
          trailing: Switch(
            value: pref.isDarkMode,
            onChanged: (bool value) {
              pref.setDarkMode(value);
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.format_size),
          title: Text(l10n.fontSizeLabel),
          trailing: DropdownButton(
            items: pref.fontSizeFactorList.indexed.map((entry) {
              final (index, factor) = entry;
              return DropdownMenuItem(
                value: index,
                child: Text(
                  factor < 0.9
                      ? l10n.fontSizeSmall
                      : factor < 1.1
                      ? l10n.fontSizeMedium
                      : factor < 1.3
                      ? l10n.fontSizeLarge
                      : l10n.fontSizeXLarge,
                ),
              );
            }).toList(),
            value: pref.fontSizeIndex,
            onChanged: (int? index) {
              if (index != null) pref.setFontSizeIndex(index);
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.archive),
          title: Text(l10n.backupLabel),
          subtitle: Text(l10n.backupDescription),
          onTap: () {
            Navigator.of(context).pop();

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  return const BackupPage();
                },
              ),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.eulaLabel),
          subtitle: Text(l10n.eulaDescription),
          onTap: () {
            Navigator.of(context).pop();

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.eulaDialogTitle),
                content: SingleChildScrollView(child: Text(l10n.eulaText)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonClose),
                  ),
                ],
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.library_books),
          title: Text(l10n.licensesLabel),
          subtitle: Text(l10n.licensesDescription),
          onTap: () {
            Navigator.of(context).pop();

            showAboutDialog(
              context: context,
              applicationName: l10n.appName,
              applicationVersion: l10n.appVersion,
              applicationLegalese: l10n.appLegalese,
              applicationIcon: Image.asset(
                'assets/images/app_icon.png',
                width: 64,
                height: 64,
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openWebPageInBrowser(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $url');
    }
  }
}
