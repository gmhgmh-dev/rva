import 'package:flutter/material.dart';

/// Renders a European-style circular speed limit sign with red border and white interior.
class SpeedSignWidget extends StatelessWidget {
  final int? speedLimit;
  final bool isReducedZone;

  const SpeedSignWidget({
    super.key,
    required this.speedLimit,
    required this.isReducedZone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: isReducedZone ? const Color(0xFFD32F2F) : const Color(0xFFE53935),
              width: 12,
            ),
            boxShadow: [
              BoxShadow(
                color: (isReducedZone ? Colors.redAccent : Colors.black).withAlpha(80),
                blurRadius: isReducedZone ? 16 : 8,
                spreadRadius: isReducedZone ? 2 : 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              speedLimit != null ? '$speedLimit' : '--',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isReducedZone ? Colors.amber.shade900 : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isReducedZone ? '30 KM/H ZONA' : 'STANDARTA ZONA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
