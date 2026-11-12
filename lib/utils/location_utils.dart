import 'dart:math' as math;
import 'package:get/get.dart';

class LocationUtils {
  /// Default center coordinates for Addis Ababa, Ethiopia
  static const double defaultLatitude = 9.0209;
  static const double defaultLongitude = 38.7469;

  /// Calculate distance between two lat/lng coordinates in kilometers using Haversine formula
  static double calculateDistanceInKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;

  /// Formats distance into a badge label (e.g. "Around 1.2km" or "Around 850m")
  static String formatDistanceBadge(double km) {
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '${'around'.tr} ${meters}m';
    }
    return '${'around'.tr} ${km.toStringAsFixed(1)}km';
  }

  /// Formats distance into a clean string (e.g. "1.2 km" or "850 m")
  static String formatDistanceKm(double km) {
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// Prettifies a reverse-geocoded address string, transforming lowercase text from Gebeta Maps
  /// into proper Title Case, preserving acronyms (CMC, CBE, ATM, etc.),
  /// standardizing abbreviations (St., Rd., Ave.), and deduplicating redundant segments.
  static String prettifyAddress(String? rawAddress, {bool compact = false}) {
    if (rawAddress == null || rawAddress.trim().isEmpty) return '';

    final trimmed = rawAddress.trim();
    // Preserve coordinate fallback strings like "9.0104, 38.7617 (Addis Ababa)"
    if (RegExp(r'^\d+\.\d+,\s*\d+\.\d+').hasMatch(trimmed)) {
      return trimmed;
    }

    final rawSegments = trimmed.split(',');
    final cleanedSegments = <String>[];

    for (final seg in rawSegments) {
      final s = seg.trim();
      if (s.isEmpty) continue;

      final formatted = _formatSegmentWords(s);
      if (formatted.isEmpty) continue;

      // Deduplicate identical or redundant segments
      final isDuplicate = cleanedSegments.any((existing) =>
          existing.toLowerCase() == formatted.toLowerCase() ||
          existing.toLowerCase().split(', ').contains(formatted.toLowerCase()));

      if (!isDuplicate) {
        cleanedSegments.add(formatted);
      }
    }

    if (cleanedSegments.isEmpty) return trimmed;

    if (compact) {
      // In compact mode for pills and badges:
      // Drop trailing "Ethiopia" if we already have city/landmark segments
      if (cleanedSegments.length > 1 &&
          cleanedSegments.last.toLowerCase() == 'ethiopia') {
        cleanedSegments.removeLast();
      }
      // If still more than 2 segments (e.g. Landmark, Subcity, City), keep the most relevant 2
      if (cleanedSegments.length > 2) {
        return '${cleanedSegments[0]}, ${cleanedSegments[1]}';
      }
    }

    return cleanedSegments.join(', ');
  }

  /// Compact single-line version of prettified address suitable for small pills and headers
  static String prettifyAddressCompact(String? rawAddress) =>
      prettifyAddress(rawAddress, compact: true);

  static String _formatSegmentWords(String segment) {
    const acronyms = {
      'cmc', 'cbe', 'atm', 'dhl', 'who', 'un', 'au', 'usa', 'uk',
      'gmt', 'sms', 'tv', 'vip', 'pos', 'gps', 'id', 'fcm',
      'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix', 'x'
    };

    const abbreviations = {
      'st': 'St.',
      'st.': 'St.',
      'rd': 'Rd.',
      'rd.': 'Rd.',
      'ave': 'Ave.',
      'ave.': 'Ave.',
      'blvd': 'Blvd.',
      'blvd.': 'Blvd.',
      'bldg': 'Bldg.',
      'bldg.': 'Bldg.',
      'sq': 'Square',
      'sq.': 'Square',
      'no': 'No.',
      'no.': 'No.',
      'apt': 'Apt.',
      'apt.': 'Apt.',
    };

    const minorWords = {
      'and', 'of', 'at', 'by', 'for', 'in', 'on', 'to', 'near'
    };

    final tokens = segment.split(RegExp(r'\s+'));
    final formattedTokens = <String>[];

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i].trim();
      if (token.isEmpty) continue;

      if (token.contains('-')) {
        final subParts = token.split('-');
        final formattedSubParts = subParts
            .map((sp) => _formatSingleWord(sp, acronyms, abbreviations))
            .toList();
        formattedTokens.add(formattedSubParts.join('-'));
        continue;
      }

      if (token.contains('/')) {
        final subParts = token.split('/');
        final formattedSubParts = subParts
            .map((sp) => _formatSingleWord(sp, acronyms, abbreviations))
            .toList();
        formattedTokens.add(formattedSubParts.join('/'));
        continue;
      }

      final lower = token.toLowerCase();
      if (i > 0 && minorWords.contains(lower)) {
        formattedTokens.add(lower);
      } else {
        formattedTokens.add(_formatSingleWord(token, acronyms, abbreviations));
      }
    }

    return formattedTokens.join(' ');
  }

  static String _formatSingleWord(
    String word,
    Set<String> acronyms,
    Map<String, String> abbreviations,
  ) {
    if (word.isEmpty) return word;
    final trimmed = word.trim();
    if (trimmed.isEmpty) return '';

    final match =
        RegExp(r'^([^a-zA-Z0-9]*)(.*?)([^a-zA-Z0-9]*)$').firstMatch(trimmed);
    if (match == null) return trimmed;

    final prefix = match.group(1) ?? '';
    final core = match.group(2) ?? '';
    final suffix = match.group(3) ?? '';

    if (core.isEmpty) return trimmed;

    final lower = core.toLowerCase();
    final lowerWithSuffix = (core + suffix).toLowerCase();

    if (abbreviations.containsKey(lowerWithSuffix)) {
      return '$prefix${abbreviations[lowerWithSuffix]}';
    }

    if (abbreviations.containsKey(lower)) {
      return '$prefix${abbreviations[lower]}$suffix';
    }

    if (acronyms.contains(lower)) {
      return '$prefix${lower.toUpperCase()}$suffix';
    }

    // Preserve existing all-caps word (e.g. AMN, NGO)
    if (core == core.toUpperCase() &&
        core.length > 1 &&
        !RegExp(r'^\d+$').hasMatch(core)) {
      return '$prefix$core$suffix';
    }

    final ordinalMatch =
        RegExp(r'^(\d+)(st|nd|rd|th)$', caseSensitive: false).firstMatch(lower);
    if (ordinalMatch != null) {
      return '$prefix${ordinalMatch.group(1)}${ordinalMatch.group(2)!.toLowerCase()}$suffix';
    }

    if (RegExp(r'^\d+$').hasMatch(lower)) {
      return '$prefix$lower$suffix';
    }

    if (core.length == 1) {
      return '$prefix${core.toUpperCase()}$suffix';
    }

    final capitalized =
        '${core[0].toUpperCase()}${core.substring(1).toLowerCase()}';
    return '$prefix$capitalized$suffix';
  }
}
