import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/incoming_job_offer.dart';
import '../../../services/order_alert_service.dart';

class IncomingJobOfferSheet extends StatelessWidget {
  final IncomingJobOffer offer;
  final int remainingSeconds;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const IncomingJobOfferSheet({
    super.key,
    required this.offer,
    required this.remainingSeconds,
    required this.onAccept,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final progress = (remainingSeconds / offer.totalDurationSeconds).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: borderCol, width: 1.5),
          left: BorderSide(color: borderCol, width: 1.5),
          right: BorderSide(color: borderCol, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Top Header Row with responsive wrap (Surge badge, Status, Mute toggle, Rating)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Left badges group (Surge, Order Placed, Service)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (offer.surgeMultiplier > 1.0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.keyboard_double_arrow_up_rounded,
                              color: Colors.white, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            '${offer.surgeMultiplier}x High demand',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Status 0: Order Placed badge (before accept)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6366F1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Order Placed',
                          style: TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (offer.serviceCategory.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        offer.serviceCategory,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),

              // Right action & customer rating group
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Ringer audio & vibration status / Quick Mute
                  Obx(() {
                    final isRinging = OrderAlertService.instance.isRinging.value;
                    return InkWell(
                      onTap: () {
                        if (isRinging) {
                          OrderAlertService.instance.stopRinging();
                        } else {
                          OrderAlertService.instance.startRinging();
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: isRinging
                              ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isRinging ? const Color(0xFFEF4444) : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isRinging ? Icons.ring_volume_rounded : Icons.volume_off_rounded,
                              size: 14,
                              color: isRinging ? const Color(0xFFEF4444) : AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isRinging ? 'Ringing' : 'Muted',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isRinging ? const Color(0xFFEF4444) : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Passenger rating
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_rounded, size: 14),
                        const SizedBox(width: 3),
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.starGold),
                        const SizedBox(width: 2),
                        Text(
                          offer.customerRating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Cash Fare Badge (Photo 4)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments_rounded, color: AppColors.onlineGreen, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${offer.paymentMethod}  –  ETB ${offer.fareAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Countdown Timer Label & Progress Bar (Shrinking)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Incoming Dispatch Offer',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Text(
                'Auto-pass in ${remainingSeconds >= 60 ? "${remainingSeconds ~/ 60}m ${(remainingSeconds % 60).toString().padLeft(2, '0')}s" : "${remainingSeconds}s"}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: progress > 0.25 ? AppColors.onlineGreen : AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.25 ? AppColors.onlineGreen : AppColors.secondary,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Route: Pickup and Dropoff Timeline (Photo 4)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dots and connecting line
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.onlineGreen, width: 3),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 28,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.secondary, width: 3),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Addresses
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.pickupName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      offer.dropoffName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Drop-off time and distance (Photo 4)
          Text(
            'Drop-off time',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${offer.dropoffMinutes} minutes • ${offer.distanceKm} km',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons: "Let it pass" (Decline) & "Accept job" (Primary AMN Blue)
          Row(
            children: [
              // 1. Let it pass
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text(
                    'Let it pass',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Accept job
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Accept job',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
