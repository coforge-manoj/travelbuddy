import 'package:flutter/material.dart';

/// The bottom composer bar: text field, mic button (voice input), and send
/// button. Voice wiring itself lands in Phase 11 — [onMicPressed] is a stub
/// hook until then so the layout doesn't shift once voice ships.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onMicPressed,
    this.isListening = false,
    this.enabled = true,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onMicPressed;
  final bool isListening;
  final bool enabled;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();

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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: widget.isListening ? 'Stop listening' : 'Voice input',
              onPressed: widget.enabled ? widget.onMicPressed : null,
              icon: Icon(widget.isListening ? Icons.mic : Icons.mic_none),
              color: widget.isListening ? Theme.of(context).colorScheme.error : null,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'Ask about your flight, seat, or baggage…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: widget.enabled ? _submit : null,
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}
