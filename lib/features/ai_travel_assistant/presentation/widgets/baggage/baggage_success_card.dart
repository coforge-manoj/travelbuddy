import 'package:flutter/material.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';

/// Confirmation card shown after a baggage purchase attempt (success or
/// failure — e.g. a declined payment surfaces here with the same shape).
class BaggageSuccessCard extends StatelessWidget {
  const BaggageSuccessCard({super.key, required this.purchase});

  final BaggagePurchase purchase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSuccess = purchase.status == BaggagePurchaseStatus.success;
    final onColor = isSuccess ? scheme.onPrimaryContainer : scheme.onErrorContainer;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isSuccess ? scheme.primaryContainer : scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(isSuccess ? Icons.check_circle : Icons.error_outline, size: 18, color: onColor),
                const SizedBox(width: 8),
                Text(
                  isSuccess ? 'Baggage confirmed' : 'Purchase failed',
                  style:
                      Theme.of(context).textTheme.labelLarge?.copyWith(color: onColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '+${purchase.option.extraWeightKg.toStringAsFixed(0)} kg · '
              '${purchase.option.price.toStringAsFixed(0)} ${purchase.option.currency}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: onColor),
            ),
            if (purchase.confirmationCode != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Confirmation: ${purchase.confirmationCode}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
