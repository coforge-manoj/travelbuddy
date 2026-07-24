import 'package:flutter/material.dart';

/// The bottom composer bar: a rounded pill with a text field and an inline mic
/// button, plus a "Tap mic to speak" helper below. Voice mode 1 (dictation)
/// streams the live transcript in via [dictationText]; the passenger can edit
/// it before sending.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onMicPressed,
    this.onVoiceConversation,
    this.isListening = false,
    this.enabled = true,
    this.dictationText,
  });

  final ValueChanged<String> onSend;

  /// Voice mode 1: tap to dictate into the text field.
  final VoidCallback onMicPressed;

  /// Voice mode 2: tap to open the recording dialog for a full voice
  /// conversation. Hidden when null.
  final VoidCallback? onVoiceConversation;

  final bool isListening;
  final bool enabled;

  /// Live dictation transcript to mirror into the text field. Null when not
  /// dictating; when it changes to a new non-null value the field is updated.
  final String? dictationText;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void didUpdateWidget(covariant MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dictation = widget.dictationText;
    if (dictation != null &&
        dictation != oldWidget.dictationText &&
        dictation != _controller.text) {
      _controller.value = TextEditingValue(
        text: dictation,
        selection: TextSelection.collapsed(offset: dictation.length),
      );
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
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The rounded input pill (with an inline mic for voice-to-text)
            // sits next to a dedicated circular send button, WhatsApp-style.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? colorScheme.surfaceContainerHighest
                          : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    padding: const EdgeInsets.only(left: 20, right: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: widget.enabled,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              hintText: 'Type a message…',
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _micButton(colorScheme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _sendButton(colorScheme),
              ],
            ),
            const SizedBox(height: 8),
            // The "Tap mic to speak" helper opens the voice conversation dialog.
            InkWell(
              onTap: widget.enabled ? widget.onVoiceConversation : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mic_none,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap mic to speak',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inline mic inside the pill: dictates speech into the text field
  /// (voice-to-text). Turns red while actively listening.
  Widget _micButton(ColorScheme colorScheme) {
    return IconButton(
      tooltip: widget.isListening ? 'Stop listening' : 'Dictate',
      onPressed: widget.enabled ? widget.onMicPressed : null,
      icon: Icon(widget.isListening ? Icons.mic : Icons.mic_none),
      color: widget.isListening ? colorScheme.error : colorScheme.primary,
    );
  }

  /// Dedicated circular send button. Enabled only once the field has text.
  Widget _sendButton(ColorScheme colorScheme) {
    final active = widget.enabled && _hasText;
    return Material(
      color: active
          ? colorScheme.primary
          : colorScheme.primary.withValues(alpha: 0.3),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: active ? _submit : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            Icons.send_rounded,
            size: 22,
            color: colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
