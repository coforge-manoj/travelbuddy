import 'package:flutter/material.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';

/// Terminal / counter / gate summary plus step-by-step walking directions.
/// The indoor map itself is a placeholder — see [AirportInfo.indoorMapAssetPath].
class AirportInfoCard extends StatelessWidget {
  const AirportInfoCard({super.key, required this.info});

  final AirportInfo info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget stat(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
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
                Icon(Icons.map, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Getting to your gate', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                stat('Terminal', info.terminal),
                stat('Counter', info.checkInCounter),
                stat('Gate', info.gate),
                stat('Walk time', '${info.walkingTimeMinutes} min'),
              ],
            ),
            if (info.directions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              for (var i = 0; i < info.directions.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}.', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 6),
                      Expanded(
                        child:
                            Text(info.directions[i], style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
            if (info.indoorMapAssetPath == null) ...[
              const SizedBox(height: 8),
              Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Indoor map placeholder',
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
