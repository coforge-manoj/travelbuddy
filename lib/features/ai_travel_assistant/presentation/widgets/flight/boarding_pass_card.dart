import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/app_date.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/boarding_pass.dart';

/// The `boarding_pass` card. Laid out as a pass rather than a list of rows:
/// the passenger scans this at the gate, so seat, gate and group are the
/// three things that have to be readable at arm's length.
class BoardingPassCard extends StatelessWidget {
  const BoardingPassCard({super.key, required this.pass});

  final BoardingPass pass;

  static const _ink = Color(0xFF0A2A43);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flight_takeoff,
                          size: 18, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Boarding pass',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white70,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      if (pass.cabin.isNotEmpty)
                        Text(
                          pass.cabin,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: Colors.white70),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // The issued pass names the flight but not always the
                  // route, so the flight number takes the headline slot
                  // rather than the pass reading "— ✈ —".
                  if (pass.origin.isEmpty && pass.destination.isEmpty)
                    Text(
                      pass.flightNumber.isEmpty ? pass.pnr : pass.flightNumber,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _Airport(code: pass.origin, time: pass.departureTime),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(Icons.flight,
                                size: 18, color: Colors.white38),
                          ),
                        ),
                        _Airport(
                          code: pass.destination,
                          time: null,
                          alignEnd: true,
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (pass.flightNumber.isNotEmpty &&
                          (pass.origin.isNotEmpty || pass.destination.isNotEmpty))
                        pass.flightNumber,
                      if (pass.date != null) AppDate.formatRaw(pass.date)!,
                      if (pass.passengerName.isNotEmpty) pass.passengerName,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const _Perforation(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _PassField(label: 'Seat', value: pass.seat),
                      _PassField(label: 'Gate', value: pass.gate),
                      _PassField(label: 'Group', value: pass.boardingGroup),
                      _PassField(label: 'Boards', value: pass.boardingTime),
                    ],
                  ),
                  if (pass.terminal != null || pass.sequenceNumber != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      [
                        if (pass.terminal != null) 'Terminal ${pass.terminal}',
                        if (pass.sequenceNumber != null)
                          'Seq ${pass.sequenceNumber}',
                      ].join(' · '),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.white54),
                    ),
                  ],
                  if (pass.pnr.isNotEmpty || pass.barcode != null) ...[
                    const SizedBox(height: 12),
                    _BarcodeStrip(value: pass.barcode ?? pass.pnr),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        pass.pnr.isEmpty ? pass.barcode! : pass.pnr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Airport extends StatelessWidget {
  const _Airport({required this.code, required this.time, this.alignEnd = false});

  final String code;
  final String? time;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          code.isEmpty ? '—' : code,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
        ),
        if (time != null)
          Text(
            time!,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white70),
          ),
      ],
    );
  }
}

class _PassField extends StatelessWidget {
  const _PassField({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white54,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value ?? '—',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 6.0;
          final dashCount = (constraints.maxWidth / (dashWidth * 2)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              dashCount,
              (_) => Container(
                width: dashWidth,
                height: 1,
                color: Colors.white24,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A decorative stand-in for the scannable code — the real barcode payload
/// is on [BoardingPass.barcode] and is printed underneath, so nothing here
/// is load-bearing. Swap in a real symbology widget when one is available.
class _BarcodeStrip extends StatelessWidget {
  const _BarcodeStrip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final codeUnits = value.codeUnits;
          final barCount = (constraints.maxWidth / 3).floor();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(barCount, (i) {
              // Widths derived from the payload so two different passes do
              // not draw an identical strip.
              final unit = codeUnits.isEmpty
                  ? 1
                  : codeUnits[i % codeUnits.length];
              final isBar = unit % 3 != 0;
              return Container(
                width: isBar ? 2 : 1,
                margin: const EdgeInsets.only(right: 1),
                color: isBar ? Colors.black87 : Colors.transparent,
              );
            }),
          );
        },
      ),
    );
  }
}
