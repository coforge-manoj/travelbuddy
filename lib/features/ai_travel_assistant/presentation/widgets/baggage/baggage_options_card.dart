import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';

/// Lists purchasable extra-baggage options; tapping "Add" confirms the
/// purchase via [ChatViewModel.confirmBaggagePurchase].
class BaggageOptionsCard extends ConsumerStatefulWidget {
  const BaggageOptionsCard({super.key, required this.options});

  final List<BaggageOption> options;

  @override
  ConsumerState<BaggageOptionsCard> createState() => _BaggageOptionsCardState();
}

class _BaggageOptionsCardState extends ConsumerState<BaggageOptionsCard> {
  String? _purchasingOptionId;

  Future<void> _purchase(String optionId) async {
    if (_purchasingOptionId != null) return;
    setState(() => _purchasingOptionId = optionId);
    await ref.read(chatViewModelProvider.notifier).confirmBaggagePurchase(optionId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.luggage, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Extra baggage', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            for (final option in widget.options)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '+${option.extraWeightKg.toStringAsFixed(0)} kg',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${option.price.toStringAsFixed(0)} ${option.currency}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 84,
                      child: OutlinedButton(
                        onPressed:
                            _purchasingOptionId == null ? () => _purchase(option.id) : null,
                        child: _purchasingOptionId == option.id
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
