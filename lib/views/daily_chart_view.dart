// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'dart:math';

import 'package:flutter/material.dart';
import 'base_chart_view.dart';

class DailyChartViewController
    extends BaseChartViewController<_DailyBarChartState> {}

class DailyChartView extends BaseChartView {
  const DailyChartView({
    super.key,
    required super.currentData,
    required super.previousData,
    required super.nextData,
    required super.barColor,
    required super.textColor,
    required super.fontSize,
    super.onSwipeLeft,
    super.onSwipeRight,
    DailyChartViewController? super.controller,
  });

  @override
  State<DailyChartView> createState() => _DailyBarChartState();
}

class _DailyBarChartState
    extends BaseBarChartState<DailyChartView, DailyBarChartPainter> {
  @override
  DailyBarChartPainter createPainter({
    required double shift,
    required double upperBound,
    required double beginUpperBound,
    required double endUpperBound,
  }) {
    return DailyBarChartPainter(
      currentData: widget.currentData,
      previousData: widget.previousData,
      nextData: widget.nextData,
      shift: shift,
      barColor: widget.barColor,
      textColor: widget.textColor,
      fontSize: widget.fontSize,
      tempUpperBound: upperBound,
      beginUpperBound: beginUpperBound,
      endUpperBound: endUpperBound,
    );
  }

  @override
  void onTapUp(TapUpDetails d) {
    if (super.isAnimating) return;

    stopWatch.stop();
  }

  @override
  double targetUpperBound(List<int> data) {
    final maxVal = data
        .fold(50, (prev, element) => max(prev, element))
        .toDouble();
    return (maxVal / 50.0).ceilToDouble() * 50.0;
  }
}

class DailyBarChartPainter extends BaseBarChartPainter {
  DailyBarChartPainter({
    required super.currentData,
    required super.previousData,
    required super.nextData,
    required super.shift,
    required super.barColor,
    required super.textColor,
    required super.fontSize,
    required super.tempUpperBound,
    required super.beginUpperBound,
    required super.endUpperBound,
  });

  @override
  int get divisionCount => 48;

  @override
  double get totalSpacingFactor => 0.2;

  @override
  double calculateSpacing(double chartWidth, double barWidth) {
    return (chartWidth * totalSpacingFactor) / (divisionCount + 1);
  }

  @override
  void drawBars({
    required Canvas canvas,
    required List<int> data,
    required Rect chartRect,
    required double shift,
    required double barWidth,
    required double spacing,
    required Paint barPaint,
    required double upperBound,
  }) {
    final barCount = min(48, data.length);
    final chartHeight = chartRect.height;
    final origin = chartRect.bottomLeft + Offset(spacing + shift, 0);
    for (int i = 0; i < barCount; i++) {
      final count = data[i];
      if (count <= 0) continue;

      final normalizedValue = (count.toDouble() / upperBound).clamp(0.0, 1.0);
      final barHeight = chartHeight * normalizedValue;
      final left = origin.dx + i * (barWidth + spacing);
      final top = origin.dy - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  void drawGridAndLabels({
    required Canvas canvas,
    required Rect chartRect,
    required double shift,
    required double barWidth,
    required double spacing,
    required Paint axisPaint,
  }) {
    final origin = chartRect.bottomLeft + Offset(spacing + shift, 0);
    for (int i = 0; i <= 48; i += 8) {
      final top = origin + Offset(i * (barWidth + spacing), 0);
      final end = top + const Offset(0, 6);
      final labelTop = top + const Offset(0, 8);
      final labelText = (i / 2).toStringAsFixed(0);
      final alignment = i == 0
          ? Alignment.topLeft
          : i == 48
          ? Alignment.topRight
          : Alignment.topCenter;

      canvas.drawLine(top, end, axisPaint);
      drawText(canvas, labelText, labelTop, alignment);
    }
  }
}
