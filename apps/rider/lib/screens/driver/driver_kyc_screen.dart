import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

/// Each KYC document slot: local preview bytes + uploaded object key + presigned view URL.
class _DocSlot {
  String? objectKey;
  Uint8List? previewBytes;
  String? existingUrl; // presigned GET URL từ hồ sơ đã nộp
  double progress = 0;
  bool uploading = false;
  String? error;
}

class DriverKYCScreen extends StatefulWidget {
  const DriverKYCScreen({super.key});

  @override
  State<DriverKYCScreen> createState() => _DriverKYCScreenState();
}

class _DriverKYCScreenState extends State<DriverKYCScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Controllers
  late TextEditingController _idCardController;
  late TextEditingController _licenseNumController;
  late TextEditingController _licenseExpiryController;
  late TextEditingController _vehiclePlateController;
  late TextEditingController _vehicleModelController;
  late TextEditingController _insuranceExpiryController;
  // Business controllers (NĐ 10/2020 + 47/2022 — xe ô tô hợp đồng)
  late TextEditingController _companyNameController;
  late TextEditingController _companyTaxController;
  late TextEditingController _businessLicenseController;
  late TextEditingController _transportLicenseController;
  late TextEditingController _transportLicenseExpiryController;

  String _licenseClass = 'B2';
  String _vehicleType = 'car';
  String _driverKind = 'personal';
  bool _blackboxInstalled = false;
  bool _cabinCameraInstalled = false;
  bool _isSubmitting = false;
  bool _submittedSuccess = false;
  String? _errorMessage;

  // Trạng thái hồ sơ đã nộp (load lại từ server khi mở màn)
  String? _existingStatus;
  String? _existingRejectionReason;
  bool _hasExisting = false;

  // Real document uploads: docType -> slot
  final Map<String, _DocSlot> _docs = {
    'cccd_front': _DocSlot(),
    'cccd_back': _DocSlot(),
    'gplx_front': _DocSlot(),
    'gplx_back': _DocSlot(),
    'vehicle_registration': _DocSlot(),
    'vehicle_insurance': _DocSlot(),
  };

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _driverKind = auth.driverKind == 'business' ? 'business' : 'personal';
    if (_driverKind == 'business') {
      _docs['business_license'] = _DocSlot();
      _docs['transport_license'] = _DocSlot();
      _docs['employment_contract'] = _DocSlot();
      // Xe hợp đồng doanh nghiệp chỉ là ô tô (NĐ 10/2020)
      _vehicleType = 'car';
    }
    _idCardController = TextEditingController();
    _licenseNumController = TextEditingController();
    _licenseExpiryController = TextEditingController();
    _vehiclePlateController = TextEditingController(
      text: auth.licensePlate,
    );
    _vehicleModelController = TextEditingController(
      text: auth.vehicleModel,
    );
    _insuranceExpiryController = TextEditingController();
    _companyNameController = TextEditingController();
    _companyTaxController = TextEditingController();
    _businessLicenseController = TextEditingController();
    _transportLicenseController = TextEditingController();
    _transportLicenseExpiryController = TextEditingController();
    if (_vehicleType == 'motorcycle') {
      _licenseClass = 'A1';
    }
    // Load hồ sơ đã nộp (nếu có) để "Xem hồ sơ" hiển thị lại đầy đủ
    _loadExistingKyc();
  }

  Future<void> _loadExistingKyc() async {
    Map<String, dynamic>? detail;
    try {
      detail = await ApiService().getMyKyc();
    } catch (_) {
      return; // offline demo mode: giữ form trống như cũ
    }
    if (!mounted) return;
    final user = detail['user'] as Map<String, dynamic>? ?? {};
    final docUrls = detail['doc_urls'] as Map<String, dynamic>? ?? {};

    // driver_kind theo server (anti-downgrade phía client)
    final serverKind = user['driver_kind']?.toString();
    if (serverKind == 'business' && !_docs.containsKey('business_license')) {
      _docs['business_license'] = _DocSlot();
      _docs['transport_license'] = _DocSlot();
      _docs['employment_contract'] = _DocSlot();
    }
    if (serverKind != null && serverKind.isNotEmpty) {
      _driverKind = serverKind;
    }

    String? s(dynamic v) {
      final str = v?.toString();
      return (str == null || str.isEmpty) ? null : str;
    }

    _idCardController.text = s(user['id_card_number']) ?? '';
    _licenseNumController.text = s(user['driver_license_number']) ?? '';
    _licenseExpiryController.text = s(user['driver_license_expiry']) ?? '';
    _insuranceExpiryController.text = s(user['vehicle_insurance_expiry']) ?? '';
    if (s(user['license_plate']) != null) {
      _vehiclePlateController.text = s(user['license_plate'])!;
    }
    if (s(user['vehicle_model']) != null) {
      _vehicleModelController.text = s(user['vehicle_model'])!;
    }
    final licenseClass = s(user['driver_license_class']);
    if (licenseClass != null && ['A1','A2','B1','B2','C','D','E'].contains(licenseClass)) {
      _licenseClass = licenseClass;
    }
    final vehicleType = s(user['vehicle_type']);
    if (_driverKind == 'business') {
      _vehicleType = 'car';
    } else if (vehicleType == 'car' || vehicleType == 'motorcycle') {
      _vehicleType = vehicleType!;
    }
    _companyNameController.text = s(user['company_name']) ?? '';
    _companyTaxController.text = s(user['company_tax_code']) ?? '';
    _businessLicenseController.text = s(user['business_license_number']) ?? '';
    _transportLicenseController.text = s(user['transport_license_number']) ?? '';
    _transportLicenseExpiryController.text = s(user['transport_license_expiry']) ?? '';
    _blackboxInstalled = user['blackbox_installed'] == true;
    _cabinCameraInstalled = user['cabin_camera_installed'] == true;

    // Doc slots đã nộp: object key + presigned URL để xem lại ảnh
    void fillSlot(String slotKey, String? objectKey) {
      if (objectKey == null) return;
      final slot = _docs[slotKey];
      if (slot == null) return;
      slot.objectKey = objectKey;
      final url = docUrls[slotKey]?.toString();
      slot.existingUrl = (url != null && url.isNotEmpty) ? url : null;
    }
    fillSlot('cccd_front', s(user['id_card_front_url']));
    fillSlot('cccd_back', s(user['id_card_back_url']));
    fillSlot('gplx_front', s(user['driver_license_front_url']));
    fillSlot('gplx_back', s(user['driver_license_back_url']));
    fillSlot('vehicle_registration', s(user['vehicle_registration_url']));
    fillSlot('vehicle_insurance', s(user['vehicle_insurance_url']));
    fillSlot('business_license', s(user['business_license_url']));
    fillSlot('transport_license', s(user['transport_license_url']));
    fillSlot('employment_contract', s(user['employment_contract_url']));

    setState(() {
      _existingStatus = s(user['approval_status']);
      _existingRejectionReason = s(user['rejection_reason']);
      _hasExisting = _docs.values.any((d) => d.objectKey != null) ||
          _idCardController.text.isNotEmpty ||
          _licenseNumController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _idCardController.dispose();
    _licenseNumController.dispose();
    _licenseExpiryController.dispose();
    _vehiclePlateController.dispose();
    _vehicleModelController.dispose();
    _insuranceExpiryController.dispose();
    _companyNameController.dispose();
    _companyTaxController.dispose();
    _businessLicenseController.dispose();
    _transportLicenseController.dispose();
    _transportLicenseExpiryController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(String docType) async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
    } catch (_) {
      return;
    }
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    // Trên web picked.path là blob URL; tên file thật nằm ở picked.name.
    final ext = picked.name.isNotEmpty
        ? picked.name.split('.').last.toLowerCase()
        : picked.path.split('.').last.toLowerCase();

    final slot = _docs[docType]!;
    setState(() {
      slot.previewBytes = bytes;
      slot.uploading = true;
      slot.error = null;
      slot.progress = 0;
    });

    try {
      final key = await ApiService().uploadKycDocument(
        docType: docType,
        bytes: bytes,
        fileExt: ext,
        onProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => slot.progress = sent / total);
          }
        },
      );
      setState(() {
        slot.objectKey = key;
        slot.uploading = false;
        slot.progress = 1;
      });
    } catch (e) {
      setState(() {
        slot.uploading = false;
        slot.objectKey = null;
        slot.error = 'Tải lên thất bại, thử lại';
      });
    }
  }

  List<String> get _missingDocs {
    final required = [
      'cccd_front', 'cccd_back', 'gplx_front',
      'vehicle_registration', 'vehicle_insurance',
      if (_driverKind == 'business') 'business_license',
      if (_driverKind == 'business') 'employment_contract',
    ];
    return required.where((t) => _docs[t]?.objectKey == null).toList();
  }

  Future<void> _submitKYC() async {
    if (!_formKey.currentState!.validate()) return;

    final missing = _missingDocs;
    if (missing.isNotEmpty) {
      setState(() {
        _errorMessage =
            'Vui lòng tải lên đầy đủ ảnh giấy tờ bắt buộc (${missing.length} ảnh còn thiếu).';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();

    String? key(String docType) => _docs[docType]?.objectKey;

    try {
      final payload = {
        'driver_kind': _driverKind,
        'id_card_number': _idCardController.text.trim(),
        'id_card_front_url': key('cccd_front'),
        'id_card_back_url': key('cccd_back'),
        'driver_license_number': _licenseNumController.text.trim(),
        'driver_license_class': _licenseClass,
        'driver_license_expiry': _licenseExpiryController.text.trim(),
        'driver_license_front_url': key('gplx_front'),
        'driver_license_back_url': key('gplx_back'),
        'vehicle_registration_url': key('vehicle_registration'),
        'vehicle_insurance_url': key('vehicle_insurance'),
        'vehicle_insurance_expiry': _insuranceExpiryController.text.trim(),
        'vehicle_type': _vehicleType,
        'license_plate': _vehiclePlateController.text.trim(),
        'vehicle_model': _vehicleModelController.text.trim(),
        if (_driverKind == 'business') ...{
          'company_name': _companyNameController.text.trim(),
          'company_tax_code': _companyTaxController.text.trim(),
          'business_license_number': _businessLicenseController.text.trim(),
          'business_license_url': key('business_license'),
          'transport_license_number': _transportLicenseController.text.trim(),
          'transport_license_expiry': _transportLicenseExpiryController.text.trim(),
          'transport_license_url': key('transport_license'),
          'employment_contract_url': key('employment_contract'),
          'blackbox_installed': _blackboxInstalled,
          'cabin_camera_installed': _cabinCameraInstalled,
        },
      };

      final response = await ApiService().submitDriverKYC(payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        auth.updateDriverKYC(
          vehicleType: _vehicleType,
          licensePlate: _vehiclePlateController.text.trim(),
          vehicleModel: _vehicleModelController.text.trim(),
        );
        setState(() {
          _isSubmitting = false;
          _submittedSuccess = true;
        });
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = response.data?['error'] ?? 'Gửi hồ sơ thất bại';
        });
      }
    } catch (e) {
      // Hiển thị lỗi thật (validation backend, network, DB...) — không fake success.
      String msg = 'Gửi hồ sơ thất bại';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          msg = data['error'].toString();
        } else if (e.message != null) {
          msg = e.message!;
        }
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        elevation: 0,
        title: Text(
          _hasExisting
              ? 'Hồ sơ Pháp lý & KYC Tài xế'
              : (_driverKind == 'business'
                  ? 'Đăng ký Tài xế Doanh nghiệp & KYC'
                  : 'Đăng ký Pháp lý & KYC Tài xế'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
        ),
      ),
      body: _submittedSuccess ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.greenBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.green, width: 2),
              ),
              child: const Icon(Icons.check_circle, color: AppColors.green, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Hồ sơ đã được tiếp nhận!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Hồ sơ đăng ký đối tác tài xế${_driverKind == 'business' ? ' doanh nghiệp' : ''} của bạn đang được bộ phận quản lý Xe Buôn Hồ xét duyệt theo quy định Nghị định 10/2020/NĐ-CP.\n\nThời gian xử lý dự kiến: từ 2 đến 24 giờ làm việc. Bạn sẽ nhận được thông báo ngay khi hồ sơ được kích hoạt.',
              style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/driver');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Vào Bảng Điều Khiển Tài Xế',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    switch (_existingStatus) {
      case 'pending_approval':
        return _banner(
          color: AppColors.orange,
          bg: AppColors.orangeBg,
          icon: Icons.pending_actions,
          text: 'Hồ sơ đang chờ xét duyệt theo NĐ 10/2020/NĐ-CP. Bạn có thể xem lại hoặc cập nhật và gửi xét duyệt lại.',
        );
      case 'rejected':
        return _banner(
          color: AppColors.red,
          bg: AppColors.redBg,
          icon: Icons.cancel_outlined,
          text: 'Hồ sơ bị từ chối${_existingRejectionReason != null ? ': $_existingRejectionReason' : ''}. Vui lòng sửa và gửi lại.',
        );
      case 'approved':
        return _banner(
          color: AppColors.green,
          bg: AppColors.greenBg,
          icon: Icons.verified_outlined,
          text: 'Hồ sơ đã được phê duyệt. Bạn có thể cập nhật giấy tờ khi có thay đổi (sẽ xét duyệt lại).',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _banner({
    required Color color,
    required Color bg,
    required IconData icon,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildComplianceBanner(),
          _buildStatusBanner(),
          const SizedBox(height: 8),

          // Section 1: CCCD
          _buildSectionHeader('1. Định danh cá nhân (CCCD / ĐDCN)'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _idCardController,
            style: const TextStyle(color: AppColors.text),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số Căn cước công dân (12 số)',
              prefixIcon: Icon(Icons.badge_outlined, color: AppColors.text3),
            ),
            validator: (v) {
              if (v == null || v.trim().length != 12) {
                return 'Số CCCD phải gồm đúng 12 chữ số';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildDocRow('cccd_front', 'Ảnh CCCD mặt trước', 'cccd_back', 'Ảnh CCCD mặt sau'),
          const SizedBox(height: 24),

          // Section 2: Driver License
          _buildSectionHeader('2. Giấy phép lái xe (GPLX)'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _licenseNumController,
                  style: const TextStyle(color: AppColors.text),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số Giấy phép lái xe',
                    prefixIcon: Icon(Icons.card_membership, color: AppColors.text3),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập số GPLX' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _licenseClass,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: AppColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Hạng GPLX',
                  ),
                  items: ['A1', 'A2', 'B1', 'B2', 'C', 'D', 'E'].map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _licenseClass = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _licenseExpiryController,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Ngày hết hạn GPLX (YYYY-MM-DD)',
              hintText: '2030-12-31 hoặc bỏ trống nếu vô thời hạn',
              prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.text3),
            ),
            validator: (v) => _validateDate(v, 'Ngày hết hạn GPLX'),
          ),
          const SizedBox(height: 12),
          _buildDocRow('gplx_front', 'Ảnh GPLX mặt trước', 'gplx_back', 'Ảnh GPLX mặt sau'),
          const SizedBox(height: 24),

          // Section 3: Vehicle Info
          _buildSectionHeader('3. Phương tiện & Pháp lý xe'),
          const SizedBox(height: 10),
          if (_driverKind == 'personal') _buildVehicleTypePicker(),
          if (_driverKind == 'personal') const SizedBox(height: 12),
          TextFormField(
            controller: _vehiclePlateController,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Biển số xe',
              hintText: 'VD: 47-B1 123.45',
              prefixIcon: Icon(Icons.pin_outlined, color: AppColors.text3),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập biển số xe' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _vehicleModelController,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Hãng xe & Tên dòng xe',
              hintText: 'VD: Honda Wave Alpha 2022',
              prefixIcon: Icon(Icons.info_outline, color: AppColors.text3),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập hãng và dòng xe' : null,
          ),
          const SizedBox(height: 12),
          _buildDocRow('vehicle_registration', 'Đăng ký xe (Cà vẹt)', 'vehicle_insurance', 'Bảo hiểm TNDS xe'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _insuranceExpiryController,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Ngày hết hạn bảo hiểm TNDS (YYYY-MM-DD)',
              prefixIcon: Icon(Icons.calendar_month_outlined, color: AppColors.text3),
            ),
            validator: (v) => _validateDate(v, 'Ngày hết hạn bảo hiểm'),
          ),
          const SizedBox(height: 24),

          // Section 4: Business paperwork (chỉ tài xế doanh nghiệp)
          if (_driverKind == 'business') _buildBusinessSection(),

          // Error box if any
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.redBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: const TextStyle(fontSize: 13, color: AppColors.red)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Submit Button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitKYC,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _hasExisting ? 'Cập nhật hồ sơ xét duyệt' : 'Gửi hồ sơ xét duyệt',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String? _validateDate(String? v, String label) {
    if (v == null || v.trim().isEmpty) return null;
    final reg = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!reg.hasMatch(v.trim())) {
      return '$label theo định dạng YYYY-MM-DD';
    }
    return null;
  }

  Widget _buildComplianceBanner() {
    final isBusiness = _driverKind == 'business';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user, color: AppColors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBusiness ? 'Quy chuẩn pháp lý xe hợp đồng doanh nghiệp' : 'Quy chuẩn pháp lý thương mại',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.blue),
                ),
                const SizedBox(height: 4),
                Text(
                  isBusiness
                      ? 'Theo NĐ 10/2020/NĐ-CP và NĐ 47/2022/NĐ-CP, xe ô tô hợp đồng kinh doanh vận tải phải có Giấy phép vận tải, phù hiệu hợp đồng, hộp đen GPS, camera cabin và tài xế ký HĐ lao động với doanh nghiệp.'
                      : 'Theo Nghị định 10/2020/NĐ-CP và NĐ 47/2022/NĐ-CP, tài xế bắt buộc phải định danh CCCD, Giấy phép lái xe còn hiệu lực, đăng ký xe và bảo hiểm bắt buộc TNDS để đảm bảo an toàn cho khách hàng.',
                  style: const TextStyle(fontSize: 11, color: AppColors.text2, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypePicker() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _vehicleType = 'car';
              _licenseClass = 'B2';
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _vehicleType == 'car' ? AppColors.blueBg : AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _vehicleType == 'car' ? AppColors.blue : AppColors.border,
                  width: _vehicleType == 'car' ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car, color: _vehicleType == 'car' ? AppColors.blue : AppColors.text3),
                  const SizedBox(width: 8),
                  Text(
                    'Xe ô tô',
                    style: TextStyle(
                      color: _vehicleType == 'car' ? AppColors.blue : AppColors.text3,
                      fontWeight: FontWeight.bold,
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
            onTap: () => setState(() {
              _vehicleType = 'motorcycle';
              _licenseClass = 'A1';
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _vehicleType == 'motorcycle' ? AppColors.greenBg : AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _vehicleType == 'motorcycle' ? AppColors.green : AppColors.border,
                  width: _vehicleType == 'motorcycle' ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.two_wheeler, color: _vehicleType == 'motorcycle' ? AppColors.green : AppColors.text3),
                  const SizedBox(width: 8),
                  Text(
                    'Xe máy',
                    style: TextStyle(
                      color: _vehicleType == 'motorcycle' ? AppColors.green : AppColors.text3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('4. Giấy tờ doanh nghiệp (xe ô tô hợp đồng)'),
        const SizedBox(height: 10),
        TextFormField(
          controller: _companyNameController,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            labelText: 'Tên doanh nghiệp',
            prefixIcon: Icon(Icons.business_outlined, color: AppColors.text3),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập tên doanh nghiệp' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _companyTaxController,
          style: const TextStyle(color: AppColors.text),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Mã số thuế',
            prefixIcon: Icon(Icons.receipt_long_outlined, color: AppColors.text3),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _businessLicenseController,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            labelText: 'Số Giấy chứng nhận ĐK kinh doanh',
            prefixIcon: Icon(Icons.description_outlined, color: AppColors.text3),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập số GPKD' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _transportLicenseController,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'Số Giấy phép vận tải',
                  prefixIcon: Icon(Icons.local_shipping_outlined, color: AppColors.text3),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập số GPLVT' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _transportLicenseExpiryController,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'Hạn GPLVT (YYYY-MM-DD)',
                ),
                validator: (v) => _validateDate(v, 'Hạn GPLVT'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDocRow('business_license', 'Giấy ĐK kinh doanh', 'transport_license', 'Giấy phép vận tải'),
        const SizedBox(height: 12),
        _buildDocSlot('employment_contract', 'Hợp đồng lao động / hợp đồng tài xế'),
        const SizedBox(height: 16),
        _buildAttestation(
          value: _blackboxInstalled,
          onChanged: (v) => setState(() => _blackboxInstalled = v),
          label: 'Xe đã lắp hộp đen / GPS tracker (cam kết theo NĐ 47/2022)',
        ),
        const SizedBox(height: 8),
        _buildAttestation(
          value: _cabinCameraInstalled,
          onChanged: (v) => setState(() => _cabinCameraInstalled = v),
          label: 'Xe đã lắp camera cabin ghi hình hành trình',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAttestation({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String label,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              activeColor: AppColors.green,
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow(String leftType, String leftTitle, String rightType, String rightTitle) {
    return Row(
      children: [
        Expanded(child: _buildDocSlot(leftType, leftTitle)),
        const SizedBox(width: 12),
        Expanded(child: _buildDocSlot(rightType, rightTitle)),
      ],
    );
  }

  Widget _buildDocSlot(String docType, String title) {
    final slot = _docs[docType]!;
    final isUploaded = slot.objectKey != null;
    final hasPreview = slot.previewBytes != null;

    return GestureDetector(
      onTap: slot.uploading ? null : () => _pickAndUpload(docType),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUploaded ? AppColors.greenBg : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: slot.error != null
                ? AppColors.red
                : (isUploaded ? AppColors.green.withValues(alpha: 0.5) : AppColors.border),
          ),
        ),
        child: Column(
          children: [
            if (hasPreview)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  slot.previewBytes!,
                  height: 56,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              )
            else if (slot.existingUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  slot.existingUrl!,
                  height: 56,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 56,
                    child: Icon(Icons.image_not_supported_outlined, color: AppColors.text3, size: 24),
                  ),
                ),
              )
            else
              Icon(
                isUploaded ? Icons.check_circle : Icons.camera_alt_outlined,
                color: isUploaded ? AppColors.green : AppColors.text3,
                size: 26,
              ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isUploaded ? AppColors.green : AppColors.text2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              slot.uploading
                  ? 'Đang tải ${(slot.progress * 100).toInt()}%'
                  : (isUploaded ? 'Đã nộp ✓ — chạm để thay' : (slot.error ?? 'Bấm để chụp/chọn')),
              style: TextStyle(
                fontSize: 10,
                color: slot.error != null
                    ? AppColors.red
                    : (isUploaded ? AppColors.green : AppColors.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),
    );
  }
}
