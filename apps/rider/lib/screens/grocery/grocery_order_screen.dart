import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/app_models.dart';

class GroceryOrderScreen extends StatefulWidget {
  const GroceryOrderScreen({super.key});

  @override
  State<GroceryOrderScreen> createState() => _GroceryOrderScreenState();
}

class _GroceryOrderScreenState extends State<GroceryOrderScreen> {
  final List<MarketStore> _stores = [
    MarketStore(
      id: 'coopmart_cq',
      name: 'Co.opmart Cống Quỳnh',
      address: '189 Cống Quỳnh, P. Nguyễn Cư Trinh, Q.1',
      category: 'Siêu thị',
      emoji: '🛒',
      rating: 4.8,
      distance: '1.2 km',
      openHours: '07:30 - 22:00',
    ),
    MarketStore(
      id: 'winmart_ntmk',
      name: 'WinMart+ Nguyễn Thị Minh Khai',
      address: '32 Nguyễn Thị Minh Khai, P. Đa Kao, Q.1',
      category: 'Tiện lợi',
      emoji: '🏪',
      rating: 4.7,
      distance: '0.8 km',
      openHours: '06:00 - 23:00',
    ),
    MarketStore(
      id: 'cho_benthanh',
      name: 'Chợ Bến Thành',
      address: 'Đường Lê Lợi, P. Bến Thành, Q.1',
      category: 'Chợ truyền thống',
      emoji: '🏮',
      rating: 4.9,
      distance: '1.5 km',
      openHours: '06:00 - 18:00',
    ),
    MarketStore(
      id: 'bachhoaxanh',
      name: 'Bách Hóa Xanh Bùi Viện',
      address: '84 Bùi Viện, P. Phạm Ngũ Lão, Q.1',
      category: 'Cửa hàng',
      emoji: '🥬',
      rating: 4.6,
      distance: '0.6 km',
      openHours: '06:30 - 21:30',
    ),
    MarketStore(
      id: 'cho_tandinh',
      name: 'Chợ Tân Định',
      address: '336 Hai Bà Trưng, P. Tân Định, Q.1',
      category: 'Chợ truyền thống',
      emoji: '🥩',
      rating: 4.8,
      distance: '2.5 km',
      openHours: '05:30 - 18:30',
    ),
  ];

  late MarketStore _selectedStore;
  final List<GroceryItem> _items = [
    GroceryItem(
      id: 'item_1',
      name: 'Thịt ba chỉ heo tươi',
      quantity: 1,
      unit: 'kg',
      estimatedPrice: 140000,
      note: 'Chọn miếng nạc mỡ đều',
      allowSubstitution: true,
    ),
    GroceryItem(
      id: 'item_2',
      name: 'Rau muống nước',
      quantity: 2,
      unit: 'bó',
      estimatedPrice: 15000,
      note: 'Rau non, tươi mới',
      allowSubstitution: true,
    ),
    GroceryItem(
      id: 'item_3',
      name: 'Cà chua Đà Lạt',
      quantity: 1,
      unit: 'kg',
      estimatedPrice: 32000,
      note: 'Quả chín vừa, không dập',
      allowSubstitution: true,
    ),
    GroceryItem(
      id: 'item_4',
      name: 'Trứng gà Ba Huân (vỉ 10 quả)',
      quantity: 1,
      unit: 'hộp',
      estimatedPrice: 35000,
      allowSubstitution: true,
    ),
  ];

