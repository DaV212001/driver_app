import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../core/theme/app_colors.dart';
import '../services/notification_service.dart';

/// A self-contained, reactive Card displaying the FCM Device Token for testing and backend integration.
/// Automatically updates in real-time when the token is refreshed or initialized.
/// Only renders in debug mode.
class FcmTokenCard extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const FcmTokenCard({
    super.key,
    this.margin = const EdgeInsets.only(bottom: 20),
  });

  void _copyToken(BuildContext context, String token) {
    Clipboard.setData(ClipboardData(text: token));
    HapticFeedback.lightImpact();
    Get.rawSnackbar(
      title: 'FCM Token Copied! 📋',
      message: 'Registered device token copied to clipboard for backend testing.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.onSurface,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen),
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Obx(() {
      final token = NotificationService.instance.fcmToken.value;
      final isFetching = NotificationService.instance.isFetchingToken.value;
      final hasToken = token != null && token.isNotEmpty;

      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasToken
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.outline,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: hasToken ? 0.08 : 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Icon + Title + Status Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cell_tower_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FCM Device Token',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'For backend push notification integration',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Live Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasToken
                          ? AppColors.onlineGreenBg
                          : AppColors.warningAmberBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: hasToken
                                ? AppColors.onlineGreen
                                : AppColors.warningAmber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          hasToken ? 'Live' : (isFetching ? 'Fetching...' : 'Pending'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: hasToken
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Token Display Box (Tap to Copy)
              InkWell(
                onTap: hasToken ? () => _copyToken(context, token) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: isFetching && !hasToken
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Requesting FCM registration token...',
                                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      : hasToken
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    token,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                      letterSpacing: 0.1,
                                    ),
                                    maxLines: 4,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ],
                            )
                          : const Text(
                              'Token unavailable. Ensure device has Google Play Services and tap refresh.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                ),
              ),

              const SizedBox(height: 12),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: hasToken ? () => _copyToken(context, token) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text(
                        'Copy Token',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: isFetching
                        ? null
                        : () => NotificationService.instance.refreshDeviceToken(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: isFetching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}
