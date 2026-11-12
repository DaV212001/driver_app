import 'package:flutter/material.dart';
import '../../models/country_code.dart';
import 'country_code_bottom_sheet.dart';
import 'country_flag.dart';

/// Interactive dropdown selector displaying the active country flag and dial code.
/// Tapping opens a searchable dropdown sheet/dialog with visible country flags.
class CountryCodeDropdown extends StatelessWidget {
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onChanged;
  final bool enabled;

  const CountryCodeDropdown({
    super.key,
    required this.selectedCountry,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: enabled
          ? () => showCountryPickerBottomSheet(
                context,
                selectedCountry: selectedCountry,
                onSelect: onChanged,
              )
          : null,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CountryFlag(
                country: selectedCountry,
                width: 26,
                height: 18,
              ),
              const SizedBox(width: 8),
              Text(
                selectedCountry.dialCode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Container(
                height: 24,
                width: 1,
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
