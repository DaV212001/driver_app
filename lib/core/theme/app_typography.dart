import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme createTextTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      // Display & Headlines: Quicksand (Refined & dialed down)
      displayLarge: GoogleFonts.quicksand(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      headlineLarge: GoogleFonts.quicksand(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      headlineMedium: GoogleFonts.quicksand(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineSmall: GoogleFonts.quicksand(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),

      // Titles & Body: Inter (Refined & dialed down)
      titleLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }
}
