import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/constants.dart';
import '../../constants/pages.dart';
import '../../core/theme/app_colors.dart';
import '../../controllers/driver_auth_controller.dart';
import '../../models/country_code.dart';
import '../../services/driver_auth_service.dart';
import '../../widgets/common/country_code_dropdown.dart';
import '../../widgets/fcm_token_card.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _plateNumberController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  CountryCode _selectedCountry = CountryCode.defaultCountry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<DriverAuthController>()) {
        Get.find<DriverAuthController>().loadRegistrationMetadata();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  void _showVehicleImageSourceModal(BuildContext context, DriverAuthController authCtrl) {
    final vehicleName = authCtrl.selectedVehicle?.name ?? 'Vehicle';
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
                  'Upload Photo of your $vehicleName',
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
                    authCtrl.pickVehicleImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    authCtrl.pickVehicleImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onSignIn(DriverAuthController authCtrl) {
    final rawPhone = _phoneController.text.trim();
    final phone = DriverAuthService.sanitizePhone(rawPhone, _selectedCountry.dialCode);
    final password = _passwordController.text;
    if (rawPhone.isEmpty) {
      Get.snackbar('Required Field', 'Please enter your phone number',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (password.isEmpty) {
      Get.snackbar('Required Field', 'Please enter your password',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (password.length != 4 || !RegExp(r'^\d{4}$').hasMatch(password)) {
      Get.snackbar('Invalid Password', 'Password must be exactly 4 digits',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    authCtrl.login(phone, password);
  }

  void _onSignUp(DriverAuthController authCtrl) {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final phone = DriverAuthService.sanitizePhone(rawPhone, _selectedCountry.dialCode);
    final password = _passwordController.text;
    final plateNumber = _plateNumberController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      Get.snackbar('Required Field', 'Please enter your full name',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (email.isNotEmpty && (!email.contains('@') || !email.contains('.'))) {
      Get.snackbar('Invalid Email', 'Please enter a valid email address or leave it blank',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (rawPhone.isEmpty) {
      Get.snackbar('Required Field', 'Please enter your phone number',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (password.length != 4 || !RegExp(r'^\d{4}$').hasMatch(password)) {
      Get.snackbar('Invalid Password', 'Password must be exactly 4 digits',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final cityId = authCtrl.selectedCityId.value;
    if (cityId == null || cityId <= 0) {
      Get.snackbar('Required Field', 'Please select your operating city',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final vehicleId = authCtrl.selectedVehicleId.value;
    if (vehicleId == null || vehicleId <= 0) {
      Get.snackbar('Required Field', 'Please select your vehicle type',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (plateNumber.isEmpty) {
      Get.snackbar('Required Field', 'Please enter your vehicle plate number',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (authCtrl.vehicleImagePath.value == null || authCtrl.vehicleImagePath.value!.isEmpty) {
      final vehicleName = authCtrl.selectedVehicle?.name ?? 'vehicle';
      Get.snackbar('Required Field', 'Please upload a photo of your $vehicleName',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    authCtrl.register(
      firstName: firstName,
      lastName: lastName,
      email: email.isNotEmpty ? email : null,
      phone: phone,
      password: password,
      vehicleId: vehicleId,
      cityId: cityId,
      plateNumber: plateNumber,
      carImagePath: authCtrl.vehicleImagePath.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textTheme = theme.textTheme;
    final authCtrl = Get.isRegistered<DriverAuthController>()
        ? Get.find<DriverAuthController>()
        : Get.put(DriverAuthController());

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. App Branding & Logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AutoSizeText(
                              kAppName,
                              maxLines: 1,
                              minFontSize: 18,
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            AutoSizeText(
                              kAppTagline,
                              maxLines: 1,
                              minFontSize: 10,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // FCM Token Card (Visible only when both kDebugMode and kShowDebugFcmCard are true)
                  if (kDebugMode && kShowDebugFcmCard) ...[
                    const FcmTokenCard(),
                    const SizedBox(height: 8),
                  ],

                  // 2. Tab Switcher (Sign In / Register)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isSignUp = false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isSignUp
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: AutoSizeText(
                                'Courier Sign In',
                                maxLines: 1,
                                minFontSize: 11,
                                style: TextStyle(
                                  color: !_isSignUp
                                      ? Colors.white
                                      : AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isSignUp = true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isSignUp
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: AutoSizeText(
                                'Register Driver',
                                maxLines: 1,
                                minFontSize: 11,
                                style: TextStyle(
                                  color: _isSignUp
                                      ? Colors.white
                                      : AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Form Inputs
                  if (_isSignUp) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'First Name',
                              prefixIcon: const Icon(Icons.person_outline, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Last Name',
                              prefixIcon: const Icon(Icons.person_outline, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address (Optional)',
                        hintText: 'driver@example.com',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Phone Input
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: _selectedCountry.dialCode == '+251'
                          ? '911234567 or 0911234567'
                          : 'Enter phone number',
                      prefixIcon: CountryCodeDropdown(
                        selectedCountry: _selectedCountry,
                        onChanged: (country) {
                          setState(() {
                            _selectedCountry = country;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Password Input
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Password (4-digit PIN)',
                      hintText: '4-digit PIN',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),

                  if (!_isSignUp) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Get.toNamed(Pages.forgotPassword, arguments: {
                            'phone': _phoneController.text.trim(),
                          });
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),

                    // City Dropdown Selector
                    Obx(() {
                      final cities = authCtrl.cities;
                      final selectedCity = authCtrl.selectedCityId.value;
                      final isLoading = authCtrl.isLoadingMetadata.value;
                      final validCityValue = cities.any((c) => c.id == selectedCity)
                          ? selectedCity
                          : null;

                      return DropdownButtonFormField<int>(
                        initialValue: validCityValue,
                        hint: Text(
                          isLoading && cities.isEmpty
                              ? 'Loading cities...'
                              : 'Select your city',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Operating City',
                          prefixIcon: const Icon(Icons.location_city_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        isExpanded: true,
                        items: cities.map((city) {
                          return DropdownMenuItem<int>(
                            value: city.id,
                            child: Text(
                              city.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          authCtrl.selectedCityId.value = val;
                        },
                      );
                    }),

                    const SizedBox(height: 18),

                    // Horizontally scrolling vehicle selection
                    Obx(() {
                      final vehicleTypes = authCtrl.vehicleTypes;
                      final selectedVehicleId = authCtrl.selectedVehicleId.value;
                      final isLoading = authCtrl.isLoadingMetadata.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Select Vehicle Type',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              if (isLoading && vehicleTypes.isEmpty)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (isLoading && vehicleTypes.isEmpty)
                            Container(
                              height: 118,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Loading vehicle types...',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          else if (vehicleTypes.isEmpty)
                            Container(
                              height: 118,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'No vehicle types available',
                                style: TextStyle(fontSize: 13),
                              ),
                            )
                          else
                            SizedBox(
                              height: 122,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: vehicleTypes.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final vehicle = vehicleTypes[index];
                                  final isSelected = vehicle.id == selectedVehicleId;

                                  return InkWell(
                                    onTap: () {
                                      authCtrl.selectedVehicleId.value = vehicle.id;
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 116,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primaryContainer.withValues(alpha: 0.35)
                                            : theme.cardColor,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.outline.withValues(alpha: 0.5),
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primary.withValues(alpha: 0.18),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                if (vehicle.image != null &&
                                                    vehicle.image!.isNotEmpty)
                                                  CachedNetworkImage(
                                                    imageUrl: Uri.encodeFull(vehicle.image!),
                                                    fit: BoxFit.contain,
                                                    width: 56,
                                                    height: 56,
                                                    placeholder: (context, url) => Center(
                                                      child: SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: AppColors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                    errorWidget: (context, url, error) => Icon(
                                                      Icons.two_wheeler_rounded,
                                                      size: 38,
                                                      color: isSelected
                                                          ? AppColors.primary
                                                          : AppColors.onSurfaceVariant,
                                                    ),
                                                  )
                                                else
                                                  Icon(
                                                    Icons.two_wheeler_rounded,
                                                    size: 38,
                                                    color: isSelected
                                                        ? AppColors.primary
                                                        : AppColors.onSurfaceVariant,
                                                  ),
                                                if (isSelected)
                                                  Positioned(
                                                    top: 0,
                                                    right: 0,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(2),
                                                      decoration: const BoxDecoration(
                                                        color: AppColors.primary,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.check,
                                                        size: 11,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            vehicle.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: 18),

                    // Plate Number Input Field
                    TextFormField(
                      controller: _plateNumberController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Plate Number',
                        hintText: 'e.g., AA 3-12345 or ET 2-98765',
                        prefixIcon: const Icon(Icons.pin_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Vehicle Photo / Car Image Picker
                    Obx(() {
                      final imagePath = authCtrl.vehicleImagePath.value;
                      final selectedVehicleName = authCtrl.selectedVehicle?.name ?? 'Vehicle';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: imagePath != null ? AppColors.primary : AppColors.outlineVariant,
                            width: imagePath != null ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Photo of your $selectedVehicleName',
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Upload a clear photo of your $selectedVehicleName',
                                        style: textTheme.bodySmall?.copyWith(
                                          fontSize: 11.5,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (imagePath != null)
                                  IconButton(
                                    icon: const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
                                    tooltip: 'Remove photo',
                                    onPressed: authCtrl.clearVehicleImage,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (imagePath != null && File(imagePath).existsSync())
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(imagePath),
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showVehicleImageSourceModal(context, authCtrl),
                                      icon: const Icon(Icons.edit_rounded, size: 14),
                                      label: const Text('Change', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black87,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              InkWell(
                                onTap: () => _showVehicleImageSourceModal(context, authCtrl),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 90,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 28),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tap to add $selectedVehicleName photo',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 18),
                  ],

                  const SizedBox(height: 12),

                  // 4. Primary Submit Button
                  Obx(() {
                    final loading = authCtrl.isLoading.value;
                    return ElevatedButton(
                      onPressed: loading
                          ? null
                          : () {
                              if (_isSignUp) {
                                _onSignUp(authCtrl);
                              } else {
                                _onSignIn(authCtrl);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : AutoSizeText(
                              _isSignUp
                                  ? 'Register & Get OTP'
                                  : 'Sign In to Driver App',
                              maxLines: 1,
                              minFontSize: 12,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // 6. Security notice
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 14, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Flexible(
                        child: AutoSizeText(
                          'AMN Dispatch 256-bit Encrypted Connection',
                          maxLines: 1,
                          minFontSize: 9,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
