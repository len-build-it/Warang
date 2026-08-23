import 'package:flutter/material.dart';

class MomentsBarChart extends StatelessWidget {
  const MomentsBarChart({
    super.key,
    required this.values,
    required this.labels,
  });

  final List<int> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _MomentsBarPainter(
      values: values,
      labels: labels,
      barColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: .72),
      lineColor: Theme.of(context).colorScheme.outline,
      labelColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: .54),
    ),
    child: const SizedBox.expand(),
  );
}

class TripTrendChart extends StatelessWidget {
  const TripTrendChart({super.key, required this.values, required this.labels});

  final List<int> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TripTrendPainter(
      values: values,
      labels: labels,
      lineColor: Theme.of(context).colorScheme.primary.withValues(alpha: .82),
      pointColor: Theme.of(context).colorScheme.onSurface,
      labelColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: .54),
    ),
    child: const SizedBox.expand(),
  );
}

class _MomentsBarPainter extends CustomPainter {
  const _MomentsBarPainter({
    required this.values,
    required this.labels,
    required this.barColor,
    required this.lineColor,
    required this.labelColor,
  });

  final List<int> values;
  final List<String> labels;
  final Color barColor;
  final Color lineColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(10, 8, size.width - 20, size.height - 30);
    final maxValue = values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    final maxY = maxValue == 0 ? 1 : maxValue;
    final baseline = chart.bottom;
    canvas.drawLine(
      Offset.zero.translate(0, baseline),
      Offset(size.width, baseline),
      Paint()..color = lineColor,
    );
    final slot = chart.width / values.length;
    final barWidth = slot * .46;
    final barPaint = Paint()..color = barColor;
    final labelStyle = TextStyle(
      fontFamily: 'DM Mono',
      fontSize: 9,
      letterSpacing: 1.1,
      color: labelColor,
    );
    for (var index = 0; index < values.length; index++) {
      final height = chart.height * values[index] / maxY;
      final left = chart.left + slot * index + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, baseline - height, barWidth, height),
          const Radius.circular(4),
        ),
        barPaint,
      );
      final text = TextPainter(
        text: TextSpan(text: labels[index], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(left + (barWidth - text.width) / 2, baseline + 9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MomentsBarPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.labels != labels ||
      oldDelegate.barColor != barColor ||
      oldDelegate.lineColor != lineColor;
}

class _TripTrendPainter extends CustomPainter {
  const _TripTrendPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.pointColor,
    required this.labelColor,
  });

  final List<int> values;
  final List<String> labels;
  final Color lineColor;
  final Color pointColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(12, 10, size.width - 24, size.height - 32);
    final maxValue = values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    final maxY = maxValue == 0 ? 1 : maxValue;
    canvas.drawLine(
      Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom),
      Paint()..color = lineColor.withValues(alpha: .2),
    );
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = lineColor.withValues(alpha: .10)
      ..style = PaintingStyle.fill;
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (values.length - 1);
      final y = chart.bottom - chart.height * values[index] / maxY;
      points.add(Offset(x, y));
    }
    if (points.isNotEmpty) {
      final area = Path()..moveTo(points.first.dx, chart.bottom);
      final trend = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        trend.lineTo(point.dx, point.dy);
        area.lineTo(point.dx, point.dy);
      }
      area
        ..lineTo(points.last.dx, chart.bottom)
        ..close();
      canvas.drawPath(area, fill);
      canvas.drawPath(trend, line);
    }
    final pointPaint = Paint()..color = pointColor;
    final labelStyle = TextStyle(
      fontFamily: 'DM Mono',
      fontSize: 9,
      letterSpacing: 1.1,
      color: labelColor,
    );
    for (var index = 0; index < points.length; index++) {
      canvas.drawCircle(points[index], 3.5, pointPaint);
      final text = TextPainter(
        text: TextSpan(text: labels[index], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(points[index].dx - text.width / 2, chart.bottom + 9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TripTrendPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.labels != labels ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.pointColor != pointColor;
}
