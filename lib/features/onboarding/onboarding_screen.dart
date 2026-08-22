import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme/tokens.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Maya(size: 150),
                  const SizedBox(height: 30),
                  Text(
                    'Warang',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A map you fill with your own photographs.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 42),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'What should we call you?',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await ref
                          .read(repositoryProvider)
                          .setName(
                            _nameController.text.isEmpty
                                ? 'Explorer'
                                : _nameController.text,
                          );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: WarangColors.accent,
                      foregroundColor: WarangColors.accentInk,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: const Text('Start'),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Warang may ask for camera and location access so your moments can be saved where you are. Nothing leaves this phone.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Maya extends StatelessWidget {
  const _Maya({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size,
    child: CustomPaint(painter: _MayaPainter()),
  );
}

class _MayaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 4);
    final scale = size.shortestSide / 150;
    final body = Paint()..color = const Color(0xFF8B5038);
    final cream = Paint()..color = const Color(0xFFF1DFC0);
    final dark = Paint()..color = const Color(0xFF2E241D);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 78 * scale, height: 96 * scale),
      body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 18 * scale),
        width: 52 * scale,
        height: 62 * scale,
      ),
      cream,
    );
    canvas.drawCircle(center.translate(0, -48 * scale), 34 * scale, body);
    canvas.drawArc(
      Rect.fromCenter(
        center: center.translate(0, -52 * scale),
        width: 64 * scale,
        height: 48 * scale,
      ),
      3.14,
      3.14,
      false,
      dark,
    );
    canvas.drawCircle(
      center.translate(12 * scale, -53 * scale),
      4 * scale,
      dark,
    );
    final beak = Path()
      ..moveTo(center.dx + 31 * scale, center.dy - 48 * scale)
      ..lineTo(center.dx + 52 * scale, center.dy - 42 * scale)
      ..lineTo(center.dx + 31 * scale, center.dy - 35 * scale)
      ..close();
    canvas.drawPath(beak, Paint()..color = WarangColors.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
