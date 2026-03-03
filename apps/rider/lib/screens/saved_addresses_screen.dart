import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/app_models.dart';
import '../services/geocoding_service.dart';

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
    final favorites = _addresses.where((a) => a.type == AddressType.favorite).toList();
    final others = _addresses.where((a) => a.type != AddressType.favorite).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Địa chỉ đã lưu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppColors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm địa chỉ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
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

          if (favorites.isNotEmpty) ...[
            Text('Yêu thích', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 12),
            for (int i = 0; i < favorites.length; i++)
              _buildAddressCard(favorites[i]),
            const SizedBox(height: 20),
          ],

          Text('Khác', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
          const SizedBox(height: 12),
          for (int i = 0; i < others.length; i++)
            _buildAddressCard(others[i]),
        ],
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
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
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

  Widget _buildAddressCard(SavedAddress addr) {
    return Container(
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
            decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(addr.type.emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(addr.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                Text(addr.address, style: TextStyle(fontSize: 12, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      backgroundColor: AppColors.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddAddressSheet(
        onSave: (name, address, lat, lng) {
          setState(() {
            _addresses.add(SavedAddress(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              address: address,
              lat: lat,
              lng: lng,
              type: AddressType.favorite,
            ));
          });
        },
      ),
    );
  }
}

// ========== Add Address Bottom Sheet with Search ==========
class _AddAddressSheet extends StatefulWidget {
  final void Function(String name, String address, double lat, double lng) onSave;
  const _AddAddressSheet({required this.onSave});

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _geocoding = GeocodingService();
  List<GeocodingResult> _suggestions = [];
  GeocodingResult? _selected;
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    _geocoding.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() { _suggestions = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await _geocoding.search(query, lat: 10.7769, lng: 106.7009);
        if (mounted) setState(() { _suggestions = results; _searching = false; });
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _selectSuggestion(GeocodingResult result) {
    setState(() {
      _selected = result;
      _searchCtrl.text = result.displayName;
      _suggestions = [];
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = result.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Thêm địa chỉ mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 20),

          // Name field
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              hintText: 'Tên địa chỉ (VD: Nhà bà ngoại)',
              prefixIcon: Icon(Icons.label_outline, color: AppColors.text3),
            ),
          ),
          const SizedBox(height: 12),

          // Search field
          TextField(
            controller: _searchCtrl,
            style: TextStyle(color: AppColors.text),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm địa chỉ, tên đường...',
              prefixIcon: Icon(Icons.search, color: AppColors.text3),
              suffixIcon: _searching
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue)),
                  )
                : _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: Icon(Icons.close, color: AppColors.text3, size: 18), onPressed: () {
                      _searchCtrl.clear();
                      setState(() { _suggestions = []; _selected = null; });
                    })
                  : null,
            ),
          ),

          // Suggestions
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: AppColors.bg3, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  return GestureDetector(
                    onTap: () => _selectSuggestion(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: i < _suggestions.length - 1
                          ? Border(bottom: BorderSide(color: AppColors.border))
                          : null,
                      ),
                      child: Row(
                        children: [
                          Text(s.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(s.displayName, style: TextStyle(fontSize: 11, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Selected indicator
          if (_selected != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Text('✅', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selected!.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green))),
                  Text('${_selected!.lat.toStringAsFixed(4)}, ${_selected!.lng.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 10, color: AppColors.text3)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _selected != null ? () {
                widget.onSave(_nameCtrl.text, _selected!.displayName, _selected!.lat, _selected!.lng);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Đã lưu ${_nameCtrl.text}'), backgroundColor: AppColors.green),
                );
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                disabledBackgroundColor: AppColors.bg3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _selected != null ? 'Lưu địa chỉ' : 'Chọn địa chỉ để lưu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _selected != null ? Colors.white : AppColors.text3),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
