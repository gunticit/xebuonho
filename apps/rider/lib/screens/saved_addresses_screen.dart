import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/app_models.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final _addresses = <SavedAddress>[
    SavedAddress(id: '1', name: 'Nhà', address: 'Landmark 81, Vinhomes Central Park, Bình Thạnh', lat: 10.7943, lng: 106.7218, type: AddressType.home),
    SavedAddress(id: '2', name: 'Công ty', address: 'Bitexco Tower, 2 Hải Triều, Q.1', lat: 10.7716, lng: 106.7045, type: AddressType.work),
    SavedAddress(id: '3', name: 'Phòng gym', address: 'California Fitness, Q.3', lat: 10.7838, lng: 106.6920, type: AddressType.favorite, emoji: '💪'),
    SavedAddress(id: '4', name: 'Quán cà phê', address: 'The Workshop, Q.1', lat: 10.7780, lng: 106.6960, type: AddressType.favorite, emoji: '☕'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Địa chỉ đã lưu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm địa chỉ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick set
            Row(
              children: [
                _buildQuickSet('🏠', 'Nhà', _addresses.any((a) => a.type == AddressType.home)),
                const SizedBox(width: 10),
                _buildQuickSet('🏢', 'Công ty', _addresses.any((a) => a.type == AddressType.work)),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Yêu thích', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 12),
            ..._addresses.where((a) => a.type == AddressType.favorite).map((a) => _buildAddressItem(a)),

            const SizedBox(height: 20),
            const Text('Tất cả', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 12),
            ..._addresses.map((a) => _buildAddressItem(a)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSet(String emoji, String label, bool hasAddress) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasAddress ? AppColors.blueBg : AppColors.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasAddress ? AppColors.blue.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(
                    hasAddress ? 'Đã thiết lập' : 'Thêm địa chỉ',
                    style: TextStyle(fontSize: 12, color: hasAddress ? AppColors.green : AppColors.text3),
                  ),
                ],
              ),
            ),
            Icon(hasAddress ? Icons.check_circle : Icons.add_circle_outline,
              color: hasAddress ? AppColors.green : AppColors.text3, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressItem(SavedAddress addr) {
    return Dismissible(
      key: Key(addr.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.redBg, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete, color: AppColors.red),
      ),
      onDismissed: (_) => setState(() => _addresses.removeWhere((a) => a.id == addr.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.bg3, borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(addr.type.emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(addr.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(addr.address, style: const TextStyle(fontSize: 12, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Thêm địa chỉ mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 20),
            TextField(
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(hintText: 'Tên địa chỉ (VD: Nhà bà ngoại)', prefixIcon: Icon(Icons.label_outline, color: AppColors.text3)),
            ),
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(hintText: 'Tìm địa chỉ...', prefixIcon: Icon(Icons.search, color: AppColors.text3)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Lưu địa chỉ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
