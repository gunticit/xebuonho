import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/app_models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <ChatMessage>[
    ChatMessage(id: '1', text: 'Xin chào! Tôi đang trên đường đến.', isMe: false, time: DateTime.now().subtract(const Duration(minutes: 3))),
    ChatMessage(id: '2', text: 'Tôi đang ở cổng chính nhé', isMe: true, time: DateTime.now().subtract(const Duration(minutes: 2))),
    ChatMessage(id: '3', text: 'Vâng, tôi thấy rồi. Khoảng 2 phút nữa tôi đến.', isMe: false, time: DateTime.now().subtract(const Duration(minutes: 1))),
  ];

  final _quickActions = [
    'Tôi đang chờ ở đây',
    'Bạn ở đâu rồi?',
    'Đợi tôi 2 phút',
    'Cảm ơn bạn!',
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(id: 'u${_messages.length}', text: text, isMe: true, time: DateTime.now()));
      _msgCtrl.clear();
    });
    _scrollToBottom();

    // Simulate driver reply
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final replies = ['Vâng ạ 👍', 'OK, tôi biết rồi', 'Được ạ, không vấn đề gì', 'Tôi đang đến đây'];
      setState(() {
        _messages.add(ChatMessage(
          id: 'd${_messages.length}',
          text: replies[DateTime.now().millisecond % replies.length],
          isMe: false,
          time: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('🧑', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nguyễn Văn B', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Đang hoạt động', style: TextStyle(fontSize: 11, color: AppColors.green)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.phone, color: AppColors.green, size: 22), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessage(_messages[i]),
            ),
          ),

          // Quick actions
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _quickActions.map((a) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _send(a),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bg2, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(a, style: const TextStyle(fontSize: 13, color: AppColors.blue, fontWeight: FontWeight.w500)),
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 24),
            decoration: const BoxDecoration(
              color: AppColors.bg2,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: AppColors.text, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Nhắn tin...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(_msgCtrl.text),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!msg.isMe) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('🧑', style: TextStyle(fontSize: 14))),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: msg.isMe ? AppColors.blue : AppColors.bg2,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
                bottomRight: Radius.circular(msg.isMe ? 4 : 16),
              ),
              border: msg.isMe ? null : Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(msg.text, style: TextStyle(fontSize: 14, color: msg.isMe ? Colors.white : AppColors.text)),
                const SizedBox(height: 2),
                Text(
                  '${msg.time.hour}:${msg.time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 10, color: msg.isMe ? Colors.white70 : AppColors.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
