// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'dart:math';
import 'package:flutter/material.dart';

abstract class BaseChartViewController<S extends BaseBarChartState> {
  S? _state;

  void _attach(S state) {
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

abstract class BaseChartView extends StatefulWidget {
  final List<int> currentData;
  final List<int> previousData;
  final List<int> nextData;
  final Color barColor;
  final Color textColor;
  final double fontSize;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final BaseChartViewController? controller;

  const BaseChartView({
    super.key,
    required this.currentData,
    required this.previousData,
    required this.nextData,
    required this.barColor,
    required this.textColor,
    required this.fontSize,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.controller,
  });
}

abstract class BaseBarChartState<
  W extends BaseChartView,
  P extends BaseBarChartPainter
>
    extends State<W>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  double _dragShift = 0.0;
  bool _isAnimating = false;
  double _lastWidth = 0.0;
  double _tempUpperBound = 50.0;
  double _currentUpperBound = 50.0;
  double _previousUpperBound = 50.0;
  final Stopwatch stopWatch = Stopwatch();

  bool get isAnimating => _isAnimating;

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
  void didUpdateWidget(covariant W oldWidget) {
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
    stopWatch.reset();
    stopWatch.start();
  }

  void onTapUp(TapUpDetails d);

  void _onTapCancel() {
    if (_isAnimating) return;
    stopWatch.stop();
  }

  double targetUpperBound(List<int> data);

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

  P createPainter({
    required double shift,
    required double upperBound,
    required double beginUpperBound,
    required double endUpperBound,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final margin = BaseBarChartPainter.margin;
        _lastWidth = constraints.maxWidth - margin.left - margin.right;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onTapDown: _onTapDown,
          onTapUp: onTapUp,
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

abstract class BaseBarChartPainter extends CustomPainter {
  final List<int> currentData;
  final List<int> previousData;
  final List<int> nextData;
  final double shift;
  final Color barColor;
  final Color textColor;
  final double fontSize;
  final double tempUpperBound;
  final double beginUpperBound;
  final double endUpperBound;

  static const Rect margin = Rect.fromLTRB(50, 20, 50, 20);

  BaseBarChartPainter({
    required this.currentData,
    required this.previousData,
    required this.nextData,
    required this.shift,
    required this.barColor,
    required this.textColor,
    required this.fontSize,
    required this.tempUpperBound,
    required this.beginUpperBound,
    required this.endUpperBound,
  });

  int get divisionCount;

  double get totalSpacingFactor;

  void drawBars({
    required Canvas canvas,
    required List<int> data,
    required Rect chartRect,
    required double shift,
    required double barWidth,
    required double spacing,
    required Paint barPaint,
    required double upperBound,
  });

  void drawGridAndLabels({
    required Canvas canvas,
    required Rect chartRect,
    required double shift,
    required double barWidth,
    required double spacing,
    required Paint axisPaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final proceed =
        (((tempUpperBound - beginUpperBound) /
                        (endUpperBound - beginUpperBound))
                    .clamp(0.0, 1.0) *
                255)
            .toInt();

    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.5;

    final gridPaint1 = Paint()
      ..color = Colors.grey.withAlpha(proceed)
      ..strokeWidth = 1.0;

    final gridPaint2 = Paint()
      ..color = Colors.grey.withAlpha(255 - proceed)
      ..strokeWidth = 1.0;

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final Rect chartRect = Rect.fromLTRB(
      margin.left,
      margin.top,
      size.width - margin.right,
      size.height - margin.bottom,
    );

    final Rect beginCharRect = Rect.fromLTRB(
      chartRect.left,
      chartRect.top +
          chartRect.height *
              (1.0 - beginUpperBound.toDouble() / tempUpperBound.toDouble()),
      chartRect.right,
      chartRect.bottom,
    );

    final Rect endChartRect = Rect.fromLTRB(
      chartRect.left,
      chartRect.top +
          chartRect.height *
              (1.0 - endUpperBound.toDouble() / tempUpperBound.toDouble()),
      chartRect.right,
      chartRect.bottom,
    );

    double mainShift = shift;
    double subShift = 0.0;
    List<int> subData = [];

    if (shift < 0.0) {
      if (nextData.isNotEmpty) {
        subShift = shift + chartRect.width;
        subData = nextData;
      }
    } else if (shift > 0.0) {
      if (previousData.isNotEmpty) {
        subShift = shift - chartRect.width;
        subData = previousData;
      }
    }

    final totalSpacing = chartRect.width * totalSpacingFactor;
    final barWidth = (chartRect.width - totalSpacing) / divisionCount;
    final spacing = calculateSpacing(chartRect.width, barWidth);

    final clipPath = Path()
      ..addRect(Rect.fromLTRB(chartRect.left, 0, chartRect.right, size.height));

    canvas.save();
    canvas.clipPath(clipPath);

    // Draw static grid lines (Upper and Middle)
    if (tempUpperBound != endUpperBound) {
      if (beginCharRect.top >= chartRect.top) {
        canvas.drawLine(
          beginCharRect.topLeft,
          beginCharRect.topRight,
          gridPaint2,
        );
      }
      if (beginCharRect.center.dy >= chartRect.top) {
        canvas.drawLine(
          beginCharRect.centerLeft,
          beginCharRect.centerRight,
          gridPaint2,
        );
      }
    }

    if (endChartRect.top >= chartRect.top) {
      canvas.drawLine(endChartRect.topLeft, endChartRect.topRight, gridPaint1);
    }
    if (endChartRect.center.dy >= chartRect.top) {
      canvas.drawLine(
        endChartRect.centerLeft,
        endChartRect.centerRight,
        gridPaint1,
      );
    }

    // Draw Bars
    if (subData.isNotEmpty) {
      drawBars(
        canvas: canvas,
        data: subData,
        chartRect: chartRect,
        shift: subShift,
        barWidth: barWidth,
        spacing: spacing,
        barPaint: barPaint,
        upperBound: tempUpperBound,
      );
    }

    drawBars(
      canvas: canvas,
      data: currentData,
      chartRect: chartRect,
      shift: mainShift,
      barWidth: barWidth,
      spacing: spacing,
      barPaint: barPaint,
      upperBound: tempUpperBound,
    );

    // Draw grid and labels
    if (subData.isNotEmpty) {
      drawGridAndLabels(
        canvas: canvas,
        chartRect: chartRect,
        shift: subShift,
        barWidth: barWidth,
        spacing: spacing,
        axisPaint: axisPaint,
      );
    }

    drawGridAndLabels(
      canvas: canvas,
      chartRect: chartRect,
      shift: mainShift,
      barWidth: barWidth,
      spacing: spacing,
      axisPaint: axisPaint,
    );

    canvas.restore();

    // Draw static grid labels (Upper and Middle)
    if (tempUpperBound != endUpperBound) {
      for (final (Offset gridEnd, double value) in [
        if (beginCharRect.top >= chartRect.top)
          (beginCharRect.topRight, beginUpperBound),
        if (beginCharRect.center.dy >= chartRect.top)
          (beginCharRect.centerRight, beginUpperBound / 2),
      ]) {
        final label = value.toStringAsFixed(0);
        const gridLabelMargin = Offset(4, 0);
        const alignment = Alignment.centerLeft;
        drawText(
          canvas,
          label,
          gridEnd + gridLabelMargin,
          alignment,
          proceed: 255 - proceed,
        );
      }
    }

    for (final (Offset gridEnd, double value) in [
      if (endChartRect.top >= chartRect.top)
        (endChartRect.topRight, endUpperBound),
      if (endChartRect.center.dy >= chartRect.top)
        (endChartRect.centerRight, endUpperBound / 2),
    ]) {
      final label = value.toStringAsFixed(0);
      const gridLabelMargin = Offset(4, 0);
      const alignment = Alignment.centerLeft;
      drawText(
        canvas,
        label,
        gridEnd + gridLabelMargin,
        alignment,
        proceed: proceed,
      );
    }

    // Draw static X-axis lines
    canvas.drawLine(
      endChartRect.bottomLeft,
      endChartRect.bottomRight,
      axisPaint,
    );
  }

  double calculateSpacing(double chartWidth, double barWidth);

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
  bool shouldRepaint(covariant BaseBarChartPainter oldDelegate) {
    return oldDelegate.currentData != currentData ||
        oldDelegate.previousData != previousData ||
        oldDelegate.nextData != nextData ||
        oldDelegate.shift != shift ||
        oldDelegate.barColor != barColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.tempUpperBound != tempUpperBound ||
        oldDelegate.beginUpperBound != beginUpperBound ||
        oldDelegate.endUpperBound != endUpperBound;
  }
}
