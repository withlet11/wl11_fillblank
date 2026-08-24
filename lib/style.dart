// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

class ContentViewPalette {
  final Color background;
  final Color border;
  final Color textField;
  final Color text;
  final Color accent;
  final Color muted;

  const ContentViewPalette({
    required this.background,
    required this.border,
    required this.textField,
    required this.text,
    required this.accent,
    required this.muted,
  });

  factory ContentViewPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return isDark ? _dark : _light;
  }

  static const _light = ContentViewPalette(
    background: Colors.black12,
    border: Colors.grey,
    textField: Colors.white,
    text: Colors.black,
    accent: Colors.deepOrangeAccent,
    muted: Colors.grey,
  );

  static const _dark = ContentViewPalette(
    background: Colors.black,
    border: Colors.white24,
    textField: Colors.white12,
    text: Colors.white,
    accent: Colors.deepOrangeAccent,
    muted: Colors.white38,
  );
}
