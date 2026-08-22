import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class WarangMapPainter extends CustomPainter {
  WarangMapPainter({required this.palette, required this.dark});
  final MapPalette palette;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.water);
    final land = Paint()..color = palette.land;
    final landAlt = Paint()..color = palette.landAlt;
    final roads = Paint()
      ..color = palette.roads
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final island = Path()
      ..moveTo(size.width * .04, size.height * .10)
      ..quadraticBezierTo(
        size.width * .34,
        size.height * .02,
        size.width * .59,
        size.height * .18,
      )
      ..quadraticBezierTo(
        size.width * .87,
        size.height * .32,
        size.width * .96,
        size.height * .70,
      )
      ..quadraticBezierTo(
        size.width * .79,
        size.height * .93,
        size.width * .44,
        size.height * .85,
      )
      ..quadraticBezierTo(
        size.width * .15,
        size.height * .82,
        size.width * .04,
        size.height * .55,
      )
      ..close();
    canvas.drawPath(island, land);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .10,
        size.height * .60,
        size.width * .44,
        size.height * .29,
      ),
      landAlt,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .60,
        size.height * .10,
        size.width * .30,
        size.height * .34,
      ),
      landAlt,
    );
    for (var i = 0; i < 3; i++) {
      final path = Path()..moveTo(-20, size.height * (.15 + i * .13));
      path.cubicTo(
        size.width * .22,
        size.height * (.05 + i * .14),
        size.width * .55,
        size.height * (.28 + i * .08),
        size.width + 20,
        size.height * (.10 + i * .14),
      );
      canvas.drawPath(path, roads..strokeWidth = 8 - i * 2.5);
    }
    for (var i = 0; i < 4; i++) {
      final path = Path()..moveTo(size.width * (.12 + i * .22), -20);
      path.cubicTo(
        size.width * (.26 + i * .12),
        size.height * .35,
        size.width * (.04 + i * .20),
        size.height * .62,
        size.width * (.30 + i * .16),
        size.height + 20,
      );
      canvas.drawPath(path, roads..strokeWidth = 3);
    }
    _paintLabel(
      canvas,
      'MALAY',
      Offset(size.width * .16, size.height * .24),
      palette.label,
    );
    _paintLabel(
      canvas,
      'BULABOG',
      Offset(size.width * .70, size.height * .51),
      palette.label,
    );
    _paintLabel(
      canvas,
      'DIWA',
      Offset(size.width * .34, size.height * .72),
      palette.label,
    );
    _paintLabel(
      canvas,
      'SIBUYAN SEA',
      Offset(size.width * .55, size.height * .09),
      palette.labelWater,
    );
  }

  void _paintLabel(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'DM Mono',
          fontSize: 9,
          letterSpacing: 1.7,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant WarangMapPainter oldDelegate) =>
      oldDelegate.palette != palette;
}
