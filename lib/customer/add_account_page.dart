import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class AddAccountPage extends StatefulWidget {
  const AddAccountPage({super.key});

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _accountNumberDigitsController =
      TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _meterNoController = TextEditingController();
  final TextEditingController _bookSeqController = TextEditingController();

  String? selectedAccountClass;

  String? selectedProvince = "Pampanga";
  String? selectedMunicipality = "San Simon";
  String? selectedBarangay;

  Set<String> existingAccountNumbers = {};
  Set<String> existingMeterNumbers = {};
  Set<String> existingBookSequences = {};

  bool _loading = true;

  final List<String> barangays = [
    "Concepcion",
    "Dela Paz",
    "San Pedro",
    "San Juan",
    "San Pablo",
    "San Miguel",
    "Sta Monica",
    "Sta Cruz",
    "San Nicolas",
    "San Jose",
    "San Agustin",
    "San Isidro",
    "Santo Niño",
  ];

  final List<String> accountClasses = ["Residential", "Commercial"];

  String? customerFirstName;
  String? customerLastName;

  String? _labelError;

  bool _hasShownInfoModal = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerName();
    _fetchExistingAccounts().then((_) {
      setState(() {
        _loading = false; // Set loading to false after fetch
      });
    });
    // Only allow letters and spaces for account name
    _accountNameController.addListener(() {
      String text = _accountNameController.text;
      String filtered = text.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
      if (filtered != text) {
        _accountNameController.value = _accountNameController.value.copyWith(
          text: filtered,
          selection: TextSelection.collapsed(offset: filtered.length),
        );
      }
    });
    // Replace _accountNumberController logic with digits-only controller
    String? _previousAccountText;
    _accountNumberDigitsController.addListener(() {
      final oldText = _accountNumberDigitsController.text;
      final selection = _accountNumberDigitsController.selection;
      String digits = oldText.replaceAll('-', '');
      if (digits.length > 10) digits = digits.substring(0, 10);

      final isDeleting =
          _previousAccountText != null &&
          oldText.length < _previousAccountText!.length;

      if (isDeleting) {
        _previousAccountText = oldText;
        return;
      }

      String formatted = digits;
      if (digits.length > 2) {
        formatted = digits.substring(0, 2) + '-' + digits.substring(2);
      } else if (digits.length == 2) {
        formatted = digits + '-';
      }
      if (digits.length > 6) {
        formatted = formatted.substring(0, 7) + '-' + formatted.substring(7);
      } else if (digits.length == 6) {
        formatted = formatted + '-';
      }

      if (formatted != oldText) {
        _accountNumberDigitsController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }

      _previousAccountText = formatted;
    });

    // Book Sequence auto-dash logic
    String? _previousBookText;
    _bookSeqController.addListener(() {
      final oldText = _bookSeqController.text;
      final selection = _bookSeqController.selection;
      String digits = oldText.replaceAll('-', '');
      if (digits.length > 7) digits = digits.substring(0, 7);

      final isDeleting =
          _previousBookText != null &&
          oldText.length < _previousBookText!.length;

      if (isDeleting) {
        _previousBookText = oldText;
        return;
      }

      String formatted = digits;
      if (digits.length > 3) {
        formatted = digits.substring(0, 3) + '-' + digits.substring(3);
      } else if (digits.length == 3) {
        formatted = digits + '-';
      }

      if (formatted != oldText) {
        _bookSeqController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }

      _previousBookText = formatted;
    });
    selectedAccountClass = null; // default to null, force user to pick

    // Always show info modal when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInfoModal();
    });
  }

  void _showInfoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoModalContent(),
    );
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNumberDigitsController.dispose();
    _meterNoController.dispose();
    _labelController.dispose();
    _streetController.dispose();
    _bookSeqController.dispose();
    // no _accountClassController to dispose
    super.dispose();
  }

  Future<void> _fetchExistingAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('https://aquafixsansimon.com/api/clw_accounts_all.php'),
      );
      if (response.statusCode == 200) {
        final accounts = json.decode(response.body);
        if (accounts is List) {
          setState(() {
            existingAccountNumbers =
                accounts
                    .map((acc) => (acc['account_number'] ?? '').toString())
                    .toSet();
            existingMeterNumbers =
                accounts
                    .map((acc) => (acc['meter_no'] ?? '').toString())
                    .toSet();
            existingBookSequences =
                accounts
                    .map((acc) => (acc['book_seq'] ?? '').toString())
                    .toSet();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCustomerName() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) {
      customerFirstName = '';
      customerLastName = '';
      if (mounted) setState(() {});
      return;
    }
    try {
      final response = await http.get(
        Uri.parse(
          'https://aquafixsansimon.com/api/customers.php?customer_id=$customerId',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map) {
          customerFirstName = data['first_name'] ?? '';
          customerLastName = data['last_name'] ?? '';
          print(
            'Fetched first_name: $customerFirstName, last_name: $customerLastName',
          );
        } else if (data is List && data.isNotEmpty) {
          final customer = data.firstWhere(
            (c) => c['customer_id'].toString() == customerId,
            orElse: () => null,
          );
          customerFirstName = customer?['first_name'] ?? '';
          customerLastName = customer?['last_name'] ?? '';
          print(
            'Fetched first_name: $customerFirstName, last_name: $customerLastName',
          );
        }
      } else {
        customerFirstName = '';
        customerLastName = '';
      }
    } catch (e) {
      customerFirstName = '';
      customerLastName = '';
    }
    if (mounted) setState(() {});
  }

  // Helper: Levenshtein distance
  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    List<List<int>> dp = List.generate(
      a.length + 1,
      (_) => List.filled(b.length + 1, 0),
    );
    for (int i = 0; i <= a.length; i++) dp[i][0] = i;
    for (int j = 0; j <= b.length; j++) dp[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] =
              1 +
              [
                dp[i - 1][j], // delete
                dp[i][j - 1], // insert
                dp[i - 1][j - 1], // substitute
              ].reduce((a, b) => a < b ? a : b);
        }
      }
    }
    return dp[a.length][b.length];
  }

  bool _isSimilar(String a, String b) {
    a = a.trim().toLowerCase();
    b = b.trim().toLowerCase();
    if (a.isEmpty || b.isEmpty) return false;
    // Accept if substring or Levenshtein distance <= 2
    return a.contains(b) || b.contains(a) || _levenshtein(a, b) <= 2;
  }

  bool _isAccountNameValid(String accountName) {
    if (customerFirstName == null || customerLastName == null) return true;
    final parts = accountName.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return false;

    // First name part: all except last word
    final enteredFirstParts = parts.sublist(0, parts.length - 1);
    final enteredLast = parts.last;
    final regFirst = customerFirstName ?? '';
    final regLast = customerLastName ?? '';

    // Registered first name must be similar to any word in enteredFirstParts
    bool firstOk = enteredFirstParts.any((word) => _isSimilar(word, regFirst));
    // Registered last name must be similar to enteredLast
    bool lastOk = _isSimilar(enteredLast, regLast);

    return firstOk && lastOk;
  }

  Future<bool> _labelExists(String label) async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) return false;
    try {
      final response = await http.get(
        Uri.parse(
          'https://aquafixsansimon.com/api/clw_accounts.php?customer_id=$customerId',
        ),
      );
      if (response.statusCode == 200) {
        final accounts = json.decode(response.body);
        if (accounts is List) {
          return accounts.any(
            (acc) =>
                (acc['label']?.toString().toLowerCase() ?? '') ==
                label.trim().toLowerCase(),
          );
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      // Check for duplicate label

      // Compose account number with fixed AC
      final accountNumber = 'AC' + _accountNumberDigitsController.text;
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('customer_id') ?? '';
      final newAddress = {
        "customer_id": customerId,
        "label": _labelController.text,
        "street": _streetController.text,
        "barangay": selectedBarangay,
        "municipality": selectedMunicipality,
        "province": selectedProvince,
        "account_number": accountNumber,
        "account_name": _accountNameController.text,
        "meter_no": _meterNoController.text,
        "account_class": selectedAccountClass,
        "book_seq": _bookSeqController.text,
      };

      final response = await http.post(
        Uri.parse(
          'https://aquafixsansimon.com/api/jo_request.php?action=add_account',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newAddress),
      );

      if (response.statusCode == 200) {
        // Fix: Only try to decode if response is JSON (not HTML error)
        try {
          final resp = json.decode(response.body);
          final clwAccountId = resp['clw_account_id'] ?? resp['id'];
          Navigator.pop(context, clwAccountId);
        } catch (e) {
          // If response is not JSON, show error
          print('API Error (not JSON): ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add account. Please try again.')),
          );
        }
      } else {
        // Print error response for debugging
        print('API Error: ${response.body}');
        String errorMsg = 'Failed to add account.';
        try {
          final resp = json.decode(response.body);
          if (resp is Map &&
              (resp['message'] != null || resp['error'] != null)) {
            errorMsg = resp['message'] ?? resp['error'];
          }
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    }
  }

  Future<void> _checkLabelDuplicate(String label) async {
    if (label.trim().isEmpty) {
      setState(() => _labelError = null);
      return;
    }
    if (await _labelExists(label)) {
      setState(
        () =>
            _labelError =
                'The $label label already exists. Please choose a different label.',
      );
    } else {
      setState(() => _labelError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF2C9CD9);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          "Add CLW Account",
          style: TextStyle(fontSize: 18.sp, color: Colors.white),
        ),
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            tooltip: "How to fill up",
            onPressed: _showInfoModal,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Label
              TextFormField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: "Account Label",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  hintText: "e.g., Home, Office, Apartment",
                  errorText: _labelError,
                ),
                onChanged: (value) {
                  _checkLabelDuplicate(value);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter a label";
                  }
                  if (_labelError != null) {
                    return _labelError;
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Account Number (AC fixed)
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 16.h,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey),
                        top: BorderSide(color: Colors.grey),
                        bottom: BorderSide(color: Colors.grey),
                      ),
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(10.r),
                      ),
                      color: Colors.grey[200],
                    ),
                    child: Text(
                      "AC",
                      style: TextStyle(
                        fontSize: 15.7.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _accountNumberDigitsController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: "Account No.",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(10.r),
                          ),
                        ),
                        hintText: "12-3456-7890",
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 16.h,
                          horizontal: 12.w,
                        ),
                      ),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          12,
                        ), // allow up to 12 chars (digits + dashes)
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                      ],
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter account number";
                        }
                        final pattern = RegExp(r'^\d{2}-\d{4}-\d{4}$');
                        if (value.length != 12 || !pattern.hasMatch(value)) {
                          return "Format: 12-3456-7890";
                        }
                        final fullAccountNo = 'AC' + value;
                        if (existingAccountNumbers.contains(fullAccountNo)) {
                          return "Account number already exists";
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Account Name
              TextFormField(
                controller: _accountNameController,
                decoration: InputDecoration(
                  labelText: "Account Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  hintText: "e.g. Juan Dela Cruz",
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter account name";
                  }
                  if (value.trim().split(RegExp(r'\s+')).length < 2) {
                    return "Enter first and last name";
                  }
                  if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
                    return "Only letters and spaces allowed";
                  }
                  // Show error if not close to registered name
                  if (!(_isAccountNameValid(value))) {
                    return "Must match the name registered with CLW Account.”";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Account Class Dropdown
              DropdownButtonFormField<String>(
                value: selectedAccountClass,
                decoration: InputDecoration(
                  labelText: "Account Class",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                items:
                    accountClasses
                        .map(
                          (cls) =>
                              DropdownMenuItem(value: cls, child: Text(cls)),
                        )
                        .toList(),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? "Please select account class"
                            : null,
                onChanged: (value) {
                  setState(() {
                    selectedAccountClass = value;
                  });
                },
              ),
              SizedBox(height: 16.h),

              // Meter No.
              TextFormField(
                controller: _meterNoController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: "Meter No.",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  hintText: "5 digits",
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(5),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter meter no.";
                  }
                  if (value.length != 5) {
                    return "Meter no. must be exactly 5 digits";
                  }
                  if (existingMeterNumbers.contains(value)) {
                    return "Meter no. already exists";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Book Sequence
              TextFormField(
                controller: _bookSeqController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: "Book Sequence",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  hintText: "e.g., 123-4567",
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                  LengthLimitingTextInputFormatter(8),
                ],
                keyboardType: TextInputType.number,

                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter book sequence";
                  }
                  final pattern = RegExp(r'^\d{3}-\d{4}$');
                  if (!pattern.hasMatch(value)) {
                    return "Format: 123-4567";
                  }
                  if (existingBookSequences.contains(value)) {
                    return "Book sequence already exists";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Street
              TextFormField(
                controller: _streetController,
                decoration: InputDecoration(
                  labelText: "House No. / Purok / Street",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? "Please enter street details"
                            : null,
              ),
              SizedBox(height: 16.h),

              // Barangay Dropdown (Dynamic)
              DropdownButtonFormField<String>(
                value: selectedBarangay,
                decoration: InputDecoration(
                  labelText: "Barangay",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                items:
                    barangays
                        .map(
                          (bgy) =>
                              DropdownMenuItem(value: bgy, child: Text(bgy)),
                        )
                        .toList(),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? "Please select a barangay"
                            : null,
                onChanged: (value) {
                  setState(() {
                    selectedBarangay = value;
                  });
                },
              ),
              SizedBox(height: 16.h),

              // Municipality Dropdown (Disabled)
              DropdownButtonFormField<String>(
                value: selectedMunicipality,
                decoration: InputDecoration(
                  labelText: "Municipality",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "San Simon",
                    child: Text("San Simon"),
                  ),
                ],
                onChanged: null, // <- disable
              ),
              SizedBox(height: 16.h),

              // Province Dropdown (Disabled)
              DropdownButtonFormField<String>(
                value: selectedProvince,
                decoration: InputDecoration(
                  labelText: "Province",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: "Pampanga", child: Text("Pampanga")),
                ],
                onChanged: null, // <- disable
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _saveAddress,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              "Add Account",
              style: TextStyle(fontSize: 15.sp, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Modal content widget ---
class _InfoModalContent extends StatefulWidget {
  @override
  State<_InfoModalContent> createState() => _InfoModalContentState();
}

class _InfoModalContentState extends State<_InfoModalContent> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF2C9CD9);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),
          Text(
            "How to Fill Up Your CLW Account",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                // Slide 1: Sample water bill (original size)
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[100],
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/Water-Bill.png',
                          fit: BoxFit.contain, // show original size
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Find your Account No., Name, Meter No., Book Sequence, and Class in your water bill. Tap 'Next' for more tips.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ],
                ),
                // Slide 2: Highlight image + description
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[100],
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/Water-Bill-Highlight.png',
                          fit: BoxFit.contain, // show original size
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Tip: For best results, copy the details exactly as shown on your water bill. Use the registered name for Account Name (for example, 'Juan Dela Cruz').\n\nIf you need help, feel free to visit or contact our office—we’re happy to assist you!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              2,
              (i) => Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 16 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? primaryColor : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentPage > 0)
                TextButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.ease,
                    );
                  },
                  child: Text("Back"),
                )
              else
                SizedBox(width: 64),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  if (_currentPage < 1) {
                    _pageController.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.ease,
                    );
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  _currentPage < 1 ? "Next" : "Got it!",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
