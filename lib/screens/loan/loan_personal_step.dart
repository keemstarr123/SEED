import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:seed/services/loan/loan_repository.dart';

class LoanPersonalStep extends StatefulWidget {
  final String userId;
  final String businessId;
  final VoidCallback onNext;

  const LoanPersonalStep({
    super.key,
    required this.userId,
    required this.businessId,
    required this.onNext,
  });

  @override
  State<LoanPersonalStep> createState() => _LoanPersonalStepState();
}

class _LoanPersonalStepState extends State<LoanPersonalStep> {
  final _repo = LoanRepository();
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _business;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.fetchUserProfile(widget.userId),
        _repo.fetchBusinessProfile(widget.businessId),
      ]);
      if (mounted) {
        setState(() {
          _user = results[0];
          _business = results[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // PostgreSQL stores date as YYYY-MM-DD
  // Display to user as dd/MM/yyyy
  String _displayDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw); // parses YYYY-MM-DD
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw; // already in display format or unknown
    }
  }

  String _toPostgresDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  bool _isPersonalComplete() {
    if (_user == null) return false;
    return ['name', 'ic_number', 'phone_number', 'email', 'date_of_birth', 'gender']
        .every((k) => (_user![k] ?? '').toString().isNotEmpty);
  }

  bool _isBusinessComplete() {
    if (_business == null) return false;
    return ['business_name', 'ssm_registration_number', 'type', 'year_of_establishment']
        .every((k) => (_business![k] ?? '').toString().isNotEmpty);
  }

  void _openPersonalModal() {
    // Temp controllers — initialised from current _user
    final nameCtrl = TextEditingController(text: _user?['name'] ?? '');
    final icCtrl = TextEditingController(text: _user?['ic_number'] ?? '');
    final phoneCtrl = TextEditingController(text: _user?['phone_number'] ?? '');
    final emailCtrl = TextEditingController(text: _user?['email'] ?? '');
    final addressCtrl = TextEditingController(text: _user?['home_address'] ?? '');
    String gender = (_user?['gender'] ?? 'Male');
    if (!['Male', 'Female', 'Other'].contains(gender)) gender = 'Male';

    // Parse existing date
    DateTime? selectedDob;
    try {
      final raw = _user?['date_of_birth'] as String?;
      if (raw != null && raw.isNotEmpty) selectedDob = DateTime.parse(raw);
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: selectedDob ?? DateTime(1990),
              firstDate: DateTime(1940),
              lastDate: DateTime.now(),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.light(primary: Color(0xFF38B6FF)),
                ),
                child: child!,
              ),
            );
            if (picked != null) setModal(() => selectedDob = picked);
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    child: Row(
                      children: [
                        Text('Edit Personal Information',
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      children: [
                        _modalField('Full Name', nameCtrl),
                        _modalField('NRIC', icCtrl),
                        // DOB — date picker
                        Padding(
                          padding: EdgeInsets.only(bottom: 14.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date of Birth',
                                  style: TextStyle(
                                      fontSize: 11.sp,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500)),
                              SizedBox(height: 6.h),
                              GestureDetector(
                                onTap: pickDate,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12.w, vertical: 13.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FE),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedDob != null
                                              ? _toDisplayDate(selectedDob!)
                                              : 'Select date',
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w600,
                                            color: selectedDob != null
                                                ? Colors.black
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.calendar_today_outlined,
                                          size: 16.sp, color: const Color(0xFF38B6FF)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _modalField('Phone Number', phoneCtrl,
                            keyboardType: TextInputType.phone),
                        _modalField('Email Address', emailCtrl,
                            keyboardType: TextInputType.emailAddress),
                        // Gender
                        Padding(
                          padding: EdgeInsets.only(bottom: 14.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gender',
                                  style: TextStyle(
                                      fontSize: 11.sp,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500)),
                              SizedBox(height: 6.h),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'Male', label: Text('Male')),
                                  ButtonSegment(value: 'Female', label: Text('Female')),
                                  ButtonSegment(value: 'Other', label: Text('Other')),
                                ],
                                selected: {gender},
                                onSelectionChanged: (s) =>
                                    setModal(() => gender = s.first),
                                style: SegmentedButton.styleFrom(
                                  selectedBackgroundColor: const Color(0xFF38B6FF),
                                  selectedForegroundColor: Colors.white,
                                  textStyle: TextStyle(fontSize: 12.sp),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _modalField('Home Address', addressCtrl, maxLines: 2),
                        SizedBox(height: 8.h),
                      ],
                    ),
                  ),
                  // Bottom buttons
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.r)),
                            ),
                            child: Text('Cancel',
                                style: TextStyle(
                                    fontSize: 14.sp, color: Colors.black)),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final updated = {
                                ..._user ?? {},
                                'name': nameCtrl.text.trim(),
                                'ic_number': icCtrl.text.trim(),
                                'date_of_birth': selectedDob != null
                                    ? _toPostgresDate(selectedDob!)
                                    : (_user?['date_of_birth'] ?? ''),
                                'phone_number': phoneCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                                'gender': gender,
                                'home_address': addressCtrl.text.trim(),
                              };
                              setState(() => _user = updated);
                              Navigator.pop(ctx);
                              _repo.updateUserProfile(widget.userId, {
                                'name': updated['name'],
                                'ic_number': updated['ic_number'],
                                'date_of_birth': updated['date_of_birth'],
                                'phone_number': updated['phone_number'],
                                'email': updated['email'],
                                'gender': updated['gender'],
                                'home_address': updated['home_address'],
                              }).then((_) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Personal info saved'),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }).catchError((e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Save failed: $e'),
                                        behavior: SnackBarBehavior.floating),
                                  );
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.r)),
                              elevation: 0,
                            ),
                            child: Text('Save',
                                style: TextStyle(fontSize: 14.sp)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _openBusinessModal() {
    final bizNameCtrl = TextEditingController(text: _business?['business_name'] ?? '');
    final ssmCtrl = TextEditingController(
        text: _business?['ssm_registration_number'] ?? '');
    final bizTypeCtrl = TextEditingController(text: _business?['type'] ?? '');
    final yearCtrl = TextEditingController(
        text: '${_business?['year_of_establishment'] ?? ''}');
    final bizAddressCtrl =
        TextEditingController(text: _business?['business_address'] ?? '');
    final bizPhoneCtrl =
        TextEditingController(text: _business?['contact_number'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                  child: Row(
                    children: [
                      Text('Edit Business Information',
                          style: TextStyle(
                              fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade100),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    children: [
                      _modalField('Business Name', bizNameCtrl),
                      _modalField('SSM Registration No.', ssmCtrl),
                      _modalField('Business Type', bizTypeCtrl),
                      _modalField('Year Established', yearCtrl,
                          keyboardType: TextInputType.number),
                      _modalField('Business Address', bizAddressCtrl,
                          maxLines: 2),
                      _modalField('Contact Number', bizPhoneCtrl,
                          keyboardType: TextInputType.phone),
                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.r)),
                          ),
                          child: Text('Cancel',
                              style: TextStyle(
                                  fontSize: 14.sp, color: Colors.black)),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final updated = {
                              ..._business ?? {},
                              'business_name': bizNameCtrl.text.trim(),
                              'ssm_registration_number': ssmCtrl.text.trim(),
                              'type': bizTypeCtrl.text.trim(),
                              'year_of_establishment': yearCtrl.text.trim(),
                              'business_address': bizAddressCtrl.text.trim(),
                              'contact_number': bizPhoneCtrl.text.trim(),
                            };
                            setState(() => _business = updated);
                            Navigator.pop(ctx);
                            _repo.updateBusinessProfile(widget.businessId, {
                              'business_name': updated['business_name'],
                              'ssm_registration_number':
                                  updated['ssm_registration_number'],
                              'type': updated['type'],
                              'year_of_establishment':
                                  updated['year_of_establishment'],
                              'business_address': updated['business_address'],
                              'contact_number': updated['contact_number'],
                            }).then((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Business info saved'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }).catchError((e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Save failed: $e'),
                                      behavior: SnackBarBehavior.floating),
                                );
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.r)),
                            elevation: 0,
                          ),
                          child:
                              Text('Save', style: TextStyle(fontSize: 14.sp)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onNext() {
    if (!_isPersonalComplete() || !_isBusinessComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required fields before proceeding.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFBA7517),
        ),
      );
      return;
    }
    widget.onNext();
  }

  String _toDisplayDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final personalComplete = _isPersonalComplete();
    final businessComplete = _isBusinessComplete();
    final canProceed = personalComplete && businessComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Is the information below correct?',
                  style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                ),
                SizedBox(height: 16.h),

                _sectionCard(
                  title: 'Personal Information',
                  isComplete: personalComplete,
                  onEdit: _openPersonalModal,
                  rows: [
                    ['Full Name', _user?['name'] ?? '-'],
                    ['NRIC', _user?['ic_number'] ?? '-'],
                    ['Date of Birth', _displayDate(_user?['date_of_birth'])],
                    ['Phone Number', _user?['phone_number'] ?? '-'],
                    ['Email Address', _user?['email'] ?? '-'],
                    ['Gender', _user?['gender'] ?? '-'],
                    ['Home Address', _user?['home_address'] ?? '-'],
                  ],
                ),
                SizedBox(height: 16.h),

                _sectionCard(
                  title: 'Business Information',
                  isComplete: businessComplete,
                  onEdit: _openBusinessModal,
                  rows: [
                    ['Business Name', _business?['business_name'] ?? '-'],
                    ['SSM Registration No.', _business?['ssm_registration_number'] ?? '-'],
                    ['Business Type', _business?['type'] ?? '-'],
                    ['Year Established', '${_business?['year_of_establishment'] ?? '-'}'],
                    ['Business Address', _business?['business_address'] ?? '-'],
                    ['Contact Number', _business?['contact_number'] ?? '-'],
                  ],
                ),

                if (!canProceed) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: const Color(0xFFBA7517).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16.sp, color: const Color(0xFFBA7517)),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Complete both sections to proceed.',
                            style: TextStyle(
                                fontSize: 12.sp,
                                color: const Color(0xFFBA7517)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canProceed ? _onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canProceed ? Colors.black : Colors.grey.shade300,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.r)),
                elevation: 0,
              ),
              child: Text('Next',
                  style: TextStyle(
                      fontSize: 15.sp, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required bool isComplete,
    required VoidCallback onEdit,
    required List<List<String>> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isComplete
              ? const Color(0xFF1D9E75).withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 12.w, 14.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14.sp, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6.w),
                    Icon(
                      isComplete
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16.sp,
                      color: isComplete
                          ? const Color(0xFF1D9E75)
                          : Colors.grey.shade400,
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 11.sp, color: Colors.white),
                        SizedBox(width: 4.w),
                        Text('Edit',
                            style: TextStyle(
                                fontSize: 11.sp, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          ...rows.map(
            (row) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row[0],
                      style: TextStyle(
                          fontSize: 11.sp, color: Colors.grey.shade500)),
                  SizedBox(height: 2.h),
                  Text(row[1],
                      style: TextStyle(
                          fontSize: 13.sp, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modalField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 6.h),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              filled: true,
              fillColor: const Color(0xFFF8F9FE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: Color(0xFF38B6FF)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
