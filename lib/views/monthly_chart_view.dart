// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../l10n/app_localizations.dart';

class MonthlyChartViewController {
  _MonthlyChartState? _state;

  void _attach(_MonthlyChartState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  void swipeLeft() {
    _state?._swipeLeft();
  }

  void swipeRight() {
    _state?._swipeRight();
  }
}

class MonthlyChartView extends StatefulWidget {
  final List<int> currentData;
  final List<int> previousData;
  final List<int> nextData;
  final int startWeekDay;
  final Color circleColor;
  final Color textColor;
  final double fontSize;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final ValueChanged<int>? onDailyViewSelected;
  final MonthlyChartViewController? controller;

  const MonthlyChartView({
    super.key,
    required this.currentData,
    required this.previousData,
    required this.nextData,
    required this.startWeekDay,
    required this.circleColor,
    required this.textColor,
    required this.fontSize,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onDailyViewSelected,
    this.controller,
  });

  @override
  State<MonthlyChartView> createState() => _MonthlyChartState();
}

class _MonthlyChartState extends State<MonthlyChartView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  double _dragShift = 0.0;
  bool _isAnimating = false;
  double _lastWidth = 0.0;
  double _tempUpperBound = 50.0;
  double _currentUpperBound = 50.0;
  double _previousUpperBound = 50.0;
  final Stopwatch _stopWatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final maxVal = widget.currentData
        .fold(50, (prev, element) => max(prev, element))
        .toDouble();
    _currentUpperBound = (maxVal / 50.0).ceilToDouble() * 50.0;
    _previousUpperBound = _currentUpperBound;
    _tempUpperBound = _currentUpperBound;
  }

  @override
  void didUpdateWidget(covariant MonthlyChartView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _animationController.dispose();
    super.dispose();
  }

  void _swipeLeft() {
    if (_isAnimating || widget.nextData.isEmpty) return;
    _animateTo(-_lastWidth, widget.nextData, () {
      widget.onSwipeLeft?.call();
      setState(() {
        _dragShift = 0.0;
      });
    });
  }

  void _swipeRight() {
    if (_isAnimating || widget.previousData.isEmpty) return;
    _animateTo(_lastWidth, widget.previousData, () {
      widget.onSwipeRight?.call();
      setState(() {
        _dragShift = 0.0;
      });
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isAnimating ||
        _dragShift.abs() >= _lastWidth ||
        (details.delta.dx > 0 && widget.previousData.isEmpty) ||
        (details.delta.dx < 0 && widget.nextData.isEmpty)) {
      return;
    }

    setState(() {
      _dragShift += details.delta.dx;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isAnimating) return;

    const threshold = 50.0;
    if (_dragShift < -threshold) {
      _swipeLeft();
    } else if (_dragShift > threshold) {
      _swipeRight();
    } else {
      _animateTo(0.0, widget.currentData, null);
    }
  }

  void _onTapDown(TapDownDetails d) {
    if (_isAnimating) return;
    _stopWatch.reset();
    _stopWatch.start();
  }

  void _onTapUp(TapUpDetails d) {
    if (_isAnimating) return;

    _stopWatch.stop();
    final holdTime = _stopWatch.elapsedMilliseconds;

    if (holdTime < 100) {
      final object = context.findRenderObject() as RenderBox;
      final size = object.size;
      final marginLeft = MonthlyBarChartPainter.margin.left;
      final marginTop = MonthlyBarChartPainter.margin.top;
      final marginRight = MonthlyBarChartPainter.margin.right;
      final marginBottom = MonthlyBarChartPainter.margin.bottom;

      double width = size.width - marginLeft - marginRight;
      double height = size.height - marginTop - marginBottom;
      double x = d.localPosition.dx - marginLeft;
      double y = d.localPosition.dy - marginTop;

      int index = ((x / width) * 7).toInt() + ((y / height) * 7).toInt() * 7;

      widget.onDailyViewSelected?.call(index);
    }
  }

  void _onTapCancel() {
    if (_isAnimating) return;
    _stopWatch.stop();
  }

  double targetUpperBound(List<int> data) {
    final maxVal = data
        .fold(50, (prev, element) => max(prev, element))
        .toDouble();
    return (maxVal / 50.0).ceilToDouble() * 50.0;
  }

  void _animateTo(double target, List<int> newData, VoidCallback? onComplete) {
    _isAnimating = true;

    final shiftAnimation = Tween<double>(begin: _dragShift, end: target)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(0.0, 0.5, curve: Curves.easeOutCubic),
          ),
        );

    _previousUpperBound = _currentUpperBound;
    _currentUpperBound = targetUpperBound(newData);

    final upperBoundAnimation =
        Tween<double>(
          begin: _previousUpperBound,
          end: _currentUpperBound,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(0.5, 1.0, curve: Curves.linear),
          ),
        );

    void listener() {
      setState(() {
        _dragShift = shiftAnimation.value;
        _tempUpperBound = upperBoundAnimation.value;
      });
    }

    shiftAnimation.addListener(listener);
    upperBoundAnimation.addListener(listener);

    _animationController.forward(from: 0.0).then((_) {
      shiftAnimation.removeListener(listener);
      upperBoundAnimation.removeListener(listener);
      _isAnimating = false;
      onComplete?.call();
    });
  }

  MonthlyBarChartPainter createPainter({
    required double shift,
    required double upperBound,
    required double beginUpperBound,
    required double endUpperBound,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return MonthlyBarChartPainter(
      currentData: widget.currentData,
      previousData: widget.previousData,
      nextData: widget.nextData,
      startWeekDay: widget.startWeekDay,
      weekdayLabel: [
        for (int i = 0; i < 7; ++i)
          intl.DateFormat.E(l10n.localeName).format(DateTime(2026, 9, i)),
      ],
      shift: shift,
      circleColor: widget.circleColor,
      textColor: widget.textColor,
      fontSize: widget.fontSize,
      tempUpperBound: upperBound,
      beginUpperBound: beginUpperBound,
      endUpperBound: endUpperBound,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final margin = MonthlyBarChartPainter.margin;
        _lastWidth = constraints.maxWidth - margin.left - margin.right;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(double.infinity, 180),
                painter: createPainter(
                  shift: _dragShift,
                  upperBound: _tempUpperBound,
                  beginUpperBound: _previousUpperBound,
                  endUpperBound: _currentUpperBound,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class MonthlyBarChartPainter extends CustomPainter {
  final List<int> currentData;
  final List<int> previousData;
  final List<int> nextData;
  final int startWeekDay;
  final List<String> weekdayLabel;
  final double shift;
  final Color circleColor;
  final Color textColor;
  final double fontSize;
  final double tempUpperBound;
  final double beginUpperBound;
  final double endUpperBound;

  static const Rect margin = Rect.fromLTRB(5, 5, 5, 5);
  static const int maxRowCount = 7;

  MonthlyBarChartPainter({
    required this.currentData,
    required this.previousData,
    required this.nextData,
    required this.startWeekDay,
    required this.weekdayLabel,
    required this.shift,
    required this.circleColor,
    required this.textColor,
    required this.fontSize,
    required this.tempUpperBound,
    required this.beginUpperBound,
    required this.endUpperBound,
  });

  void drawBubble({
    required Canvas canvas,
    required List<int> data,
    required int startOffset,
    required Rect chartRect,
    required double shift,
    required Paint bubblePaint,
    required double upperBound,
  }) {
    final dayCount = min(31, data.length);
    final chartHeight = chartRect.height;
    final chartWidth = chartRect.width;
    final origin =
        chartRect.topLeft +
        Offset(chartWidth / 7 / 2 + shift, chartHeight / maxRowCount / 2);
    final maxRadius = chartHeight / maxRowCount * 0.9;
    for (int i = 0; i < dayCount; ++i) {
      final count = data[i];
      final day = i + 1;
      final position = startOffset + i;
      final center =
          origin +
          Offset(
            (position % 7) * (chartWidth / 7),
            (position ~/ 7) * (chartHeight / maxRowCount),
          );
      final label = day.toStringAsFixed(0);
      drawText(canvas, label, center, Alignment.center);

      if (count <= 0) continue;

      final normalizedValue = sqrt(
        count.toDouble() / upperBound,
      ).clamp(0.33, 1.0);
      final radius = maxRadius * normalizedValue;
      bubblePaint.color = circleColor.withAlpha(
        (normalizedValue * 128 + 32).toInt(),
      );
      canvas.drawCircle(center, radius, bubblePaint);
    }

    for (int i = 0; i < 7; ++i) {
      final center =
          origin +
          Offset(
            (i % 7) * (chartWidth / 7),
            ((startOffset + dayCount) ~/ 7 + 1) * (chartHeight / maxRowCount),
          );
      final label = weekdayLabel[i];
      drawText(canvas, label, center, Alignment.center);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final circlePaint = Paint()
      ..color = circleColor
      ..style = PaintingStyle.fill;

    final Rect chartRect = Rect.fromLTRB(
      margin.left,
      margin.top,
      size.width - margin.right,
      size.height - margin.bottom,
    );

    final Size chartSize = chartRect.size;
    double mainShift = shift;
    double subShift = 0.0;
    List<int> targetData = [];
    int subStartWeekDay = startWeekDay;

    if (shift < 0.0) {
      if (nextData.isNotEmpty) {
        subShift = shift + chartSize.width;
        targetData = nextData;
        subStartWeekDay = (startWeekDay + currentData.length) % 7;
      }
    } else if (shift > 0.0) {
      if (previousData.isNotEmpty) {
        subShift = shift - chartSize.width;
        targetData = previousData;
        subStartWeekDay = (startWeekDay - targetData.length) % 7;
      }
    }

    // Draw Circles
    if (targetData.isNotEmpty) {
      drawBubble(
        canvas: canvas,
        data: targetData,
        startOffset: subStartWeekDay,
        chartRect: chartRect,
        shift: subShift,
        bubblePaint: circlePaint,
        upperBound: tempUpperBound,
      );
    }

    drawBubble(
      canvas: canvas,
      data: currentData,
      startOffset: startWeekDay,
      chartRect: chartRect,
      shift: mainShift,
      bubblePaint: circlePaint,
      upperBound: tempUpperBound,
    );
  }

  void drawText(
    Canvas canvas,
    String text,
    Offset position,
    Alignment alignment, {
    int proceed = 255,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor.withAlpha(proceed),
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset =
        position -
        alignment.alongOffset((Offset.zero & textPainter.size).bottomRight);

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant MonthlyBarChartPainter oldDelegate) {
    return oldDelegate.currentData != currentData ||
        oldDelegate.previousData != previousData ||
        oldDelegate.nextData != nextData ||
        oldDelegate.shift != shift ||
        oldDelegate.circleColor != circleColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.tempUpperBound != tempUpperBound ||
        oldDelegate.beginUpperBound != beginUpperBound ||
        oldDelegate.endUpperBound != endUpperBound;
  }
}
