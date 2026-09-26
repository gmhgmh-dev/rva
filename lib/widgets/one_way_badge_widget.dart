import 'package:flutter/material.dart';

/// Visual indicator showing whether the vehicle is on a one-way street or a two-way street.
class OneWayBadgeWidget extends StatelessWidget {
  final bool isOneWay;

  const OneWayBadgeWidget({
    super.key,
    required this.isOneWay,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isOneWay ? const Color(0xFF1565C0) : const Color(0xFF37474F);
    final borderColor = isOneWay ? const Color(0xFF42A5F5) : const Color(0xFF546E7A);
    final icon = isOneWay ? Icons.arrow_upward_rounded : Icons.swap_vert_rounded;
    final label = isOneWay ? 'VIENVIRZIENA IELA' : 'DIVVIRZIENU IELA';
    final subtitle = isOneWay ? 'Braukšana tikai 1 virzienā' : 'Standarta satiksme';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          if (isOneWay)
            BoxShadow(
              color: Colors.blueAccent.withAlpha(100),
              blurRadius: 14,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
