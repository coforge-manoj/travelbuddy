import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/money_format.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/extras_catalogue.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/card_shell.dart';

/// The `extras_list` card: what can be added to this cabin, with the ones
/// the cabin already covers marked. Tapping a row adds it, by sending the
/// same sentence a passenger would have typed — the backend holds the
/// basket, so the chat turn is what does the work.
class ExtrasListCard extends StatelessWidget {
  const ExtrasListCard({
    super.key,
    required this.catalogue,
    required this.onAdd,
  });

  final ExtrasCatalogue catalogue;

  /// Called with the extra's display name.
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return CardShell(
      icon: Icons.add_shopping_cart_outlined,
      title: catalogue.cabin.isEmpty
          ? 'Extras'
          : 'Extras for ${catalogue.cabin}',
      children: [
        for (final extra in catalogue.extras)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        extra.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (extra.description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            extra.description!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.outline),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (extra.included)
                  const CardBadge(label: 'Included')
                else ...[
                  Text(
                    formatMoney(extra.price, catalogue.currency),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => onAdd(extra.name),
                    child: const Text('Add'),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
