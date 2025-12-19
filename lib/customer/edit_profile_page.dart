import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _aquaFixIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _contactNoController = TextEditingController();

  final _scrollController = ScrollController();

  DateTime? _selectedDate;
  String? _selectedGender;

  final _genders = ['Male', 'Female', 'Other'];

  void _pickDate() async {
    final now = DateTime.now();
    final lastAllowed = DateTime(now.year - 18, now.month, now.day); // 18+ only
    final firstAllowed = DateTime(1900);

    DateTime initialDate;
    if (_selectedDate != null &&
        !_selectedDate!.isAfter(lastAllowed) &&
        !_selectedDate!.isBefore(firstAllowed)) {
      initialDate = _selectedDate!;
    } else {
      initialDate = lastAllowed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstAllowed,
      lastDate: lastAllowed,
      helpText: 'Select your birthday',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Color(0xFF2C9CD9)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 14.sp),
      hintStyle: TextStyle(fontSize: 14.sp),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 14.sp),
      hintStyle: TextStyle(fontSize: 14.sp),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
    );
  }

  bool _isValidBirthday(DateTime birthday) {
    final today = DateTime.now();
    final age =
        today.year -
        birthday.year -
        ((today.month < birthday.month ||
                (today.month == birthday.month && today.day < birthday.day))
            ? 1
            : 0);
    return age >= 18;
  }

  Future<void> _updateProfile() async {
    // Birthday validation before saving
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your birthday.')),
      );
      return;
    }
    if (!_isValidBirthday(_selectedDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be at least 18 years old.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';

    // Only send fields that are editable here (no email, no password)
    final data = {
      "customer_id": customerId,
      "username": _usernameController.text.trim(),
      "first_name": _firstNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "aquafix_no": _aquaFixIdController.text.trim(),
      "contact_no": "+63${_contactNoController.text.trim()}",
      "birthday":
          _selectedDate != null
              ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
              : "",
      "gender": _selectedGender ?? "",
    };

    final response = await http.put(
      Uri.parse('https://aquafixsansimon.com/api/customers.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: ${response.body}')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCustomerIdAndProfile();
  }

  Future<void> _loadCustomerIdAndProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isNotEmpty) {
      _aquaFixIdController.text = customerId;
      await _loadProfileData(customerId);
    }
  }

  Future<void> _loadProfileData(String customerId) async {
    final response = await http.get(
      Uri.parse('https://aquafixsansimon.com/api/customers.php'),
    );
    if (response.statusCode == 200) {
      final List users = json.decode(response.body);
      final user = users.firstWhere(
        (u) => u['customer_id'].toString() == customerId,
        orElse: () => null,
      );
      if (user != null && mounted) {
        setState(() {
          _usernameController.text = user['username'] ?? '';
          _firstNameController.text = user['first_name'] ?? '';
          _lastNameController.text = user['last_name'] ?? '';
          _aquaFixIdController.text = user['aquafix_no'] ?? '';
          _contactNoController.text = (user['contact_no'] ?? '').replaceFirst(
            '+63',
            '',
          );
          _selectedGender = user['gender'] ?? '';
          _selectedDate =
              user['birthday'] != null && user['birthday'].toString().isNotEmpty
                  ? DateTime.tryParse(user['birthday'])
                  : null;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C9CD9),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 22.sp, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.all(20.w),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Account Information Section
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                TextFormField(
                  controller: _usernameController,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: _inputDecoration('Username'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _aquaFixIdController,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black87,
                  ), // match enabled fields
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration('AquaFix ID').copyWith(
                    fillColor: const Color.fromARGB(255, 255, 255, 255),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(
                        color: Colors.grey.shade600,
                        width: 1,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(
                        color: Colors.grey.shade600,
                        width: 1,
                      ),
                    ),
                  ),
                  readOnly: true, // not editable
                  enableInteractiveSelection: false, // can't select/copy
                  focusNode: AlwaysDisabledFocusNode(), // prevent focus
                ),
                SizedBox(height: 12.h),

                // Personal Information Section
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        style: TextStyle(fontSize: 14.sp),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z\s]'),
                          ),
                        ],
                        decoration: _inputDecoration('First Name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'First name is required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        style: TextStyle(fontSize: 14.sp),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z\s]'),
                          ),
                        ],
                        decoration: _inputDecoration('Last Name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Last name is required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text:
                        _selectedDate != null
                            ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                            : '',
                  ),
                  style: TextStyle(fontSize: 14.sp),
                  onTap: _pickDate,
                  decoration: _inputDecoration('Birthday').copyWith(
                    suffixIcon: Icon(Icons.calendar_today, size: 20.sp),
                    hintText: 'Select date',
                  ),
                  validator: (value) {
                    if (_selectedDate == null) {
                      return 'Birthday is required';
                    }
                    if (!_isValidBirthday(_selectedDate!)) {
                      return 'You must be at least 18 years old';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),
                DropdownButtonFormField2<String>(
                  value:
                      _selectedGender != null &&
                              _genders.contains(_selectedGender)
                          ? _selectedGender
                          : null,
                  isExpanded: true,
                  decoration: _dropdownDecoration('Gender (Optional)'),
                  items:
                      _genders
                          .map(
                            (gender) => DropdownMenuItem(
                              value: gender,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 8.h,
                                ),
                                child: Text(
                                  gender,
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                  selectedItemBuilder: (context) {
                    return _genders.map((gender) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(gender, style: TextStyle(fontSize: 14.sp)),
                      );
                    }).toList();
                  },
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  menuItemStyleData: MenuItemStyleData(
                    height: 38.h,
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(height: 12.h),
                // Phone Number Field with +63 prefix
                TextFormField(
                  controller: _contactNoController,
                  style: TextStyle(fontSize: 14.sp),
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  decoration: _inputDecoration(
                    'Phone Number (9XXXXXXXXX)',
                  ).copyWith(
                    prefixText: '+63 ',
                    prefixStyle: TextStyle(
                      color: Colors.black87,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    if (!RegExp(r'^9\d{9}$').hasMatch(value.trim())) {
                      return 'Enter a valid Philippine phone number (9XXXXXXXXX)';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 100.h),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 30.h),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C9CD9),
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'SAVE CHANGES',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Add this class at the end of the file (outside the widget class)
class AlwaysDisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}
