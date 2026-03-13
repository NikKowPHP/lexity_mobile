import 'package:flutter/material.dart';
import 'liquid_components.dart';

class TutorChatDialog extends StatefulWidget {
  final String title;
  final Future<String> Function(String message, List<Map<String, String>> history) onSendMessage;
  
  const TutorChatDialog({super.key, required this.title, required this.onSendMessage});

  @override
  State<TutorChatDialog> createState() => _TutorChatDialogState();
}

class _TutorChatDialogState extends State<TutorChatDialog> {
  final List<Map<String, String>> _history = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  void _send() async {
    if (_controller.text.isEmpty || _isLoading) return;
    final userMsg = _controller.text;
    setState(() {
      _history.add({'role': 'user', 'content': userMsg});
      _isLoading = true;
      _controller.clear();
    });
    
    _scrollToBottom();

    try {
      final response = await widget.onSendMessage(userMsg, _history);
      setState(() {
        _history.add({'role': 'assistant', 'content': response});
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _history.add({'role': 'assistant', 'content': "Lexi is having a moment. Please try again later."});
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title, 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(color: Colors.white10),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _history.length,
                  itemBuilder: (c, i) => _ChatBubble(msg: _history[i]),
                ),
              ),
            ),
            if (_isLoading) 
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation<Color>(Colors.indigoAccent)),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: GlassInput(hint: "Ask Lexi...", controller: _controller)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send, 
                  icon: const Icon(Icons.send, color: Colors.indigoAccent),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.indigoAccent.withOpacity(0.1),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Map<String, String> msg;
  const _ChatBubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.indigoAccent.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          border: Border.all(color: isUser ? Colors.indigoAccent.withOpacity(0.3) : Colors.white10),
        ),
        child: Text(
          msg['content']!, 
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
      ),
    );
  }
}
