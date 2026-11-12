import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final bool hasDot;

  const StatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor = AppColors.onlineGreenBg,
    this.textColor = AppColors.onlineGreen,
    this.hasDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasDot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
