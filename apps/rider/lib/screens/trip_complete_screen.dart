import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/booking_provider.dart';
import 'package:intl/intl.dart';

class TripCompleteScreen extends StatefulWidget {
  const TripCompleteScreen({super.key});

  @override
  State<TripCompleteScreen> createState() => _TripCompleteScreenState();
}

class _TripCompleteScreenState extends State<TripCompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  int _rating = 5;
  int _tipAmount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmtVND(double amount) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    return '${fmt.format(amount)}đ';
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final fare = booking.fareEstimates[booking.vehicleType] ?? 50000;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Success animation
              AnimatedBuilder(
                animation: _scaleAnim,
                builder: (_, __) => Transform.scale(
                  scale: _scaleAnim.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.greenBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.green.withOpacity(0.3), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('✅', style: TextStyle(fontSize: 48)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Hoàn thành chuyến!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                booking.dropoffAddress,
                style: const TextStyle(fontSize: 14, color: AppColors.text3),
              ),
              const SizedBox(height: 24),

              // Fare card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('Tổng cước',
                        style: TextStyle(fontSize: 13, color: AppColors.text3)),
                    const SizedBox(height: 4),
                    Text(
                      _fmtVND(fare),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.green,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: AppColors.border),
                    const SizedBox(height: 8),
                    _buildFareRow('Cước cơ bản', _fmtVND(fare * 0.7)),
                    _buildFareRow('Phí di chuyển', _fmtVND(fare * 0.25)),
                    _buildFareRow('Phí nền tảng', _fmtVND(fare * 0.05)),
                    if (_tipAmount > 0)
                      _buildFareRow('Tip tài xế', _fmtVND(_tipAmount.toDouble()),
                          color: AppColors.orange),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Driver rating
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.blueBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('👤', style: TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nguyễn Văn Tài',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text)),
                            Text('51F-123.45 · ⭐ 4.9',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.text3)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Đánh giá tài xế',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.text2)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        return GestureDetector(
                          onTap: () => setState(() => _rating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              i < _rating ? '⭐' : '☆',
                              style: TextStyle(
                                fontSize: i < _rating ? 32 : 28,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Tip buttons
                    const Text('Tip cho tài xế',
                        style: TextStyle(fontSize: 13, color: AppColors.text2)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [5000, 10000, 20000, 50000].map((amount) {
                        final selected = _tipAmount == amount;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _tipAmount = selected ? 0 : amount;
                          }),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.orangeBg
                                  : AppColors.bg3,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppColors.orange
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              _fmtVND(amount.toDouble()),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppColors.orange
                                    : AppColors.text2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Done button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    booking.reset();
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/home', (_) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Hoàn thành',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFareRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.text3)),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.text,
              )),
        ],
      ),
    );
  }
}