  // Quick suggestions
  final Map<String, List<Map<String, dynamic>>> _quickItems = {
    '🥬 Rau củ': [
      {'name': 'Rau cải ngọt', 'unit': 'bó', 'price': 14000},
      {'name': 'Khoai tây Đà Lạt', 'unit': 'kg', 'price': 35000},
      {'name': 'Hành lá + Ngò rí', 'unit': 'bó', 'price': 10000},
      {'name': 'Xà lách búp', 'unit': 'kg', 'price': 40000},
    ],
    '🥩 Thịt & Cá': [
      {'name': 'Ức gà phi lê', 'unit': 'kg', 'price': 85000},
      {'name': 'Sườn non heo', 'unit': 'kg', 'price': 165000},
      {'name': 'Tôm sú tươi', 'unit': 'kg', 'price': 220000},
      {'name': 'Cá hồi Na Uy', 'unit': 'khay', 'price': 150000},
    ],
    '🍎 Trái cây': [
      {'name': 'Cam sành Hàm Yên', 'unit': 'kg', 'price': 28000},
      {'name': 'Táo Envy New Zealand', 'unit': 'kg', 'price': 120000},
      {'name': 'Chuối già Nam Mỹ', 'unit': 'nải', 'price': 35000},
    ],
    '🧂 Gia vị & Gạo': [
      {'name': 'Gạo ST25 Ông Cua (5kg)', 'unit': 'túi', 'price': 185000},
      {'name': 'Dầu ăn Simply 1L', 'unit': 'chai', 'price': 58000},
      {'name': 'Nước mắm Chin-su 500ml', 'unit': 'chai', 'price': 42000},
    ],
  };

  String _selectedCategory = '🥬 Rau củ';
  final String _deliveryAddress = 'Tòa nhà Bitexco, 2 Hải Triều, P. Bến Nghé, Q.1';
  String _customerNote = 'Vui lòng gọi trước khi giao 5 phút';
  String _paymentMethod = 'Ví Xebuonho';
  int _tip = 10000;

  @override
  void initState() {
    super.initState();
    _selectedStore = _stores.first;
  }

