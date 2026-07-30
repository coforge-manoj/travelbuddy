import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/theme/app_theme.dart';

/// The bottom composer bar, styled to match the landing screen's pill-shaped
/// surfaces: a rounded text field with a mic/send toggle inside it, plus a
/// "tap mic to speak" hint.
///
/// When [showReturnToVoice] is true (talkback on, temporary typing), a voice
/// icon sits beside the field so the passenger can jump back to the orb.
///
/// [dictationText] / [dictationRevision] mirror live speech-to-text from the
/// composer mic into the field so the passenger can edit before sending.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onMicPressed,
    this.isListening = false,
    this.enabled = true,
    this.showReturnToVoice = false,
    this.onReturnToVoice,
    this.dictationText = '',
    this.dictationRevision = 0,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onMicPressed;
  final bool isListening;
  final bool enabled;
  final bool showReturnToVoice;
  final VoidCallback? onReturnToVoice;
  final String dictationText;
  final int dictationRevision;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;
  int _appliedDictationRevision = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void didUpdateWidget(covariant MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dictationRevision != _appliedDictationRevision) {
      _appliedDictationRevision = widget.dictationRevision;
      final text = widget.dictationText;
      if (_controller.text != text) {
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }
  }

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ChatColors.bar(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.showReturnToVoice) ...[
                    IconButton(
                      tooltip: 'Return to voice',
                      onPressed: widget.enabled ? widget.onReturnToVoice : null,
                      icon: const Icon(Icons.graphic_eq_rounded, color: AppTheme.brandBlue),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: widget.enabled,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1B1F27) : const Color(0xFFF5F7FA),
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        suffixIcon: IconButton(
                          tooltip: widget.isListening
                              ? 'Stop listening'
                              : (_hasText ? 'Send' : 'Voice input'),
                          // While listening, keep the mic as stop even if
                          // dictation has already filled the field.
                          onPressed: !widget.enabled
                              ? null
                              : (widget.isListening
                                  ? widget.onMicPressed
                                  : (_hasText ? _submit : widget.onMicPressed)),
                          icon: Icon(
                            widget.isListening
                                ? Icons.mic
                                : (_hasText ? Icons.arrow_upward : Icons.mic_none),
                            color: widget.isListening
                                ? Theme.of(context).colorScheme.error
                                : AppTheme.brandBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_none, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    widget.isListening
                        ? 'Listening… edit before sending'
                        : 'Tap mic to dictate, then send',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
