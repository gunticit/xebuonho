import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _countdown = 60;
  Timer? _timer;
  bool _autoVerified = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < 6) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(_code);
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-verify when all 6 digits entered
    if (_code.length == 6 && !_autoVerified) {
      _autoVerified = true;
      _verify();
    } else if (_code.length < 6) {
      _autoVerified = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.bg3,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Icon(Icons.arrow_back, color: AppColors.text, size: 20)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Icon
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.greenBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Center(child: Text('📱', style: TextStyle(fontSize: 36))),
                ),
              ),
              const SizedBox(height: 20),

              const Center(
                child: Text('Xác minh số điện thoại',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Mã OTP đã gửi đến ${auth.userPhone}',
                  style: const TextStyle(fontSize: 14, color: AppColors.text3),
                ),
              ),
              const SizedBox(height: 36),

              // OTP input fields
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 48, height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      onChanged: (v) => _onChanged(index, v),
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: _controllers[index].text.isNotEmpty
                            ? AppColors.blueBg : AppColors.bg2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _controllers[index].text.isNotEmpty
                                ? AppColors.blue : AppColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _controllers[index].text.isNotEmpty
                                ? AppColors.blue : AppColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.blue, width: 2),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Error
              if (auth.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.redBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(auth.error!, style: const TextStyle(fontSize: 13, color: AppColors.red))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Verify button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Xác minh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),

              // Resend OTP
              Center(
                child: _countdown > 0
                    ? Text('Gửi lại mã sau ${_countdown}s',
                        style: const TextStyle(fontSize: 13, color: AppColors.text3))
                    : GestureDetector(
                        onTap: () {
                          auth.resendOtp();
                          _startCountdown();
                        },
                        child: const Text('Gửi lại mã OTP',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.blue)),
                      ),
              ),

              const SizedBox(height: 24),

              // Skip (demo)
              Center(
                child: GestureDetector(
                  onTap: () {
                    auth.skipOtp();
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  child: const Text('Bỏ qua (Demo) →',
                    style: TextStyle(fontSize: 13, color: AppColors.text3)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
