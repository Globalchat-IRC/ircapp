import 'package:flutter/material.dart';

/// Badge de reputación con colores y tooltip
class ReputationBadge extends StatelessWidget {
  final int reputation;
  final bool showNumber;
  final double size;
  
  const ReputationBadge({
    super.key,
    required this.reputation,
    this.showNumber = true,
    this.size = 20,
  });
  
  @override
  Widget build(BuildContext context) {
    final color = _getReputationColor();
    final icon = _getReputationIcon();
    final level = _getReputationLevel();
    
    return Tooltip(
      message: '$level ($reputation/100)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: size * 0.8),
            if (showNumber) ...[
              const SizedBox(width: 4),
              Text(
                '$reputation',
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Color _getReputationColor() {
    if (reputation >= 80) return Colors.green;
    if (reputation >= 60) return Colors.lightGreen;
    if (reputation >= 40) return Colors.orange;
    if (reputation >= 20) return Colors.deepOrange;
    return Colors.red;
  }
  
  IconData _getReputationIcon() {
    if (reputation >= 80) return Icons.star;
    if (reputation >= 60) return Icons.thumb_up;
    if (reputation >= 40) return Icons.horizontal_rule;
    if (reputation >= 20) return Icons.thumb_down;
    return Icons.block;
  }
  
  String _getReputationLevel() {
    if (reputation >= 80) return 'Excelente';
    if (reputation >= 60) return 'Buena';
    if (reputation >= 40) return 'Regular';
    if (reputation >= 20) return 'Baja';
    return 'Muy Baja';
  }
}

