import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/app_icons.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  final _pages = [
    {
      'icon': AppIcons.bike,
      'title': 'Đặt xe dễ dàng',
      'desc': 'Chỉ cần nhập điểm đến, tài xế sẽ đến đón bạn trong vài phút với cước phí minh bạch',
      'color': AppColors.blue,
    },
    {
      'icon': AppIcons.food,
      'title': 'Giao đồ ăn nhanh',
      'desc': 'Đặt món yêu thích từ hàng ngàn nhà hàng uy tín, giao tận tay trong 30 phút',
      'color': AppColors.orange,
    },
    {
      'icon': AppIcons.shield,
      'title': 'An toàn & Lái xe hộ',
      'desc': 'Tài xế chuyên nghiệp lái xe đưa bạn về nhà, hỗ trợ nút SOS 24/7 an tâm tuyệt đối',
      'color': AppColors.green,
    },
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: Text('Bỏ qua', style: AppTextStyles.body2.copyWith(color: AppColors.text3)),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  final color = p['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated modern icon container
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (_, v, child) => Transform.scale(scale: v, child: child),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color.withValues(alpha: 0.25),
                                  color.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(44),
                              border: Border.all(
                                color: color.withValues(alpha: 0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.25),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                p['icon'] as IconData,
                                size: 68,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          p['title'] as String,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.heading1.copyWith(fontSize: 26),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          p['desc'] as String,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body1.copyWith(
                            color: AppColors.text2,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots & button
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 0, 36, 40),
              child: Column(
                children: [
                  // Modern Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 32 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? AppColors.blue : AppColors.bg3,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: _currentPage == i
                              ? [
                                  BoxShadow(
                                    color: AppColors.blue.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Button with gradient
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < 2) {
                          _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                          );
                        } else {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        elevation: 4,
                        shadowColor: AppColors.blue.withValues(alpha: 0.4),
                      ),
                      child: Text(
                        _currentPage < 2 ? 'Tiếp tục' : 'Bắt đầu ngay',
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
