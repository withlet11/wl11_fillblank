// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:readblank/screens/plain_text_page.dart';
import 'package:readblank/screens/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readblank/screens/activity_page.dart';
import 'package:url_launcher/url_launcher.dart';

import 'drawers/content_selector_drawers.dart';
import 'l10n/app_localizations.dart';
import 'providers/activity_notifier.dart';
import 'providers/app_preferences_notifier.dart';
import 'providers/contents_notifier.dart';
import 'screens/read_page.dart';

void main() async {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['ReadBlank'],
      '''
MIT License

Copyright 2026 WITHLET11 <withlet11@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.


====================================================================
PROJECT-SPECIFIC NOTICE
====================================================================

This MIT License applies to the source code of this project only.

The following original assets are NOT covered by the MIT License and remain
the property of WITHLET11:

1. ASSETS
   Original graphics, images, app icons, custom illustrations, and other
   original visual assets included in the project.

2. APP NAME AND BRAND IDENTITY
   The application name "ReadBlank", its logo, and other original branding
   elements.

The source code may be freely used, copied, modified, forked, published,
distributed, and incorporated into other projects under the MIT License.

However, the original application name, app icon, logo, and other proprietary
visual assets may not be used when redistributing the Application or a
modified version of it in a manner that suggests that the redistributed
version is the original Application or an authorized version.

A modified or derivative application should use its own application name,
icon, logo, and visual assets.
''',
    );
  });

  WidgetsFlutterBinding.ensureInitialized();
  final sharedPrefs = await SharedPreferences.getInstance();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppPreferencesNotifier()),
        ChangeNotifierProvider(create: (_) => ContentsNotifier(sharedPrefs)),
        ChangeNotifierProvider(create: (_) => ActivityNotifier()),
      ],
      child: ReadBlank(),
    ),
  );
}

class ReadBlank extends StatelessWidget {
  const ReadBlank({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferencesNotifier>();

    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.lightGreen,
      brightness: Brightness.light,
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.lightGreen,
      brightness: Brightness.dark,
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: lightColorScheme,
      listTileTheme: ListTileThemeData(
        selectedTileColor: lightColorScheme.primaryContainer,
        selectedColor: lightColorScheme.onPrimaryContainer,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      listTileTheme: ListTileThemeData(
        selectedTileColor: darkColorScheme.secondaryContainer,
        selectedColor: darkColorScheme.onSecondaryContainer,
      ),
    );

    return MaterialApp(
      title: 'ReadBlank',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: prefs.locale,
      supportedLocales: [Locale('en'), Locale('hu'), Locale('ja')],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: prefs.themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(prefs.fontSizeFactor)),
          child: child!,
        );
      },
      home: const MainPage(title: 'ReadBlank'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.title});

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pref = context.watch<AppPreferencesNotifier>();

    return Consumer2<ContentsNotifier, ActivityNotifier>(
      builder: (context, contentsNotifier, activityNotifier, child) {
        return Scaffold(
          appBar: _selectedIndex == 0
              ? _buildAppBarForRead(contentsNotifier)
              : _buildAppBarForLog(activityNotifier),
          body: _selectedIndex == 0
              ? const ReadPage(key: Key('ReadPage'), title: 'Read')
              : const ActivityPage(key: Key('ActivityPage'), title: 'Activity'),
          drawer: _selectedIndex == 0
              ? NavigationDrawer(
                  header: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Text(
                          'ReadBlank',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Image.asset(
                          'assets/images/app_icon.png',
                          width: 64,
                          height: 64,
                        ),
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
                                title:
                                    contentsNotifier.currentTitle ??
                                    l10n.noTitle,
                                domain: contentsNotifier.currentDomainName,
                                paragraphs:
                                    contentsNotifier.currentParagraphList ??
                                    <String>[],
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
                          DropdownMenuItem(
                            value: Locale('en'),
                            child: Text('English'),
                          ),
                          DropdownMenuItem(
                            value: Locale('hu'),
                            child: Text('Magyar'),
                          ),
                          DropdownMenuItem(
                            value: Locale('ja'),
                            child: Text('日本語'),
                          ),
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
                      leading: const Icon(Icons.settings),
                      title: Text(l10n.settingsNavButton),
                      onTap: () {
                        Navigator.of(context).pop();

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (BuildContext context) {
                              return const SettingsPage();
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
                            content: SingleChildScrollView(
                              child: Text(l10n.eulaText),
                            ),
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
                )
              : null,
          endDrawer: const ContentSelectorDrawers(),
          endDrawerEnableOpenDragGesture: false,
          bottomNavigationBar: _buildNavigationBar(),
        );
      },
    );
  }

  AppBar _buildAppBarForRead(ContentsNotifier contentsNotifier) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contentsNotifier.currentTitle ?? contentsNotifier.currentUrl,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            contentsNotifier.currentDomainName,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      automaticallyImplyActions: false,
      actions: [
        Builder(
          builder: (context) => contentsNotifier.isLoading
              ? IconButton(
                  icon: Icon(
                    Icons.stop_circle,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () {
                    contentsNotifier.cancelLoading();
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.library_books),
                  onPressed: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
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

  AppBar _buildAppBarForLog(ActivityNotifier activityNotifier) {
    final l10n = AppLocalizations.of(context)!;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(l10n.activityNavButton)],
      ),
      automaticallyImplyActions: false,
      actions: [
        IconButton(
          icon: Icon(Icons.looks_one),
          onPressed: activityNotifier.viewMode == ActivityViewMode.daily
              ? null
              : () => activityNotifier.viewMode = ActivityViewMode.daily,
        ),
        IconButton(
          icon: Icon(Icons.calendar_view_week),
          onPressed: activityNotifier.viewMode == ActivityViewMode.weekly
              ? null
              : () => activityNotifier.viewMode = ActivityViewMode.weekly,
        ),
        IconButton(
          icon: Icon(Icons.calendar_view_month),
          onPressed: activityNotifier.viewMode == ActivityViewMode.monthly
              ? null
              : () => activityNotifier.viewMode = ActivityViewMode.monthly,
        ),
      ],
    );
  }

  NavigationBar _buildNavigationBar() {
    final l10n = AppLocalizations.of(context)!;

    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      destinations: [
        NavigationDestination(
          label: l10n.readNavButton,
          icon: const Icon(Icons.article),
        ),
        NavigationDestination(
          label: l10n.activityNavButton,
          icon: const Icon(Icons.bar_chart),
        ),
      ],
    );
  }
}
