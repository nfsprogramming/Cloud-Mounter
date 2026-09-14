import 'package:flutter/material.dart';
import '../models/connection_model.dart';
import '../theme/app_theme.dart';

class ProviderIcon extends StatelessWidget {
  final ConnectionType type;
  final double size;

  const ProviderIcon({super.key, required this.type, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.providerColors[type.name] ?? AppTheme.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Center(
        child: _buildIcon(color),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    final iconSize = size * 0.5;
    switch (type) {
      case ConnectionType.gdrive:
        return _LetterIcon('G', color, iconSize, bold: true);
      case ConnectionType.dropbox:
        return Icon(Icons.cloud_queue, color: color, size: iconSize);
      case ConnectionType.onedrive:
        return Icon(Icons.cloud, color: color, size: iconSize);
      case ConnectionType.mega:
        return _LetterIcon('M', color, iconSize, bold: true);
    }
  }
}

class _LetterIcon extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  final bool bold;

  const _LetterIcon(this.text, this.color, this.size, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
        height: 1,
      ),
    );
  }
}

class StatusDot extends StatefulWidget {
  final bool isMounted;
  final bool isMounting;

  const StatusDot(
      {super.key, required this.isMounted, required this.isMounting});

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMounting) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.warning.withValues(alpha: _pulse.value),
          ),
        ),
      );
    }

    if (widget.isMounted) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.success.withValues(alpha: 0.2 * _pulse.value),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.success,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.textTertiary,
      ),
    );
  }
}
