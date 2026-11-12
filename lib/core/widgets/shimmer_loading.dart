import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

class ShimmerLoadingCard extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const ShimmerLoadingCard({
    super.key,
    this.height = 120,
    this.width = double.infinity,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFE2E8F0),
      highlightColor: isDark ? AppColors.darkSurfaceContainerHigh : const Color(0xFFF1F5F9),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
