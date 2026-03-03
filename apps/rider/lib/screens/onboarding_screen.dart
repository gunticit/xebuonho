import 'package:flutter/material.dart';
import '../config/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  final _pages = [
    {'emoji': '🏍️', 'title': 'Đặt xe dễ dàng', 'desc': 'Chỉ cần nhập điểm đến, tài xế sẽ đến đón bạn trong vài phút', 'color': AppColors.blue},
    {'emoji': '🍔', 'title': 'Giao đồ ăn nhanh', 'desc': 'Đặt món yêu thích từ hàng ngàn nhà hàng, giao tận nơi 30 phút', 'color': AppColors.orange},
    {'emoji': '🛡️', 'title': 'An toàn tuyệt đối', 'desc': 'Chia sẻ chuyến đi, nút SOS 24/7, bảo hiểm mỗi chuyến', 'color': AppColors.green},
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
              child: TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Bỏ qua', style: TextStyle(color: AppColors.text3, fontSize: 14)),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated icon
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (_, v, child) => Transform.scale(scale: v, child: child),
                          child: Container(
                            width: 140, height: 140,
                            decoration: BoxDecoration(
                              color: (p['color'] as Color).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(color: (p['color'] as Color).withValues(alpha: 0.25), width: 2),
                              boxShadow: [BoxShadow(color: (p['color'] as Color).withValues(alpha: 0.15), blurRadius: 40, spreadRadius: 10)],
                            ),
                            child: Center(child: Text(p['emoji'] as String, style: const TextStyle(fontSize: 64))),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(p['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.text)),
                        const SizedBox(height: 12),
                        Text(p['desc'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: AppColors.text3, height: 1.5)),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots & button
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == i ? AppColors.blue : AppColors.bg3,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const SizedBox(height: 32),

                  // Button
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < 2) {
                          _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
                        } else {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _currentPage < 2 ? 'Tiếp tục' : 'Bắt đầu ngay',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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
