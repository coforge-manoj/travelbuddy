import 'package:flutter/material.dart';

/// The bottom composer bar, styled to match the landing screen's pill-shaped
/// surfaces: a rounded text field with a mic/send toggle inside it, plus a
/// "tap mic to speak" hint.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onMicPressed,
    this.onAudioModePressed,
    this.isListening = false,
    this.enabled = true,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onMicPressed;

  /// Opens the hands-free conversation, as a leading icon on the field.
  ///
  /// Distinct from [onMicPressed], which stays exactly as it was: the trailing
  /// mic dictates one message, this one starts a conversation that keeps
  /// listening on its own.
  ///
  /// Nullable, and the icon only appears when it is set — the concierge demo
  /// shares this composer and has no audio mode, so it simply doesn't pass one
  /// rather than being given a button that does nothing.
  final VoidCallback? onAudioModePressed;

  final bool isListening;
  final bool enabled;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  static const _brandBlue = Color(0xFF0883F9);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
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
        color: isDark ? const Color(0xFF14171C) : Colors.white,
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
              TextField(
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
                  // Tightened from 20 because the leading icon already insets
                  // the text; at 20 the hint sat too far from the field edge.
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: widget.onAudioModePressed == null ? 20 : 8,
                    vertical: 12,
                  ),
                  prefixIcon: widget.onAudioModePressed == null
                      ? null
                      : IconButton(
                          tooltip: 'Voice mode',
                          onPressed: widget.enabled
                              ? widget.onAudioModePressed
                              : null,
                          icon: const Icon(Icons.graphic_eq, color: _brandBlue),
                        ),
                  suffixIcon: IconButton(
                    tooltip: _hasText
                        ? 'Send'
                        : (widget.isListening ? 'Stop listening' : 'Voice input'),
                    onPressed: widget.enabled ? (_hasText ? _submit : widget.onMicPressed) : null,
                    icon: Icon(
                      _hasText
                          ? Icons.arrow_upward
                          : (widget.isListening ? Icons.mic : Icons.mic_none),
                      color: widget.isListening
                          ? Theme.of(context).colorScheme.error
                          : _brandBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_none, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    widget.isListening ? 'Listening…' : 'Tap mic to speak',
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
