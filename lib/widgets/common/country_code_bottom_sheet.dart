import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../models/country_code.dart';
import 'country_flag.dart';

Future<CountryCode?> showCountryPickerBottomSheet(
  BuildContext context, {
  CountryCode? selectedCountry,
  Function(CountryCode)? onSelect,
}) {
  return showModalBottomSheet<CountryCode>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CountryPickerContent(
      selectedCountry: selectedCountry ?? CountryCode.defaultCountry,
      onSelect: onSelect,
    ),
  );
}

class _CountryPickerContent extends StatefulWidget {
  final CountryCode selectedCountry;
  final Function(CountryCode)? onSelect;

  const _CountryPickerContent({
    required this.selectedCountry,
    this.onSelect,
  });

  @override
  State<_CountryPickerContent> createState() => _CountryPickerContentState();
}

class _CountryPickerContentState extends State<_CountryPickerContent> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryCode> _filteredCountries = CountryCode.allCountries;

  @override
  void initState() {
    super.initState();
    _filteredCountries = CountryCode.allCountries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _filteredCountries = CountryCode.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurfaceContainer
        : theme.cardColor;

    return Material(
      color: surfaceColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SafeArea(
          top: false,
          child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'select_country'.tr.isNotEmpty ? 'select_country'.tr : 'Select Country',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'search_country'.tr.isNotEmpty
                      ? 'search_country'.tr
                      : 'Search country or code...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkSurfaceContainerLow
                      : AppColors.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),

            // Country list
            Expanded(
              child: _filteredCountries.isEmpty
                  ? Center(
                      child: Text(
                        'no_results'.tr.isNotEmpty ? 'no_results'.tr : 'No countries found',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredCountries.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 64,
                        color: theme.dividerColor.withValues(alpha: 0.1),
                      ),
                      itemBuilder: (context, index) {
                        final country = _filteredCountries[index];
                        final isSelected = country.code == widget.selectedCountry.code &&
                            country.dialCode == widget.selectedCountry.dialCode;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 2,
                          ),
                          leading: CountryFlag(
                            country: country,
                            width: 32,
                            height: 22,
                            borderRadius: 4,
                          ),
                          title: Text(
                            country.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.primary : null,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : (isDark
                                          ? AppColors.darkSurfaceContainerHighest
                                          : AppColors.surfaceContainerHighest),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  country.dialCode,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                          onTap: () {
                            widget.onSelect?.call(country);
                            Navigator.of(context).pop(country);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