  int get _itemsSubtotal => _items.fold(0, (sum, item) => sum + item.totalEstimated);
  int get _serviceFee => (_itemsSubtotal * 0.15).clamp(20000, 150000).toInt();
  int get _deliveryFee => 18000;
  int get _totalEstimate => _itemsSubtotal + _serviceFee + _deliveryFee + _tip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Row(
          children: [
            Text('🛒', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Đi chợ hộ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.text)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.purpleBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.purple, size: 16),
                const SizedBox(width: 4),
                Text('${_items.length} món', style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStoreSelectionCard(),
            const SizedBox(height: 16),
            _buildShoppingListSection(),
            const SizedBox(height: 16),
            _buildQuickAddSection(),
            const SizedBox(height: 16),
            _buildDeliveryInfoCard(),
            const SizedBox(height: 16),
            _buildPricingBreakdownCard(),
            const SizedBox(height: 16),
            _buildTipSelector(),
            const SizedBox(height: 16),
            _buildPaymentMethodCard(),
            const SizedBox(height: 24),
            _buildConfirmButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🏪', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('Chợ / Siêu thị mua hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
                ],
              ),
              GestureDetector(
                onTap: _showStorePickerModal,
                child: const Text('Đổi nơi mua', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.purpleBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(_selectedStore.emoji, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedStore.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
                      const SizedBox(height: 2),
                      Text(_selectedStore.address, style: const TextStyle(fontSize: 12, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('⭐ ${_selectedStore.rating}', style: const TextStyle(fontSize: 11, color: AppColors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('📍 ${_selectedStore.distance}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                          const SizedBox(width: 8),
                          Text('🕒 ${_selectedStore.openHours}', style: const TextStyle(fontSize: 11, color: AppColors.green)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingListSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('📝', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text('Danh sách cần mua', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(8)),
                    child: Text('${_items.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text2)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showAddItemModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.blueBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: AppColors.blue, size: 16),
                      SizedBox(width: 4),
                      Text('Thêm món', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Text('🛒', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 8),
                  Text('Chưa có món nào trong danh sách', style: TextStyle(color: AppColors.text2, fontSize: 14)),
                  Text('Chọn gợi ý bên dưới hoặc bấm "+ Thêm món"', style: TextStyle(color: AppColors.text3, fontSize: 12)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => Divider(color: AppColors.border.withValues(alpha: 0.5), height: 16),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: AppColors.purpleBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.purple)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text('${_formatVND(item.estimatedPrice)}/${item.unit}', style: const TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.w600)),
                              if (item.allowSubstitution) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Được đổi món', style: TextStyle(fontSize: 10, color: AppColors.green, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ],
                          ),
                          if (item.note != null && item.note!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('💬 ${item.note}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.text3)),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.text3),
                          onPressed: () {
                            setState(() {
                              if (item.quantity > 1) {
                                item.quantity--;
                              } else {
                                _items.removeAt(index);
                              }
                            });
                          },
                        ),
                        Text('${item.quantity} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.blue),
                          onPressed: () {
                            setState(() {
                              item.quantity++;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickAddSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('⚡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Gợi ý thêm nhanh', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickItems.keys.map((cat) {
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.blue : AppColors.bg3,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.blue : AppColors.border),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.text2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_quickItems[_selectedCategory] ?? []).map((sugg) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _items.add(GroceryItem(
                      id: 'item_${DateTime.now().millisecondsSinceEpoch}',
                      name: sugg['name'] as String,
                      quantity: 1,
                      unit: sugg['unit'] as String,
                      estimatedPrice: sugg['price'] as int,
                    ));
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã thêm ${sugg['name']} vào danh sách!'),
                      duration: const Duration(seconds: 1),
                      backgroundColor: AppColors.green,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bg3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sugg['name'] as String, style: const TextStyle(fontSize: 12, color: AppColors.text, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 6),
                      Text('+${_formatVND(sugg['price'] as int)}', style: const TextStyle(fontSize: 11, color: AppColors.orange, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📍', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Giao hàng đến', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 10),
          Text(_deliveryAddress, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text)),
          const SizedBox(height: 8),
          TextField(
            onChanged: (val) => _customerNote = val,
            controller: TextEditingController(text: _customerNote),
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ghi chú cho tài xế mua hàng (ví dụ: gọi trước khi đến...)',
              hintStyle: const TextStyle(color: AppColors.text3, fontSize: 12),
              prefixIcon: const Icon(Icons.edit_note, color: AppColors.blue, size: 20),
              filled: true,
              fillColor: AppColors.bg3,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💰', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Bảng tính chi phí ước tính', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          _buildPriceRow('Tiền hàng ước tính', _formatVND(_itemsSubtotal)),
          const SizedBox(height: 6),
          _buildPriceRow('Phí dịch vụ mua hộ (15%)', _formatVND(_serviceFee), subtitle: 'Tài xế chọn hàng & đối chiếu hóa đơn'),
          const SizedBox(height: 6),
          _buildPriceRow('Phí giao hàng (${_selectedStore.distance})', _formatVND(_deliveryFee)),
          if (_tip > 0) ...[
            const SizedBox(height: 6),
            _buildPriceRow('Tiền tip tài xế', _formatVND(_tip)),
          ],
          const Divider(color: AppColors.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tổng chi phí ước tính', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
                  Text('Thanh toán theo hóa đơn thực tế', style: TextStyle(fontSize: 11, color: AppColors.text3)),
                ],
              ),
              Text(_formatVND(_totalEstimate), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {String? subtitle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
            if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.text3)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
      ],
    );
  }

  Widget _buildTipSelector() {
    final tipOptions = [0, 10000, 20000, 30000, 50000];
    return Row(
      children: [
        const Text('❤️ Tip cho tài xế:', style: TextStyle(fontSize: 13, color: AppColors.text2, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tipOptions.map((amount) {
                final isSelected = _tip == amount;
                return GestureDetector(
                  onTap: () => setState(() => _tip = amount),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.greenBg : AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.green : AppColors.border),
                    ),
                    child: Text(
                      amount == 0 ? 'Không' : '${amount ~/ 1000}k',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.green : AppColors.text2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard() {
    final methods = [
      {'name': 'Ví Xebuonho', 'emoji': '💳', 'desc': 'Số dư: 500.000đ'},
      {'name': 'Tiền mặt', 'emoji': '💵', 'desc': 'Trả khi nhận hàng'},
      {'name': 'SePay VietQR', 'emoji': '📲', 'desc': 'Quét mã ngân hàng'},
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phương thức thanh toán', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 10),
          Row(
            children: methods.map((m) {
              final isSelected = _paymentMethod == m['name'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = m['name'] as String),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.blueBg : AppColors.bg3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppColors.blue : AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text(m['emoji'] as String, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(m['name'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? AppColors.blue : AppColors.text), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return GestureDetector(
      onTap: _confirmOrder,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.purple, Color(0xFF6B21A8)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
              'Xác nhận đặt đi chợ (${_formatVND(_totalEstimate)})',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmOrder() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm ít nhất 1 món vào danh sách!'), backgroundColor: AppColors.red),
      );
      return;
    }

    final newOrder = GroceryOrder(
      id: 'GROCERY-${DateTime.now().millisecondsSinceEpoch % 100000}',
      store: _selectedStore,
      items: List.from(_items),
      status: GroceryOrderStatus.driverAssigned,
      createdAt: DateTime.now(),
      deliveryAddress: _deliveryAddress,
      paymentMethod: _paymentMethod,
      note: _customerNote,
      estimatedSubtotal: _itemsSubtotal,
      serviceFee: _serviceFee,
      deliveryFee: _deliveryFee,
      tip: _tip,
    );

    Navigator.pushNamed(context, '/grocery-tracking', arguments: newOrder);
  }

  void _showStorePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Chọn chợ hoặc siêu thị', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _stores.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final store = _stores[index];
                    final isCurrent = store.id == _selectedStore.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedStore = store);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppColors.blueBg : AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isCurrent ? AppColors.blue : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Text(store.emoji, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text)),
                                  Text(store.address, style: const TextStyle(fontSize: 11, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Text(store.distance, style: const TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddItemModal() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedUnit = 'kg';
    int quantity = 1;
    bool allowSub = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thêm món vào danh sách', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      labelText: 'Tên món cần mua *',
                      labelStyle: const TextStyle(color: AppColors.text3),
                      hintText: 'Ví dụ: Cải thảo, Nước cốt dừa...',
                      filled: true,
                      fillColor: AppColors.bg3,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: AppColors.text3),
                              onPressed: () {
                                if (quantity > 1) setModalState(() => quantity--);
                              },
                            ),
                            Text('$quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: AppColors.blue),
                              onPressed: () => setModalState(() => quantity++),
                            ),
                          ],
                        ),
                      ),
                      DropdownButton<String>(
                        value: selectedUnit,
                        dropdownColor: AppColors.card,
                        style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
                        items: ['kg', 'bó', 'túi', 'hộp', 'chai', 'khay', 'gói', 'quả', 'nải'].map((u) {
                          return DropdownMenuItem(value: u, child: Text(u));
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedUnit = val ?? 'kg'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      labelText: 'Giá ước tính (VND)',
                      labelStyle: const TextStyle(color: AppColors.text3),
                      hintText: '30000',
                      filled: true,
                      fillColor: AppColors.bg3,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      labelText: 'Ghi chú cho tài xế',
                      labelStyle: const TextStyle(color: AppColors.text3),
                      hintText: 'Chọn loại tươi, bọc kỹ...',
                      filled: true,
                      fillColor: AppColors.bg3,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: allowSub,
                        activeColor: AppColors.blue,
                        onChanged: (v) => setModalState(() => allowSub = v ?? true),
                      ),
                      const Expanded(
                        child: Text('Cho phép tài xế đề xuất món thay thế nếu hết hàng', style: TextStyle(fontSize: 12, color: AppColors.text2)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final price = int.tryParse(priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 30000;
                      setState(() {
                        _items.add(GroceryItem(
                          id: 'item_${DateTime.now().millisecondsSinceEpoch}',
                          name: nameCtrl.text.trim(),
                          quantity: quantity,
                          unit: selectedUnit,
                          estimatedPrice: price,
                          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                          allowSubstitution: allowSub,
                        ));
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Thêm vào danh sách', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatVND(int amount) {
    final s = amount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${s.replaceAllMapped(reg, (m) => '${m[1]}.')} đ';
  }
}
