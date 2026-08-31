// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/contents_notifier.dart';
import '../providers/activity_notifier.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

enum ImportProcessResult {
  success,
  alreadyExists,
  noParagraph,
  invalidUrl,
  noUrl,
  error,
}

class _BackupPageState extends State<BackupPage> {
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

    final menuList = <Widget>[
      ListTile(
        leading: const Icon(Icons.library_books),
        title: Text(l10n.contentsRestoreLabel),
        trailing: IconButton(
          icon: _isLoadingContents
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.settings_backup_restore),
          onPressed: _isImportingOrExporting ? null : _loadContents,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.library_books),
        title: Text(l10n.contentsBackupLabel),
        trailing: IconButton(
          icon: _isSavingContents
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.save),
          onPressed: _isImportingOrExporting ? null : _saveContents,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.bar_chart),
        title: Text(l10n.activityRestoreLabel),
        trailing: IconButton(
          icon: _isLoadingActivity
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.settings_backup_restore),
          onPressed: _isImportingOrExporting ? null : _loadActivity,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.bar_chart),
        title: Text(l10n.activityBackupLabel),
        trailing: IconButton(
          icon: _isSavingActivity
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.save),
          onPressed: _isImportingOrExporting ? null : _saveActivity,
        ),
      ),
    ];

    return Consumer2<ContentsNotifier, ActivityNotifier>(
      builder: (context, contentsNotifier, activityNotifier, child) {
        if (contentsNotifier.isLoading || activityNotifier.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          appBar: AppBar(title: Text(l10n.backupLabel)),
          body: ListView.separated(
            itemCount: menuList.length,
            separatorBuilder: (context, index) {
              return const Divider(height: 1, thickness: 1);
            },
            itemBuilder: (context, index) {
              return menuList[index];
            },
          ),
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
