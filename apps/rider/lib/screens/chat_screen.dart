import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <ChatMessage>[];
  Timer? _pollTimer;
  String? _rideId;
  String _peerName = 'Tài xế';
  bool _isSending = false;
  String? _error;

  final _quickActions = [
    'Tôi đang chờ ở đây',
    'Bạn ở đâu rồi?',
    'Đợi tôi 2 phút',
    'Cảm ơn bạn!',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _rideId = args['rideId']?.toString();
        final peer = args['peerName']?.toString();
        if (peer != null && peer.isNotEmpty) _peerName = peer;
      }
      if (_rideId != null && _rideId!.isNotEmpty) {
        _loadMessages();
        _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages());
      } else {
        setState(() {
          _error = 'Không tìm thấy chuyến đi để chat. Hãy bắt đầu chuyến đi trước.';
        });
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _isDriver => context.read<AuthProvider>().isDriver;

  Future<void> _loadMessages() async {
    if (_rideId == null || _rideId!.isEmpty) return;
    try {
      final rows = await ApiService().getRideMessages(_rideId!);
      if (!mounted) return;
      setState(() {
        _error = null;
        _messages
          ..clear()
          ..addAll(rows.map((m) {
            final myRole = _isDriver ? 'driver' : 'rider';
            return ChatMessage(
              id: m['id']?.toString() ?? '',
              text: m['message']?.toString() ?? '',
              isMe: m['sender_role']?.toString() == myRole,
              time: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
            );
          }));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      // Chỉ báo lỗi khi chưa có gì hiển thị (đơn không thuộc về mình / chưa nhận)
      if (_messages.isEmpty) {
        setState(() {
          _error = 'Không tải được tin nhắn. Chỉ khách và tài xế của chuyến này được chat.';
        });
      }
    }
  }

  Future<void> _send(String text) async {
    if (text.isEmpty || _rideId == null || _isSending) return;
    setState(() => _isSending = true);
    _msgCtrl.clear();
    try {
      await ApiService().sendRideMessage(_rideId!, text);
      await _loadMessages();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.card),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không gửi được tin nhắn, thử lại.'), backgroundColor: AppColors.card),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.flag, color: AppColors.orange, size: 22),
          const SizedBox(width: 8),
          Text('Báo cáo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportOption('Quấy rối, đe dọa'),
            _buildReportOption('Nội dung không phù hợp'),
            _buildReportOption('Spam, lừa đảo'),
            _buildReportOption('Lý do khác'),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOption(String reason) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Đã gửi báo cáo: $reason'), backgroundColor: AppColors.green),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(child: Text(reason, style: TextStyle(fontSize: 14, color: AppColors.text))),
            Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Chặn $_peerName?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
        content: Text('Người này sẽ không thể nhắn tin cho bạn.', style: TextStyle(fontSize: 14, color: AppColors.text3)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy', style: TextStyle(color: AppColors.text3))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🚫 Đã chặn $_peerName'), backgroundColor: AppColors.red),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Chặn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_peerName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                const Text('Đang hoạt động', style: TextStyle(fontSize: 11, color: AppColors.green)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.phone, color: AppColors.green, size: 22), onPressed: () {}),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.text2),
            color: AppColors.bg2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'report') {
                _showReportDialog();
              } else if (value == 'block') {
                _showBlockDialog();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'report', child: Row(children: [
                Icon(Icons.flag, color: AppColors.orange, size: 18),
                const SizedBox(width: 8),
                Text('Báo cáo', style: TextStyle(color: AppColors.text)),
              ])),
              PopupMenuItem(value: 'block', child: Row(children: [
                Icon(Icons.block, color: AppColors.red, size: 18),
                const SizedBox(width: 8),
                Text('Chặn người dùng', style: TextStyle(color: AppColors.red)),
              ])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages / empty / error
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppColors.text3, height: 1.5)),
                    ),
                  )
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Chưa có tin nhắn nào. Hãy chào tài xế!',
                            style: TextStyle(fontSize: 13, color: AppColors.text3)),
                      )
                    : ListView.builder(
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
