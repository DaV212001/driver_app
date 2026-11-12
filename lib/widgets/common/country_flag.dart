import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/country_code.dart';

/// Renders a reliable, high-resolution country flag image with graceful fallback.
/// Uses FlagCDN for crisp display across all platforms (Windows, Android, iOS, Web).
class CountryFlag extends StatelessWidget {
  final CountryCode country;
  final double width;
  final double height;
  final double borderRadius;

  const CountryFlag({
    super.key,
    required this.country,
    this.width = 26,
    this.height = 18,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final code = country.code.toLowerCase();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (code.isEmpty || code.length != 2) {
      return _buildFallback(isDark);
    }

    final flagUrl = 'https://flagcdn.com/w80/$code.png';

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: flagUrl,
        fit: BoxFit.cover,
        width: width,
        height: height,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => _buildFallback(isDark),
        errorWidget: (context, url, error) => _buildFallback(isDark),
      ),
    );
  }

  Widget _buildFallback(bool isDark) {
    // If the emoji is available and renders, or fallback to code badge
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        country.code.isNotEmpty ? country.code.toUpperCase() : '?',
        style: TextStyle(
          fontSize: height * 0.55,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white70 : Colors.black87,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
