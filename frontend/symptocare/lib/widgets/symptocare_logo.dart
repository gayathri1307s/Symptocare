
import 'package:flutter/material.dart';

class SymptoCareLogo extends StatelessWidget {
  final double size;
  final Color color;

  const SymptoCareLogo({
    super.key,
    this.size = 72,
    this.color = const Color(0xFF3263E9),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: size,
            color: color,
          ),
          CustomPaint(
            size: Size(size * 0.68, size * 0.34),
            painter: _EcgPainter(),
          ),
        ],
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.height * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width * 0.30, size.height * 0.55)
      ..lineTo(size.width * 0.42, size.height * 0.20)
      ..lineTo(size.width * 0.57, size.height * 0.88)
      ..lineTo(size.width * 0.72, size.height * 0.42)
      ..lineTo(size.width, size.height * 0.42);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
