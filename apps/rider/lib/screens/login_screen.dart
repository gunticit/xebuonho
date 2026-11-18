import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/app_icons.dart';
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
  String _driverKind = 'personal'; // personal | business (chỉ khi role = driver)
  bool _isRegister = false;
  bool _showPassword = false;
  bool _termsAccepted = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
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
        const SnackBar(content: Text('Số điện thoại không hợp lệ'), backgroundColor: AppColors.red),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu tối thiểu 6 ký tự'), backgroundColor: AppColors.red),
      );
      return;
    }

    bool success;
    if (_isRegister) {
      if (_nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập họ tên'), backgroundColor: AppColors.red),
        );
        return;
      }
      if (!_termsAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đồng ý với Điều khoản và Chính sách bảo vệ dữ liệu (NĐ 13/2023/NĐ-CP)'),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }
      success = await auth.register(
        phone: _phoneController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
        role: _selectedRole,
        driverKind: _driverKind,
        consentAccepted: _termsAccepted,
        consentVersion: '2026.1',
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
        if (auth.isAdmin) {
          Navigator.pushReplacementNamed(context, '/admin');
        } else if (auth.isDriver) {
          Navigator.pushReplacementNamed(context, '/driver');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
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
                const SizedBox(height: 48),

                // Modern Logo
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blue.withValues(alpha: 0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(AppIcons.bike, size: 44, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'Xebuonho',
                    style: AppTextStyles.heading1.copyWith(
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _isRegister ? 'Tạo tài khoản thành viên mới' : 'Đăng nhập vào hệ thống',
                    style: AppTextStyles.body2,
                  ),
                ),
                const SizedBox(height: 32),

                // Toggle tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: _selectedRole == 'rider' ? AppColors.blue : AppColors.border,
                                width: _selectedRole == 'rider' ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(AppIcons.profile, size: 18, color: _selectedRole == 'rider' ? AppColors.blue : AppColors.text3),
                                const SizedBox(width: 8),
                                Text(
                                  'Khách hàng',
                                  style: AppTextStyles.body1.copyWith(
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
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: _selectedRole == 'driver' ? AppColors.orange : AppColors.border,
                                width: _selectedRole == 'driver' ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(AppIcons.car, size: 18, color: _selectedRole == 'driver' ? AppColors.orange : AppColors.text3),
                                const SizedBox(width: 8),
                                Text(
                                  'Tài xế lái xe',
                                  style: AppTextStyles.body1.copyWith(
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
                  if (_selectedRole == 'driver') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildDriverKindChip('personal', AppIcons.bike, 'Cá nhân', 'Xe máy / xe cá nhân')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildDriverKindChip('business', AppIcons.car, 'Doanh nghiệp', 'Xe ô tô hợp đồng')),
                        ],
                      ),
                    ),
                  ],
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
                      prefixIcon: Icon(AppIcons.profile, color: AppColors.text3, size: 20),
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
                    prefixIcon: Icon(AppIcons.call, color: AppColors.text3, size: 20),
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
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.text3, size: 20),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _showPassword = !_showPassword),
                      child: Icon(
                        _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.text3,
                        size: 20,
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
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(auth.error!, style: AppTextStyles.body2.copyWith(color: AppColors.red))),
                      ],
                    ),
                  ),
                ],

                // PDPD Decree 13/2023/ND-CP Consent checkbox (register only)
                if (_isRegister) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: _termsAccepted ? AppColors.green.withValues(alpha: 0.5) : AppColors.border,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _termsAccepted,
                            activeColor: AppColors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) {
                              setState(() => _termsAccepted = val ?? false);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _termsAccepted = !_termsAccepted);
                            },
                            child: RichText(
                              text: TextSpan(
                                style: AppTextStyles.caption.copyWith(color: AppColors.text2, height: 1.4),
                                children: [
                                  const TextSpan(text: 'Tôi đồng ý với '),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pushNamed(context, '/terms'),
                                      child: const Text(
                                        'Điều khoản sử dụng',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.blue,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ' & '),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pushNamed(context, '/privacy'),
                                      child: const Text(
                                        'Chính sách bảo vệ DLCN (NĐ 13/2023/NĐ-CP)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.blue,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Submit button with gradient
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      elevation: 4,
                      shadowColor: AppColors.green.withValues(alpha: 0.35),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            _isRegister ? 'Tạo tài khoản' : 'Đăng nhập',
                            style: AppTextStyles.button,
                          ),
                  ),
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverKindChip(String kind, IconData icon, String label, String subtitle) {
    final active = _driverKind == kind;
    return GestureDetector(
      onTap: () => setState(() => _driverKind = kind),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.orangeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: active ? AppColors.orange : AppColors.border, width: active ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: active ? AppColors.orange : AppColors.text2),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? AppColors.orange : AppColors.text2)),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 9, color: active ? AppColors.orange : AppColors.text3)),
          ],
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.text3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: AppTextStyles.label);
  }
}
