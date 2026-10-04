import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'rider';
  bool _isRegister = false;
  bool _showPassword = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();

    if (_phoneController.text.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số điện thoại không hợp lệ'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu tối thiểu 6 ký tự'), backgroundColor: Colors.red),
      );
      return;
    }

    bool success;
    if (_isRegister) {
      if (_nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập họ tên'), backgroundColor: Colors.red),
        );
        return;
      }
      success = await auth.register(
        phone: _phoneController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
        role: _selectedRole,
      );
    } else {
      success = await auth.login(
        phone: _phoneController.text,
        password: _passwordController.text,
      );
    }

    if (success && mounted) {
      if (_isRegister) {
        Navigator.pushReplacementNamed(context, '/otp');
      } else {
        if (auth.isDriver) {
          Navigator.pushReplacementNamed(context, '/driver');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    }
  }

  void _demoLogin(String role) {
    final auth = context.read<AuthProvider>();
    auth.demoLogin(role: role);
    if (role == 'driver') {
      Navigator.pushReplacementNamed(context, '/driver');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                // Logo
                Center(
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.blueBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.blue.withValues(alpha: 0.3), width: 2),
                    ),
                    child: const Center(child: Text('🏍️', style: TextStyle(fontSize: 40))),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text('Xebuonho', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.text, letterSpacing: -1)),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _isRegister ? 'Tạo tài khoản mới' : 'Đăng nhập để đặt xe',
                    style: const TextStyle(fontSize: 14, color: AppColors.text3),
                  ),
                ),
                const SizedBox(height: 40),

                // Toggle tabs
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _buildTab('Đăng nhập', !_isRegister),
                      _buildTab('Đăng ký', _isRegister),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Role selection (register only)
                if (_isRegister) ...[
                  _buildLabel('Vai trò đăng ký'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'rider'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'rider' ? AppColors.blueBg : AppColors.bg2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedRole == 'rider' ? AppColors.blue : AppColors.border,
                                width: _selectedRole == 'rider' ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person, size: 18, color: _selectedRole == 'rider' ? AppColors.blue : AppColors.text3),
                                const SizedBox(width: 6),
                                Text(
                                  'Khách hàng',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedRole == 'rider' ? AppColors.blue : AppColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'driver'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'driver' ? AppColors.orangeBg : AppColors.bg2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedRole == 'driver' ? AppColors.orange : AppColors.border,
                                width: _selectedRole == 'driver' ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.drive_eta, size: 18, color: _selectedRole == 'driver' ? AppColors.orange : AppColors.text3),
                                const SizedBox(width: 6),
                                Text(
                                  'Tài xế lái xe',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedRole == 'driver' ? AppColors.orange : AppColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Name field (register only)
                if (_isRegister) ...[
                  _buildLabel('Họ và tên'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.text),
                    decoration: const InputDecoration(
                      hintText: 'Nguyễn Văn A',
                      prefixIcon: Icon(Icons.person_outline, color: AppColors.text3),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Phone field
                _buildLabel('Số điện thoại'),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppColors.text),
                  decoration: const InputDecoration(
                    hintText: '0901234567',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppColors.text3),
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                _buildLabel('Mật khẩu'),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: '••••••',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.text3),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _showPassword = !_showPassword),
                      child: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.text3, size: 20,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),

                // Error message
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
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

                // Submit button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            _isRegister ? 'Tạo tài khoản' : 'Đăng nhập',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.border)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('hoặc', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                    ),
                    Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),

                const SizedBox(height: 16),

                // Dual Demo login buttons (Rider vs Driver)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _demoLogin('rider'),
                        icon: const Text('🙋‍♂️', style: TextStyle(fontSize: 16)),
                        label: const Text(
                          'Khách (Demo)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blue),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.blue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _demoLogin('driver'),
                        icon: const Text('🚕', style: TextStyle(fontSize: 16)),
                        label: const Text(
                          'Tài xế (Demo)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.orange),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.orange),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _isRegister = label == 'Đăng ký';
          context.read<AuthProvider>().clearError();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.text3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2));
  }
}
