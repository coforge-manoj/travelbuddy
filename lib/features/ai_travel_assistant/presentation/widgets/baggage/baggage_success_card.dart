import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';

/// Confirmation card shown after a baggage purchase attempt (success or
/// failure — e.g. a declined payment surfaces here with the same shape).
/// While the guided post-booking flow is active, also offers "Add more
/// baggage" and "Finish" actions so the passenger can keep adding bags or
/// move on to the final itinerary.
class BaggageSuccessCard extends ConsumerStatefulWidget {
  const BaggageSuccessCard({super.key, required this.purchase});

  final BaggagePurchase purchase;

  @override
  ConsumerState<BaggageSuccessCard> createState() => _BaggageSuccessCardState();
}

class _BaggageSuccessCardState extends ConsumerState<BaggageSuccessCard> {
  bool _busy = false;

  Future<void> _addMore() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(chatViewModelProvider.notifier).addMoreBaggage();
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(chatViewModelProvider.notifier).finishBooking();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final purchase = widget.purchase;
    final isSuccess = purchase.status == BaggagePurchaseStatus.success;
    final onColor = isSuccess ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    final showActions = isSuccess &&
        ref.watch(chatViewModelProvider.select((state) => state.hasActiveBookingFlow));

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
            if (showActions) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: !_busy ? _addMore : null,
                    child: const Text('Add more baggage'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: !_busy ? _finish : null,
                    child: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Finish'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
