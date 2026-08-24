// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_preferences_notifier.dart';
import '../providers/contents_notifier.dart';
import '../providers/activity_notifier.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.title});

  final String title;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

enum ImportProcessResult {
  success,
  alreadyExists,
  noParagraph,
  invalidUrl,
  noUrl,
  error,
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoadingContents = false;
  bool _isSavingContents = false;

  bool _isLoadingActivity = false;
  bool _isSavingActivity = false;

  bool get _isImportingOrExporting =>
      _isLoadingContents ||
      _isSavingContents ||
      _isLoadingActivity ||
      _isSavingActivity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pref = context.watch<AppPreferencesNotifier>();

    final settingsList = <Widget>[
      ListTile(
        leading: const Icon(Icons.language_outlined),
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
        leading: const Icon(Icons.dark_mode_outlined),
        title: Text(l10n.darkModeLabel),
        trailing: Switch(
          value: pref.isDarkMode,
          onChanged: (bool value) {
            pref.setDarkMode(value);
          },
        ),
      ),
      ListTile(
        leading: const Icon(Icons.format_size_outlined),
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
        leading: const Icon(Icons.library_books_outlined),
        title: Text(l10n.contentsRestoreLabel),
        trailing: IconButton(
          icon: _isLoadingContents
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.settings_backup_restore_outlined),
          onPressed: _isImportingOrExporting ? null : _loadContents,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.library_books_outlined),
        title: Text(l10n.contentsBackupLabel),
        trailing: IconButton(
          icon: _isSavingContents
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.save_outlined),
          onPressed: _isImportingOrExporting ? null : _saveContents,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.bar_chart_outlined),
        title: Text(l10n.activityRestoreLabel),
        trailing: IconButton(
          icon: _isLoadingActivity
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.settings_backup_restore_outlined),
          onPressed: _isImportingOrExporting ? null : _loadActivity,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.bar_chart_outlined),
        title: Text(l10n.activityBackupLabel),
        trailing: IconButton(
          icon: _isSavingActivity
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.save_outlined),
          onPressed: _isImportingOrExporting ? null : _saveActivity,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(l10n.eulaLabel),
        subtitle: Text(l10n.eulaDescription),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.eulaDialogTitle),
              content: SingleChildScrollView(child: Text(l10n.eulaText)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.library_books_outlined),
        title: Text(l10n.licensesLabel),
        subtitle: Text(l10n.licensesDescription),
        trailing: const Icon(Icons.chevron_right_outlined),
        onTap: () {
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
            // children: [
            //   const SizedBox(height: 16),
            //   const Text(
            //     'Terms of Use & EULA:',
            //     style: TextStyle(fontWeight: FontWeight.bold),
            //   ),
            //   const SizedBox(height: 4),
            //   const Text(
            //     'MIT License (Code Only)\n\n'
            //     'Copyright 2026 Yasuhiro Yamakawa <withlet11@gmail.com>\n\n'
            //     'Permission is hereby granted, free of charge, to any person obtaining a '
            //     'copy of this software  and associated documentation files (the '
            //     '"Software"), to deal in the Software without restriction, including '
            //     'without limitation the rights to use, copy, modify, merge, publish, '
            //     'distribute, sublicense, and/or sell copies of the Software, and to permit '
            //     'persons to whom the Software is furnished to do so, subject to the '
            //     'following conditions:\n\n'
            //     'The above copyright notice and this permission notice shall be included '
            //     'in all copies or  substantial portions of the Software.\n\n'
            //     'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS '
            //     'OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF '
            //     'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN '
            //     'NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, '
            //     'DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR '
            //     'OTHERWISE, ARISING FROM,  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR '
            //     'THE USE OR OTHER DEALINGS IN THE SOFTWARE.\n\n'
            //     '====================================================================\n'
            //     'TRADEMARK & BRANDING ASSETS NOTICE (EXCLUDED FROM MIT LICENSE)\n'
            //     '====================================================================\n\n'
            //     'The "MIT License" above applies ONLY to the source code of this repository.\n\n'
            //     '1. TRADEMARKS & LOGOS: The name "ReadBlank", the app icon, custom logos,'
            //     'brand colors, and original artwork located in `assets/` are NOT licensed'
            //     'under MIT and are reserved strictly under copyright and trademark law.\n\n'
            //     '2. COMMERCIAL REDISTRIBUTION: Anyone may build or fork this project, but'
            //     'redistributed or sold versions MUST remove all instances of "ReadBlank",'
            //     'replace the app icons/logos, and cannot use official backend API endpoints.',
            //   ),
            // ],
          );
        },
      ),
    ];

    return Consumer2<ContentsNotifier, ActivityNotifier>(
      builder: (context, contentsNotifier, activityNotifier, child) {
        if (contentsNotifier.isLoading || activityNotifier.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.separated(
          itemCount: settingsList.length,
          separatorBuilder: (context, index) {
            return const Divider(height: 1, thickness: 1);
          },
          itemBuilder: (context, index) {
            return settingsList[index];
          },
        );
      },
    );
  }

  Future<void> _saveContents() async {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isSavingContents = true;
    });

    try {
      final contentsNotifier = context.read<ContentsNotifier>();
      final String? path = await contentsNotifier.exportContents();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.contentsBackupLabel),
            content: Text(
              path == null
                  ? l10n.contentsBackupCancelledMessage
                  : l10n.contentsBackupCompletedMessage,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.contentsBackupErrorMessage(e.toString())),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingContents = false;
        });
      }
    }
  }

  Future<void> _loadContents() async {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoadingContents = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        final contentsNotifier = context.read<ContentsNotifier>();
        int? count = await contentsNotifier.importContents(
          result.files.single.path!,
        );
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.contentsBackupLabel),
              content: Text(
                count == null
                    ? l10n.contentsRestoreErrorMessage('error')
                    : l10n.contentsRestoreSuccessMessage(count),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonOk),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.contentsBackupLabel),
            content: Text(l10n.contentsRestoreErrorMessage(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingContents = false;
        });
      }
    }
  }

  // Future<ImportProcessResult> _addLink(String url) async {
  //   final contentsNotifier = context.read<ContentsNotifier>();
  //   if (url.isNotEmpty) {
  //     try {
  //       final response = await http.get(Uri.parse(url));
  //       if (response.statusCode == 200) {
  //         final document = parser.parse(response.body);
  //         final pElements = document.getElementsByTagName('p');
  //         if (pElements.any((element) => element.text.trim().isNotEmpty)) {
  //           if (contentsNotifier.contains(url)) {
  //             return ImportProcessResult.alreadyExists;
  //           } else {
  //             contentsNotifier.add(url);
  //             return ImportProcessResult.success;
  //           }
  //         } else {
  //           return ImportProcessResult.noParagraph;
  //         }
  //       } else {
  //         return ImportProcessResult.invalidUrl;
  //       }
  //     } catch (e) {
  //       return ImportProcessResult.error;
  //     }
  //   } else {
  //     return ImportProcessResult.noUrl;
  //   }
  // }

  Future<void> _saveActivity() async {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isSavingActivity = true;
    });

    try {
      final activityNotifier = context.read<ActivityNotifier>();
      final String? path = await activityNotifier.exportActivity();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.contentsBackupLabel),
            content: Text(
              path == null
                  ? l10n.activityBackupCancelledMessage
                  : l10n.activityBackupCompletedMessage,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingActivity = false;
        });
      }
    }
  }

  Future<void> _loadActivity() async {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoadingActivity = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        final activityNotifier = context.read<ActivityNotifier>();
        final count = await activityNotifier.importActivity(
          result.files.single.path!,
        );
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.contentsBackupLabel),
              content: Text(
                count == null
                    ? l10n.activityRestoreErrorMessage('error')
                    : l10n.activityRestoreSuccessMessage(count),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonOk),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.contentsBackupLabel),
              content: Text(l10n.fileNotSelectedMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonOk),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.activityBackupLabel),
            content: Text(l10n.activityRestoreErrorMessage(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingActivity = false;
        });
      }
    }
  }
}
