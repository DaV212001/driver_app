import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/storage_config.dart';
import '../../constants/constants.dart';
import '../../constants/pages.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/status_badge.dart';
import '../../controllers/profile_controller.dart';
import '../../models/country_code.dart';
import '../../models/driver_profile.dart';
import '../../widgets/common/country_code_dropdown.dart';
import '../../widgets/fcm_token_card.dart';

class DriverProfileScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const DriverProfileScreen({super.key, this.onBack});

  void _showImagePickerModal(BuildContext context, ProfileController controller) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update Profile Photo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    controller.pickAndUploadProfileImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    controller.pickAndUploadProfileImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditProfileSheet(BuildContext context, ProfileController controller) {
    final rawPhone = controller.profile.value.phone;
    final matchedCountry = CountryCode.findByPhoneNumber(rawPhone) ?? CountryCode.defaultCountry;
    String initialNumber = rawPhone;
    if (initialNumber.startsWith(matchedCountry.dialCode)) {
      initialNumber = initialNumber.substring(matchedCountry.dialCode.length).trim();
    } else {
      final dialDigits = matchedCountry.dialCode.replaceAll('+', '');
      if (initialNumber.startsWith(dialDigits)) {
        initialNumber = initialNumber.substring(dialDigits.length).trim();
      }
    }

    final firstNameController = TextEditingController(text: controller.profile.value.firstName);
    final lastNameController = TextEditingController(text: controller.profile.value.lastName);
    final phoneController = TextEditingController(text: initialNumber);
    final emailController = TextEditingController(text: controller.profile.value.email);
    final formKey = GlobalKey<FormState>();
    CountryCode selectedCountry = matchedCountry;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edit Profile Information',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter first name' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter last name' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: CountryCodeDropdown(
                            selectedCountry: selectedCountry,
                            onChanged: (country) {
                              setModalState(() {
                                selectedCountry = country;
                              });
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter phone' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Please enter a valid email' : null,
                      ),
                      const SizedBox(height: 20),
                      Obx(() {
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: controller.isUpdating.value
                                ? null
                                : () async {
                                    if (formKey.currentState?.validate() ?? false) {
                                      final cleanDigits = phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
                                      final finalPhone = '${selectedCountry.dialCode} $cleanDigits';
                                      final ok = await controller.updateProfileInfo(
                                        firstName: firstNameController.text,
                                        lastName: lastNameController.text,
                                        email: emailController.text,
                                        phone: finalPhone,
                                      );
                                      if (ok && ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                    }
                                  },
                            child: controller.isUpdating.value
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ProfileController>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              )
            : null,
        title: const AutoSizeText(
          'My Profile & Settings',
          maxLines: 1,
          minFontSize: 14,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          Obx(() {
            final isDark = ThemeController.to.isDarkMode;
            return IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 20,
                color: isDark ? AppColors.starGold : AppColors.onSurfaceVariant,
              ),
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              onPressed: ThemeController.to.toggleTheme,
            );
          }),
        ],
      ),
      body: Obx(() {
        final profile = controller.profile.value;

        return RefreshIndicator(
          onRefresh: controller.fetchProfileFromApi,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Driver Profile Card (Stitch design, overflow safe)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar with Edit Badge
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: () => _showImagePickerModal(context, controller),
                                child: CircleAvatar(
                                  radius: 34,
                                  backgroundImage: (profile.avatarUrl.isNotEmpty &&
                                          (profile.avatarUrl.startsWith('http://') ||
                                              profile.avatarUrl.startsWith('https://')))
                                      ? NetworkImage(profile.avatarUrl)
                                      : null,
                                  backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.2),
                                  child: (profile.avatarUrl.isEmpty ||
                                          (!profile.avatarUrl.startsWith('http://') &&
                                              !profile.avatarUrl.startsWith('https://')))
                                      ? const Icon(Icons.person_rounded, size: 36, color: AppColors.primary)
                                      : null,
                                ),
                              ),
                              if (controller.isUploadingPhoto.value)
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _showImagePickerModal(context, controller),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: AutoSizeText(
                                        profile.name.isNotEmpty
                                            ? profile.name
                                            : (StorageConfig.getDriverName()?.isNotEmpty == true
                                                ? StorageConfig.getDriverName()!
                                                : 'Driver'),
                                        maxLines: 1,
                                        minFontSize: 12,
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _showEditProfileSheet(context, controller),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.edit_rounded, size: 13, color: AppColors.primary),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Edit',
                                              style: textTheme.labelSmall?.copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 15, color: AppColors.starGold),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: AutoSizeText(
                                        '${profile.rating} • (${profile.totalTrips} deliveries)',
                                        maxLines: 1,
                                        minFontSize: 10,
                                        style: textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                StatusBadge(
                                  label: profile.tier,
                                  icon: Icons.shield_rounded,
                                  backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.15),
                                  textColor: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      // Contact details and Wallet row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.phone_rounded, size: 14, color: AppColors.onSurfaceVariant),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: AutoSizeText(
                                        profile.phone,
                                        maxLines: 1,
                                        minFontSize: 10,
                                        style: textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (profile.email.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.email_rounded, size: 14, color: AppColors.onSurfaceVariant),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: AutoSizeText(
                                          profile.email,
                                          maxLines: 1,
                                          minFontSize: 9,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.onlineGreenBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Wallet Balance',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 9.5,
                                    color: AppColors.onlineGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${profile.walletAmount.toStringAsFixed(2)} ${profile.displayCurrency}',
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onlineGreen,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 2. Vehicle Verification Card (Fixed RenderFlex overflow with Expanded)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _buildVehicleIcon(profile.vehicle),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AutoSizeText(
                                    profile.vehicle.type.isNotEmpty
                                        ? profile.vehicle.type
                                        : (profile.vehicle.model.isNotEmpty
                                            ? profile.vehicle.model
                                            : (StorageConfig.getDriverVehicleName()?.isNotEmpty == true
                                                ? StorageConfig.getDriverVehicleName()!
                                                : (profile.vehicle.vehicleId != null
                                                    ? 'Vehicle #${profile.vehicle.vehicleId}'
                                                    : (StorageConfig.getDriverVehicleId() != null
                                                        ? 'Vehicle #${StorageConfig.getDriverVehicleId()}'
                                                        : 'Registered Vehicle')))),
                                    maxLines: 1,
                                    minFontSize: 11,
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  AutoSizeText(
                                    profile.vehicle.plateNumber.isNotEmpty
                                        ? 'Plate: ${profile.vehicle.plateNumber}'
                                        : (StorageConfig.getDriverPlateNumber()?.isNotEmpty == true
                                            ? 'Plate: ${StorageConfig.getDriverPlateNumber()}'
                                            : 'Plate: Not assigned'),
                                    maxLines: 1,
                                    minFontSize: 9,
                                    style: textTheme.bodySmall?.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // const SizedBox(width: 8),
                      // StatusBadge(
                      //   label: profile.vehicle.isVerified ? 'Verified' : 'Pending',
                      //   icon: profile.vehicle.isVerified ? Icons.verified_rounded : Icons.pending_rounded,
                      //   backgroundColor: profile.vehicle.isVerified ? AppColors.onlineGreenBg : AppColors.warningAmberBg,
                      //   textColor: profile.vehicle.isVerified ? AppColors.onlineGreen : AppColors.warningAmber,
                      // ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Operational Preferences & Settings
                Text(
                  'DRIVER SETTINGS',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                Material(
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      // Theme Switch Tile (Default Light)
                      Obx(() {
                        final isDark = ThemeController.to.isDarkMode;
                        return SwitchListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          secondary: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: isDark ? AppColors.starGold : AppColors.primary,
                          ),
                          activeThumbColor: AppColors.primary,
                          title: AutoSizeText(
                            'Dark Mode',
                            maxLines: 1,
                            minFontSize: 11,
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: AutoSizeText(
                            isDark ? 'Dark theme enabled' : 'Light theme enabled (default)',
                            maxLines: 1,
                            minFontSize: 9,
                            style: textTheme.bodySmall?.copyWith(fontSize: 11),
                          ),
                          value: isDark,
                          onChanged: (_) => ThemeController.to.toggleTheme(),
                        );
                      }),
                      const Divider(height: 1),

                      // Delivery History Shortcut
                      ListTile(
                        leading: const Icon(Icons.history_rounded, color: AppColors.primary),
                        title: AutoSizeText(
                          'Complete Delivery History',
                          maxLines: 1,
                          minFontSize: 11,
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: AutoSizeText(
                          'View logs and receipts of all past trips',
                          maxLines: 1,
                          minFontSize: 9,
                          style: textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () => Get.toNamed(Pages.deliveryHistory),
                      ),
                      const Divider(height: 1),

                      // Account Deletion Tile (Apple App Store Guideline 5.1.1(v) & Google Play User Data)
                      ListTile(
                        leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                        title: AutoSizeText(
                          'Delete Account',
                          maxLines: 1,
                          minFontSize: 11,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.error,
                          ),
                        ),
                        subtitle: AutoSizeText(
                          'Permanently remove your driver account and data',
                          maxLines: 1,
                          minFontSize: 9,
                          style: textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.error),
                        onTap: () => controller.requestAccountDeletion(context),
                      ),

                      // Auto-accept toggle
                      // SwitchListTile(
                      //   contentPadding:
                      //       const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      //   activeThumbColor: AppColors.primary,
                      //   title: AutoSizeText(
                      //     'Auto-Accept Delivery Assignments',
                      //     maxLines: 1,
                      //     minFontSize: 11,
                      //     style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                      //   ),
                      //   subtitle: AutoSizeText(
                      //     'Automatically accept queue dispatches',
                      //     maxLines: 1,
                      //     minFontSize: 9,
                      //     style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      //   ),
                      //   value: profile.autoAcceptOrders,
                      //   onChanged: controller.toggleAutoAccept,
                      // ),
                      // const Divider(height: 1),

                      // Navigation app selector
                      // ListTile(
                      //   leading: const Icon(Icons.navigation_rounded, color: AppColors.primary),
                      //   title: AutoSizeText(
                      //     'Navigation Provider',
                      //     maxLines: 1,
                      //     minFontSize: 11,
                      //     style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                      //   ),
                      //   trailing: Row(
                      //     mainAxisSize: MainAxisSize.min,
                      //     children: [
                      //       AutoSizeText(
                      //         profile.navigationApp,
                      //         maxLines: 1,
                      //         minFontSize: 10,
                      //         style: textTheme.bodySmall?.copyWith(
                      //           color: AppColors.primary,
                      //           fontWeight: FontWeight.w600,
                      //           fontSize: 11.5,
                      //         ),
                      //       ),
                      //       const Icon(Icons.chevron_right_rounded, size: 20),
                      //     ],
                      //   ),
                      //   onTap: () {
                      //     final next = profile.navigationApp == 'Google Maps'
                      //         ? 'Waze'
                      //         : 'Google Maps';
                      //     controller.setNavigationApp(next);
                      //   },
                      // ),
                      // const Divider(height: 1),

                      // Linked Bank Account
                      // ListTile(
                      //   leading: const Icon(Icons.account_balance_rounded,
                      //       color: AppColors.primary),
                      //   title: AutoSizeText(
                      //     'Payout Bank Account',
                      //     maxLines: 1,
                      //     minFontSize: 11,
                      //     style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                      //   ),
                      //   subtitle: AutoSizeText(
                      //     '${profile.bankName} (${profile.bankAccountNumber})',
                      //     maxLines: 1,
                      //     minFontSize: 9,
                      //     style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      //   ),
                      //   trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      //   onTap: () {
                      //     Get.snackbar(
                      //       'Bank Settings',
                      //       'Direct deposit linked to Commercial Bank of Ethiopia (CBE).',
                      //       backgroundColor: Colors.white,
                      //     );
                      //   },
                      // ),
                      // const Divider(height: 1),

                      // Safety Toolkit
                      // ListTile(
                      //   leading: const Icon(Icons.security_rounded, color: AppColors.secondary),
                      //   title: AutoSizeText(
                      //     'Safety Toolkit',
                      //     maxLines: 1,
                      //     minFontSize: 11,
                      //     style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                      //   ),
                      //   subtitle: AutoSizeText(
                      //     'Emergency assistance, dispatch road support',
                      //     maxLines: 1,
                      //     minFontSize: 9,
                      //     style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      //   ),
                      //   trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      //   onTap: () {
                      //     Get.snackbar(
                      //       'Safety Center',
                      //       'Emergency dispatch hotline: 991 / AMN Driver Security.',
                      //       backgroundColor: Colors.white,
                      //     );
                      //   },
                      // ),
                      // const Divider(height: 1),

                      // Order Ringtone Sound toggle
                      // Obx(() {
                      //   final soundOn = OrderAlertService.instance.soundEnabled.value;
                      //   return SwitchListTile(
                      //     contentPadding:
                      //         const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      //     secondary: Icon(
                      //       soundOn ? Icons.ring_volume_rounded : Icons.volume_off_rounded,
                      //       color: soundOn ? AppColors.primary : AppColors.onSurfaceVariant,
                      //     ),
                      //     activeThumbColor: AppColors.primary,
                      //     title: AutoSizeText(
                      //       'Order Ringtone Alert',
                      //       maxLines: 1,
                      //       minFontSize: 11,
                      //       style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                      //     ),
                      //     subtitle: AutoSizeText(
                      //       soundOn ? 'Phone rings when new orders arrive' : 'Sound disabled',
                      //       maxLines: 1,
                      //       minFontSize: 9,
                      //       style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      //     ),
                      //     value: soundOn,
                      //     onChanged: (val) => OrderAlertService.instance.setSoundEnabled(val),
                      //   );
                      // }),
                      // const Divider(height: 1),

                      // // Order Vibration Alert toggle
                      // Obx(() {
                      //   final vibeOn = OrderAlertService.instance.vibrationEnabled.value;
                      //   return SwitchListTile(
                      //     contentPadding:
                      //         const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      //     secondary: Icon(
                      //       vibeOn ? Icons.vibration_rounded : Icons.smartphone_rounded,
                      //       color: vibeOn ? AppColors.primary : AppColors.onSurfaceVariant,
                      //     ),
                      //     activeThumbColor: AppColors.primary,
                      //     title: AutoSizeText(
                      //       'Order Vibration Alert',
                      //       maxLines: 1,
                      //       minFontSize: 11,
                      //       style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                      //     ),
                      //     subtitle: AutoSizeText(
                      //       vibeOn ? 'Rhythmic ringing vibration enabled' : 'Vibration disabled',
                      //       maxLines: 1,
                      //       minFontSize: 9,
                      //       style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      //     ),
                      //     value: vibeOn,
                      //     onChanged: (val) => OrderAlertService.instance.setVibrationEnabled(val),
                      //   );
                      // }),
                      // const Divider(height: 1),

                      // // Test Ringtone & Vibration Button
                      // Obx(() {
                      //   final isTesting = OrderAlertService.instance.isRinging.value;
                      //   return ListTile(
                      //     leading: Icon(
                      //       isTesting ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                      //       color: isTesting ? AppColors.secondary : AppColors.primary,
                      //     ),
                      //     title: AutoSizeText(
                      //       isTesting ? 'Ringing... Tap to Stop' : 'Test Order Ringtone & Vibration',
                      //       maxLines: 1,
                      //       minFontSize: 11,
                      //       style: textTheme.titleSmall?.copyWith(
                      //         fontWeight: FontWeight.w600,
                      //         fontSize: 13,
                      //         color: isTesting ? AppColors.secondary : null,
                      //       ),
                      //     ),
                      //     subtitle: AutoSizeText(
                      //       isTesting
                      //           ? 'Testing phone ringing sound and vibration pattern'
                      //           : 'Plays 3-second sample ringtone & vibration',
                      //       maxLines: 1,
                      //       minFontSize: 9,
                      //       style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      //     ),
                      //     trailing: ElevatedButton.icon(
                      //       onPressed: () {
                      //         if (isTesting) {
                      //           OrderAlertService.instance.stopRinging();
                      //         } else {
                      //           OrderAlertService.instance.testAlert();
                      //         }
                      //       },
                      //       icon: Icon(isTesting ? Icons.stop_rounded : Icons.volume_up_rounded, size: 16),
                      //       label: Text(isTesting ? 'Stop' : 'Test'),
                      //       style: ElevatedButton.styleFrom(
                      //         backgroundColor: isTesting ? AppColors.secondary : AppColors.primary,
                      //         foregroundColor: Colors.white,
                      //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      //         minimumSize: Size.zero,
                      //         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      //       ),
                      //     ),
                      //     onTap: () {
                      //       if (isTesting) {
                      //         OrderAlertService.instance.stopRinging();
                      //       } else {
                      //         OrderAlertService.instance.testAlert();
                      //       }
                      //     },
                      //   );
                      // }),
                    ],
                  ),
                ),

                // FCM Token Card for backend test integration (Debug mode and flag enabled only)
                if (kDebugMode && kShowDebugFcmCard) ...[
                  const SizedBox(height: 24),
                  const FcmTokenCard(margin: EdgeInsets.zero),
                ],

                const SizedBox(height: 24),

                // Log Out Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: controller.logOut,
                    icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                    label: const AutoSizeText(
                      'Log Out',
                      maxLines: 1,
                      minFontSize: 12,
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildVehicleIcon(VehicleInfo vehicle) {
    if (vehicle.imageUrl != null && vehicle.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          vehicle.imageUrl!,
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _getFallbackVehicleIcon(vehicle),
        ),
      );
    }
    return _getFallbackVehicleIcon(vehicle);
  }

  Widget _getFallbackVehicleIcon(VehicleInfo vehicle) {
    final name = (vehicle.type.isNotEmpty ? vehicle.type : vehicle.model).toLowerCase();
    IconData iconData = Icons.directions_car_rounded;
    if (name.contains('moter') || name.contains('motor') || name.contains('bike')) {
      iconData = Icons.two_wheeler_rounded;
    } else if (name.contains('bajaj')) {
      iconData = Icons.electric_rickshaw_rounded;
    } else if (name.contains('truck') ||
        name.contains('isuzu') ||
        name.contains('lowbed') ||
        name.contains('pick up') ||
        name.contains('pickup')) {
      iconData = Icons.local_shipping_rounded;
    }
    return Icon(
      iconData,
      color: AppColors.primary,
      size: 22,
    );
  }
}
