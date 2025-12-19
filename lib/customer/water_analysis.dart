import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'clw_accounts_page.dart'; // Import the accounts page
import 'my_job_orders_page.dart'; // <-- NEW: import MyJobOrdersPage
import 'add_account_page.dart';
import 'dart:async';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:firebase_database/firebase_database.dart';

class WaterAnalysisPage extends StatefulWidget {
  final bool openAddModal;
  const WaterAnalysisPage({super.key, this.openAddModal = false});

  @override
  State<WaterAnalysisPage> createState() => _WaterAnalysisPageState();

  // Add this static method for navigation and showing the modal
  static void navigateAndShowAddModal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const WaterAnalysisPage(openAddModal: true),
      ),
    );
  }
}

class _WaterAnalysisPageState extends State<WaterAnalysisPage>
    with SingleTickerProviderStateMixin {
  final Map<String, List<Map<String, dynamic>>> _yearlyData = {};
  String _selectedYear = '';
  String? _modalSelectedMonth;
  String? _modalSelectedYear; // <-- Add for modal year selection
  final List<String> _months = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final Set<String> _jobOrderSubmitted = {};
  late AnimationController _hourglassController;
  final String apiUrl = 'https://aquafixsansimon.com/api/water_bills.php';
  String? _selectedAccount;
  int? _selectedClwAccountId;
  List<Map<String, dynamic>> _accounts = [];

  Timer? _saveRangeDebounce;
  DateTime _lastSaveTime = DateTime.fromMillisecondsSinceEpoch(0);

  final TextEditingController _avgConsFromController = TextEditingController();
  final TextEditingController _avgConsToController = TextEditingController();

  StreamSubscription<DatabaseEvent>? _firebaseSub;

  bool _isFetchingBills = false;

  Map<int, Map<String, dynamic>> _predictiveJobOrders = {};

  // Tutorial keys and state (NEW)
  final GlobalKey _yearKey = GlobalKey();
  final GlobalKey _monthKey = GlobalKey();
  final GlobalKey _accountKey = GlobalKey();
  final GlobalKey _avgRangeKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  bool _tutorialVisible = false;
  int _tutorialStep = 0;

  @override
  void initState() {
    super.initState();
    _hourglassController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(period: const Duration(seconds: 4));
    _initFetchSequence();
    _loadConsumptionRange();
    _listenToConsumptionRange();
    _avgConsFromController.addListener(_saveConsumptionRange);
    _avgConsToController.addListener(_saveConsumptionRange);

    // Show tutorial if needed after first frame (NEW)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowTutorial();
    });

    // If page requested to open add modal on navigation, show it after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.openAddModal) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) _showAddModal();
        });
      }
    });
  }

  void _listenToConsumptionRange() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) return;
    final ref = FirebaseDatabase.instance.ref(
      'average_consumption/$customerId',
    );
    _firebaseSub = ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        _avgConsFromController.text = data['from']?.toString() ?? '';
        _avgConsToController.text = data['to']?.toString() ?? '';
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId == null || customerId.isEmpty) return;
    final dbRef = FirebaseDatabase.instance.ref(
      'tutorials/$customerId/water_analysis',
    );
    final snapshot = await dbRef.get();
    final show = snapshot.value == true;
    if (!show) return;
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      _tutorialVisible = true;
      _tutorialStep = 0;
    });
  }

  Rect? _getWidgetRect(GlobalKey key) {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return null;
      final renderBox = ctx.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return null;
      final pos = renderBox.localToGlobal(Offset.zero);
      return Rect.fromLTWH(
        pos.dx,
        pos.dy,
        renderBox.size.width,
        renderBox.size.height,
      );
    } catch (_) {
      return null;
    }
  }

  void _advanceTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    const steps = 5;
    if (_tutorialStep >= steps - 1) {
      if (customerId != null && customerId.isNotEmpty) {
        final dbRef = FirebaseDatabase.instance.ref(
          'tutorials/$customerId/water_analysis',
        );
        await dbRef.set(false);
      }
      if (!mounted) return;
      setState(() {
        _tutorialVisible = false;
        _tutorialStep = 0;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _tutorialStep += 1;
      });
    }
  }

  Widget _buildTutorialOverlay() {
    final keys = [_yearKey, _accountKey, _monthKey, _avgRangeKey, _fabKey];
    final messages = [
      'Use this dropdown to choose the year of consumption data.',
      'Select the CLW account to analyze consumption for a specific account.',
      'Select the month to view or add bill data.',
      'Set your average consumption range here to enable anomaly detection.',
      'Tap here to add a new bill entry quickly.',
    ];
    final stepKey = (_tutorialStep < keys.length) ? keys[_tutorialStep] : null;
    final rect = stepKey != null ? _getWidgetRect(stepKey) : null;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advanceTutorial,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final screenH = constraints.maxHeight;
            const double horizPadding = 24;
            final double bubbleMaxWidth = (screenW - horizPadding * 2).clamp(
              0,
              360,
            );
            const double bubbleGap = 8;
            final message =
                (_tutorialStep < messages.length)
                    ? messages[_tutorialStep]
                    : '';

            const double triangleHeight = 10;
            final estimatedBubbleHeight = 110.0;
            double bubbleLeft = (screenW - bubbleMaxWidth) / 2;
            double bubbleTop = screenH - 120;
            double triangleLeft = screenW / 2 - 9;
            double triangleTop = bubbleTop - triangleHeight;
            bool placeAbove = false;

            if (rect != null) {
              final centerX = rect.left + rect.width / 2;
              triangleLeft = centerX - 9;

              // FAB step (last tutorial step)
              if (_tutorialStep == 4) {
                // Bubble above FAB, triangle between bubble and FAB
                bubbleLeft = (centerX - bubbleMaxWidth / 2).clamp(
                  24,
                  screenW - 24 - bubbleMaxWidth,
                );
                bubbleTop =
                    rect.top - estimatedBubbleHeight - triangleHeight - 8;
                triangleTop = bubbleTop + estimatedBubbleHeight;
                placeAbove = true; // triangle points up
              } else {
                // Default logic for other steps
                bubbleLeft = (centerX - bubbleMaxWidth / 2).clamp(
                  24,
                  screenW - 24 - bubbleMaxWidth,
                );

                // Decide if bubble should be above or below
                bubbleTop = rect.top + rect.height + triangleHeight + 8;
                if (bubbleTop + estimatedBubbleHeight > screenH - 28) {
                  placeAbove = true;
                  bubbleTop =
                      rect.top - estimatedBubbleHeight - triangleHeight - 8;
                  triangleTop = bubbleTop + estimatedBubbleHeight;
                } else {
                  placeAbove = false;
                  triangleTop = bubbleTop - triangleHeight;
                }
              }
            }

            return Stack(
              children: [
                if (rect != null) ...[
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 0,
                    height: rect.top - 8,
                    child: Container(color: Colors.black54),
                  ),
                  Positioned(
                    left: 0,
                    top: rect.top + rect.height + 8,
                    right: 0,
                    bottom: 0,
                    child: Container(color: Colors.black54),
                  ),
                  Positioned(
                    left: 0,
                    top: rect.top - 8,
                    width: rect.left - 8,
                    height: rect.height + 16,
                    child: Container(color: Colors.black54),
                  ),
                  Positioned(
                    left: rect.left + rect.width + 8,
                    top: rect.top - 8,
                    right: 0,
                    height: rect.height + 16,
                    child: Container(color: Colors.black54),
                  ),
                  Positioned(
                    left: rect.left - 8,
                    top: rect.top - 8,
                    width: rect.width + 16,
                    height: rect.height + 16,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                  // Calculate bubble and triangle positions

                  // Triangle pointer
                  Positioned(
                    left: triangleLeft,
                    top: triangleTop,
                    child: CustomPaint(
                      size: const Size(18, 10),
                      painter: _TrianglePainter(
                        color: Colors.white,
                        pointingUp: !placeAbove,
                      ),
                    ),
                  ),
                  // Bubble
                  Positioned(
                    left: bubbleLeft,
                    top: (!placeAbove) ? bubbleTop : bubbleTop + 67.h,
                    child: Container(
                      width: bubbleMaxWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top:
                        (!placeAbove)
                            ? rect.top + rect.height + 10 + 82
                            : bubbleTop + 122,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.touch_app, color: Colors.white, size: 32),
                        SizedBox(height: 8),
                        Text(
                          'Tap to continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ] else
                  Container(color: Colors.black54),
              ],
            );
          },
        ),
      ),
    );
  }

  // Load saved range from Realtime Database
  Future<void> _loadConsumptionRange() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) return;
    final ref = FirebaseDatabase.instance.ref(
      'average_consumption/$customerId',
    );
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        if (data['from'] != null) {
          _avgConsFromController.text = data['from'].toString();
        }
        if (data['to'] != null) {
          _avgConsToController.text = data['to'].toString();
        }
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _saveConsumptionRange() async {
    // Cancel any previous timer
    _saveRangeDebounce?.cancel();

    // Debounce: only allow save once every 4 seconds
    final now = DateTime.now();
    final diff = now.difference(_lastSaveTime);
    if (diff.inSeconds < 1) {
      // Schedule save after remaining time
      _saveRangeDebounce = Timer(
        Duration(seconds: 1 - diff.inSeconds),
        () async {
          await _actuallySaveConsumptionRange();
        },
      );
      return;
    }
    await _actuallySaveConsumptionRange();
  }

  // Actual save logic
  Future<void> _actuallySaveConsumptionRange() async {
    _lastSaveTime = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) {
      debugPrint('No customer_id found, not saving to Firebase.');
      return;
    }
    final ref = FirebaseDatabase.instance.ref(
      'average_consumption/$customerId',
    );
    try {
      await ref.set({
        'from': _avgConsFromController.text,
        'to': _avgConsToController.text,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Saved range to Realtime Database for $customerId');
    } catch (e) {
      debugPrint('Error saving range: $e');
    }
  }

  Future<void> _initFetchSequence() async {
    await _fetchAccounts(); // 1️⃣ get accounts
    if (_selectedAccount != null && _selectedAccount != 'No Account') {
      await _fetchWaterBills(); // 2️⃣ fetch bills for selected account
    }
  }

  @override
  void dispose() {
    _hourglassController.dispose();
    _avgConsFromController.removeListener(_saveConsumptionRange);
    _avgConsToController.removeListener(_saveConsumptionRange);
    super.dispose();
    _firebaseSub?.cancel();
  }

  Future<void> _fetchWaterBills() async {
    if (mounted) setState(() => _isFetchingBills = true);
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    final clwAccountId = _selectedAccount;

    if (customerId.isEmpty) {
      if (mounted) {
        setState(() {
          _yearlyData.clear();
          _selectedYear = '';
          _isFetchingBills = false;
        });
      }
      return;
    }

    String url = '$apiUrl?customer_id=$customerId';
    if (_selectedClwAccountId != null) {
      url += '&clw_account_id=$_selectedClwAccountId';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List bills = json.decode(response.body);
      final Map<String, List<Map<String, dynamic>>> yearly = {};

      // --- Collect bill_ids for job order lookup ---
      List<int> billIds = [];

      for (final bill in bills) {
        final year = bill['year'].toString();
        yearly.putIfAbsent(year, () => []);
        final billId = int.tryParse(bill['bill_id']?.toString() ?? '') ?? null;
        yearly[year]!.add({
          "month": bill['month'],
          "consumption": int.tryParse(bill['consumption'].toString()) ?? 0,
          "price": double.tryParse(bill['price'].toString()) ?? 0.0,
          "amount": double.tryParse(bill['amount'].toString()) ?? 0.0,
          "clw_account_id": bill['clw_account_id'] ?? "",
          "bill_id": billId,
        });
        if (billId != null) billIds.add(billId);
      }

      await _fetchPredictiveJobOrders(billIds);

      if (mounted) {
        setState(() {
          _yearlyData.clear();
          _yearlyData.addAll(yearly);

          // Always reset to most recent year
          if (_yearlyData.isNotEmpty) {
            final years = _yearlyData.keys.map((y) => int.parse(y)).toList();
            years.sort();
            _selectedYear = years.last.toString();
          } else {
            _selectedYear = '';
          }
          _isFetchingBills = false;

          print("After fetchWaterBills:");
          print("Selected account: $_selectedAccount");
          print("Yearly keys: ${_yearlyData.keys}");
          print("Selected year: $_selectedYear");
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _yearlyData.clear();
          _selectedYear = '';
          _isFetchingBills = false;
        });
      }
    }
  }

  Future<void> _fetchPredictiveJobOrders(List<int> billIds) async {
    _predictiveJobOrders.clear();
    if (billIds.isEmpty) return;
    try {
      final resp = await http.post(
        Uri.parse('https://aquafixsansimon.com/api/predictive_job_orders.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'bill_ids': billIds}),
      );
      if (resp.statusCode == 200) {
        final List jobs = json.decode(resp.body);
        for (final job in jobs) {
          final billId = int.tryParse(job['bill_id']?.toString() ?? '') ?? null;
          if (billId != null) {
            _predictiveJobOrders[billId] = job;
          }
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('Error fetching predictive job orders: $e');
    }
  }

  Future<void> _addWaterBill({
    required String year,
    required String month,
    required int consumption,
    required double price,
    required double amount,
    int? clwAccountId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) return;
    final data = {
      "customer_id": int.tryParse(customerId) ?? 0,
      "year": int.tryParse(year) ?? 0,
      "month": month,
      "consumption": consumption,
      "price": price,
      "amount": amount,
      "clw_account_id": clwAccountId ?? _selectedClwAccountId,
    };
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      await _fetchWaterBills();
    } else {
      String errorMsg = 'Failed to add water bill.';
      try {
        final resp = json.decode(response.body);
        if (resp is Map && resp['error'] != null) {
          errorMsg = resp['error'].toString();
        }
      } catch (_) {}
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    }
  }

  // Add: Predict job order category using ML API
  Future<String?> _predictJobOrderCategory({
    required String accountNo,
    required String accountName,
    required String category,
    required String note,
    required String year,
    required String month,
  }) async {
    try {
      // Find the bill entry for the selected year/month
      final billEntry = (_yearlyData[year] ?? []).firstWhere(
        (e) => e['month'] == month,
        orElse: () => {},
      );

      // Find previous month entry for previous_cum
      int monthIndex = _months.indexOf(month);
      String? prevMonth = monthIndex > 0 ? _months[monthIndex - 1] : null;
      final prevEntry =
          prevMonth != null
              ? (_yearlyData[year] ?? []).firstWhere(
                (e) => e['month'] == prevMonth,
                orElse: () => {},
              )
              : {};

      // Get account details for barangay and account class
      final selectedAccountDetails = _accounts.firstWhere(
        (acc) => acc['account_number']?.toString() == _selectedAccount,
        orElse: () => {},
      );
      final String barangay =
          selectedAccountDetails['barangay'] ?? 'Concepcion';
      final String accountClassRaw =
          selectedAccountDetails['account_class'] ?? 'Residential';

      // Map account class to RES/COM
      final String accountClass =
          accountClassRaw == 'Residential' ? 'RES' : 'COM';

      // Map months to typical Philippine weather/season (Excel logic)
      String getSeason(String month) {
        int monthNum = _months.indexOf(month) + 1;
        if (monthNum == 12 || monthNum == 1 || monthNum == 2) {
          return "Cool / Cloudy";
        } else if (monthNum >= 3 && monthNum <= 5) {
          return "Dry / Sunny";
        } else {
          return "Wet / Rainy";
        }
      }

      // Compute fluctuation based on average range, matching the data table logic
      final int from = int.tryParse(_avgConsFromController.text) ?? 0;
      final int to = int.tryParse(_avgConsToController.text) ?? 0;
      final double avg = (from + to) / 2.0;
      final int presentCum =
          billEntry.isNotEmpty ? billEntry['consumption'] ?? 0 : 0;
      double fluctuationPct = avg == 0 ? 0 : ((presentCum - avg) / avg);
      // Also print the fluctuation as shown in the table
      final double fluctuationTable =
          avg == 0 ? 0 : ((presentCum - avg) / avg) * 100;
      print(
        'fluctuation (table %): ' + fluctuationTable.toStringAsFixed(1) + '%',
      );

      String getConsumptionTrend(int prev, int present) {
        if (prev == 0 && present == 0) return "No Consumption";
        if (prev == 0) return "New";
        if (present == 0) return "No Consumption";

        double pctChange = (present - prev) / prev;

        if (pctChange.abs() > 2) return "Anomaly";
        if (pctChange > 0.10) return "Increase";
        if (pctChange < -0.10) return "Decrease";
        return "Stable";
      }

      // Use current day for jo_date instead of always "01"
      final now = DateTime.now();
      int monthNum = _months.indexOf(month) + 1;
      String joDate =
          "$year-${monthNum.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      print('fluctuationPct (for ML): ' + fluctuationPct.toString());

      // Build payload to match FastAPI
      final payload = {
        "previous_cum":
            prevEntry.isNotEmpty ? prevEntry['consumption'] ?? 0 : 0,
        "present_cum": billEntry.isNotEmpty ? billEntry['consumption'] ?? 0 : 0,
        "fluctuation": fluctuationPct,
        "consumption_trend": getConsumptionTrend(
          prevEntry.isNotEmpty ? prevEntry['consumption'] ?? 0 : 0,
          billEntry.isNotEmpty ? billEntry['consumption'] ?? 0 : 0,
        ),
        "barangay": barangay, // Use barangay from account
        "acct_class": accountClass, // Use mapped account class (RES/COM)
        "weather_season": getSeason(month),
      };

      debugPrint("Prediction API payload: ${jsonEncode(payload)}");

      final response = await http.post(
        Uri.parse("https://aquafix-ml-api.onrender.com/predict"),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": "0c6ae6e4a29e69f82c7f1d844f171b72",
        },
        body: json.encode(payload),
      );

      print("Prediction API status: ${response.statusCode}");
      print("Prediction API response: ${response.body}");
      if (response.statusCode == 200) {
        final resp = json.decode(response.body);
        print("Decoded prediction response: $resp");
        return resp["predicted_category"]?.toString();
      }
    } catch (e) {
      print("Prediction API error: $e");
    }
    return null;
  }

  DateTime? _lastTooltipTime;

  void _showJobOrderStatusTooltip(
    BuildContext context,
    String status,
    Offset iconOffset,
  ) {
    // Prevent showing tooltip if last shown was less than 1 second ago
    if (_lastTooltipTime != null &&
        DateTime.now().difference(_lastTooltipTime!) <
            const Duration(seconds: 1)) {
      return;
    }
    _lastTooltipTime = DateTime.now();

    String message;
    switch (status.toLowerCase()) {
      case 'pending':
        message = "The job order sent was Pending.";
        break;
      case 'dispatched':
        message = "The job order is Ongoing.";
        break;
      case 'accomplished':
        message = "The job order was Accomplished.";
        break;
      case 'cancelled':
        message = "The job order was Cancelled.";
        break;
      default:
        message = "Job order status: $status";
    }

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder:
          (context) => Positioned(
            left: iconOffset.dx - 200,
            top: iconOffset.dy - 40,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  // Helper to normalize predicted category to dropdown value
  String? normalizeCategory(String? predicted) {
    if (predicted == null) return null;
    // Map lowercased predicted values to dropdown values
    final Map<String, String> categoryMap = {
      'busted pipe': 'Busted Pipe',
      'busted mainline': 'Busted Mainline',
      'busted meter stand': 'Busted Meter Stand',
      'change ball valve': 'Change Ball Valve',
      'change meter': 'Change Meter',
      'relocate meter stand': 'Relocate Meter Stand',
      'elevate meter stand': 'Elevate Meter Stand',
      'drain mainline': 'Drain Mainline',
      'drain meter stand': 'Drain Meter Stand',
    };
    final key = predicted.trim().toLowerCase();
    return categoryMap[key];
  }

  // Add parameter to optionally prefill category and disable editing
  void _showJobOrderModal(
    BuildContext context,
    String year,
    String month, {
    String? prefillCategory,
    bool categoryReadOnly = false,
    double? fluctuationPct,
  }) {
    final TextEditingController accountNoController = TextEditingController();
    final TextEditingController accountNameController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    String? selectedCategory = normalizeCategory(prefillCategory);
    String? predictedCategory = normalizeCategory(prefillCategory);

    // Get account details for explanation
    final selectedAccountDetails = _accounts.firstWhere(
      (acc) => acc['account_number']?.toString() == _selectedAccount,
      orElse: () => {},
    );
    final String barangay = selectedAccountDetails['barangay'] ?? 'Concepcion';
    final String accountClassRaw =
        selectedAccountDetails['account_class'] ?? 'Residential';
    final String accountClass =
        accountClassRaw == 'Residential' ? 'RES' : 'COM';

    // Get fluctuation and weather season for explanation
    final billEntry = (_yearlyData[year] ?? []).firstWhere(
      (e) => e['month'] == month,
      orElse: () => {},
    );

    // Recompute avg from controllers (same logic as prediction)
    final int avgFrom = int.tryParse(_avgConsFromController.text) ?? 0;
    final int avgTo = int.tryParse(_avgConsToController.text) ?? 0;
    final double avg = (avgFrom + avgTo) / 2.0;
    final int presentCum =
        billEntry.isNotEmpty ? (billEntry['consumption'] ?? 0) : 0;

    // Determine fluctuation fraction robustly
    // If fluctuationPct param is null -> compute from avg & presentCum
    // If supplied, detect whether it's a fraction (<= 5) or already percent (> 5)
    double fluctuationFraction;
    if (fluctuationPct == null) {
      fluctuationFraction = avg == 0 ? 0.0 : ((presentCum - avg) / avg);
    } else {
      // defensive: if value is tiny (<= 5) assume fraction like 0.12 -> 12%
      // otherwise treat it as percent (e.g., 12.0) and convert to fraction
      if (fluctuationPct.abs() <= 5.0) {
        fluctuationFraction = fluctuationPct;
      } else {
        fluctuationFraction = fluctuationPct / 100.0;
      }
    }

    // debug print (remove later if noisy)
    debugPrint(
      'Modal: fluctuation param=$fluctuationPct, computedFraction=$fluctuationFraction, avg=$avg, present=$presentCum',
    );

    // Final display string (always show as percent)
    final String fluctuationStr = (fluctuationFraction * 100).toStringAsFixed(
      1,
    );

    // weather season (unchanged)
    final String weatherSeason =
        (() {
          int monthNum = _months.indexOf(month) + 1;
          if (monthNum == 12 || monthNum == 1 || monthNum == 2) {
            return "Cool / Cloudy";
          } else if (monthNum >= 3 && monthNum <= 5) {
            return "Dry / Sunny";
          } else {
            return "Wet / Rainy";
          }
        })();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> updatePrediction() async {
              // Only predict if not read-only
              if (!categoryReadOnly && selectedCategory != null) {
                final prediction = await _predictJobOrderCategory(
                  accountNo: accountNoController.text,
                  accountName: accountNameController.text,
                  category: selectedCategory ?? "",
                  note: noteController.text,
                  year: year,
                  month: month,
                );
                setModalState(() {
                  predictedCategory = normalizeCategory(prediction);
                  selectedCategory = normalizeCategory(prediction);
                });
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(18.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Request Job Order',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(Icons.close, size: 22.sp),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      hint: const Text('Category'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Busted Pipe',
                          child: Text('Busted Pipe'),
                        ),
                        DropdownMenuItem(
                          value: 'Busted Mainline',
                          child: Text('Busted Mainline'),
                        ),
                        DropdownMenuItem(
                          value: 'Busted Meter Stand',
                          child: Text('Busted Meter Stand'),
                        ),
                        DropdownMenuItem(
                          value: 'Change Ball Valve',
                          child: Text('Change Ball Valve'),
                        ),
                        DropdownMenuItem(
                          value: 'Change Meter',
                          child: Text('Change Meter'),
                        ),
                        DropdownMenuItem(
                          value: 'Relocate Meter Stand',
                          child: Text('Relocate Meter Stand'),
                        ),
                        DropdownMenuItem(
                          value: 'Elevate Meter Stand',
                          child: Text('Elevate Meter Stand'),
                        ),
                        DropdownMenuItem(
                          value: 'Drain Mainline',
                          child: Text('Drain Mainline'),
                        ),
                        DropdownMenuItem(
                          value: 'Drain Meter Stand',
                          child: Text('Drain Meter Stand'),
                        ),
                      ],
                      onChanged:
                          categoryReadOnly
                              ? null
                              : (val) {
                                selectedCategory = val;
                                updatePrediction();
                              },
                      disabledHint:
                          selectedCategory != null
                              ? Text(selectedCategory!)
                              : null,
                    ),
                    // Show predicted category below dropdown only if not read-only
                    if (predictedCategory != null && !categoryReadOnly)
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb,
                              color: Colors.blue,
                              size: 18.sp,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                "Predicted category: $predictedCategory",
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Note (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                      ),
                      onChanged: (_) => updatePrediction(),
                    ),
                    SizedBox(height: 12.h),
                    // Modern explanation card
                    if (predictedCategory != null && categoryReadOnly)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.08),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .center, // <-- center vertically
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: EdgeInsets.all(6.w),
                                    child: Icon(
                                      Icons.info_outline,
                                      color: Colors.blue.shade700,
                                      size: 20.sp,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Why we suggest this job",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14.sp,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 6.h),
                            explainPrediction(
                              category: predictedCategory!,
                              fluctuation: fluctuationStr,
                              acctClass: accountClass,
                              weatherSeason: weatherSeason,
                              barangay: barangay,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.blueGrey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 18.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            _jobOrderSubmitted.add('$year|$month');
                          });
                          final customerId =
                              int.tryParse(
                                selectedAccountDetails['customer_id']
                                        ?.toString() ??
                                    '',
                              ) ??
                              0;
                          final clwAccountId =
                              int.tryParse(
                                selectedAccountDetails['clw_account_id']
                                        ?.toString() ??
                                    '',
                              ) ??
                              0;
                          final category = selectedCategory ?? '';
                          final notes = noteController.text.trim();
                          final billId = billEntry['bill_id'] ?? null;
                          final progressController = StreamController<double>();
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (_) => _ProgressModal(
                                  progressStream: progressController.stream,
                                ),
                          );
                          progressController.add(0.1);
                          await Future.delayed(
                            const Duration(milliseconds: 400),
                          );
                          await submitJobOrder(
                            customerId: customerId,
                            clwAccountId: clwAccountId,
                            category: category,
                            notes: notes,
                            isPredictive: 1,
                            fluctuation: double.tryParse(fluctuationStr) ?? 0.0,
                            billId:
                                billId is int
                                    ? billId
                                    : int.tryParse(billId?.toString() ?? ''),
                          );
                          progressController.add(1.0);
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                          progressController.close();
                          Navigator.of(context, rootNavigator: true).pop();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D9FD0),
                          minimumSize: Size.fromHeight(44.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Submit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Method that handles water bill deletion
  Future<void> _deleteWaterBill(int billId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl?bill_id=$billId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      setState(() {
        // Remove the bill from _yearlyData
        _yearlyData.forEach((year, bills) {
          bills.removeWhere((bill) => bill['bill_id'] == billId);
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill deleted successfully')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete bill')));
    }
  }

  // Dart version of explain_prediction logic
  Widget explainPrediction({
    required String category,
    required String fluctuation,
    required String acctClass,
    required String weatherSeason,
    required String barangay,
    TextStyle? style,
  }) {
    // Normalize category for comparison
    final String key = category.trim().toLowerCase();

    // Map acct class codes to readable strings
    final String readableAcctClass =
        acctClass == "RES"
            ? "Residential"
            : acctClass == "COM"
            ? "Commercial"
            : acctClass;

    // Normalize weather season values
    final String readableSeason =
        weatherSeason.contains("Sunny")
            ? "Summer season"
            : weatherSeason.contains("Rainy")
            ? "Rainy season"
            : weatherSeason.contains("Cloudy")
            ? "Cool season"
            : weatherSeason;

    // Default base style if none provided
    final TextStyle baseStyle =
        style ?? TextStyle(fontSize: 13.sp, color: Colors.blueGrey.shade800);

    // Semi-bold style for factor values
    final TextStyle semiBold = baseStyle.copyWith(fontWeight: FontWeight.w600);

    // Helper to create bolded value spans
    TextSpan kv(String value) => TextSpan(text: value, style: semiBold);

    // Wrapper to ensure justify alignment
    Widget rich(List<TextSpan> children) => Text.rich(
      TextSpan(style: baseStyle, children: children),
      textAlign: TextAlign.justify,
    );

    switch (key) {
      case 'change meter':
        return rich([
          const TextSpan(text: "Likely due to a ("),
          kv("$fluctuation%"),
          const TextSpan(text: ") fluctuation in "),
          kv(readableAcctClass),
          const TextSpan(text: " accounts at "),
          kv(barangay),
          const TextSpan(text: " during "),
          kv(readableSeason),
          const TextSpan(text: ", where meter replacement is common."),
        ]);

      case 'busted pipe':
        return rich([
          const TextSpan(text: "A ("),
          kv("$fluctuation%"),
          const TextSpan(text: ") fluctuation suggests pipe issues in "),
          kv(readableAcctClass),
          const TextSpan(text: " accounts at "),
          kv(barangay),
          const TextSpan(text: " during "),
          kv(readableSeason),
          const TextSpan(text: "."),
        ]);

      case 'busted meter stand':
        return rich([
          const TextSpan(text: "Irregular readings ("),
          kv("$fluctuation%"),
          const TextSpan(text: ") in "),
          kv(readableAcctClass),
          const TextSpan(text: " accounts at "),
          kv(barangay),
          const TextSpan(text: " during "),
          kv(readableSeason),
          const TextSpan(text: " point to a damaged meter stand."),
        ]);

      case 'change ball valve':
        return rich([
          const TextSpan(text: "A ("),
          kv("$fluctuation%"),
          const TextSpan(
            text: ") fluctuation indicates valve problems, common in ",
          ),
          kv(readableAcctClass),
          const TextSpan(text: " accounts at "),
          kv(barangay),
          const TextSpan(text: " during "),
          kv(readableSeason),
          const TextSpan(text: "."),
        ]);

      case 'elevate meter stand':
        return rich([
          const TextSpan(text: "In "),
          kv(barangay),
          const TextSpan(text: ", flooding in "),
          kv(readableSeason),
          const TextSpan(
            text: " often requires elevating meter stands, especially with a (",
          ),
          kv("$fluctuation%"),
          const TextSpan(text: ") change in "),
          kv(readableAcctClass),
          const TextSpan(text: " accounts."),
        ]);

      case 'busted mainline':
        return rich([
          const TextSpan(text: "A ("),
          kv("$fluctuation%"),
          const TextSpan(
            text: ") spike suggests mainline issues, often affecting ",
          ),
          kv(readableAcctClass),
          const TextSpan(text: " accounts in "),
          kv(barangay),
          const TextSpan(text: " during "),
          kv(readableSeason),
          const TextSpan(text: "."),
        ]);

      case 'relocate meter stand':
        return rich([
          const TextSpan(text: "Relocation is predicted as "),
          kv(readableAcctClass),
          const TextSpan(text: " accounts in "),
          kv(barangay),
          const TextSpan(text: " often do so in "),
          kv(readableSeason),
          const TextSpan(text: " with ("),
          kv("$fluctuation%"),
          const TextSpan(text: ") changes."),
        ]);

      case 'drain meter stand':
        return rich([
          const TextSpan(text: "("),
          kv("$fluctuation%"),
          const TextSpan(
            text: ") change indicates draining the meter stand, common in ",
          ),
          kv(readableAcctClass),
          const TextSpan(text: " accounts at "),
          kv(barangay),
          const TextSpan(text: " during "),
          kv(readableSeason),
          const TextSpan(text: "."),
        ]);

      case 'drain mainline':
        return rich([
          kv(readableAcctClass),
          const TextSpan(text: " accounts in "),
          kv(barangay),
          const TextSpan(text: " often need mainline draining during "),
          kv(readableSeason),
          const TextSpan(text: " when ("),
          kv("$fluctuation%"),
          const TextSpan(text: ") fluctuation occurs."),
        ]);

      default:
        return rich([
          const TextSpan(text: "The prediction "),
          TextSpan(text: category, style: semiBold),
          const TextSpan(text: " is based on ("),
          kv("$fluctuation%"),
          const TextSpan(text: ") fluctuation and "),
          kv(readableAcctClass),
          const TextSpan(text: " accounts at "),
          kv(barangay),
          const TextSpan(text: " during "),
          kv(readableSeason),
          const TextSpan(text: "."),
        ]);
    }
  }

  // Add this widget near the top-level (outside any class)
  Widget explainConsumptionChange({
    required String fluctuation, // e.g. "25" or "25.0" (percent)
    required String acctClass, // "RES", "COM", or readable
    required double consumption, // current consumption (m³)
    required double avgConsumption, // average consumption (m³)
    required int month, // clicked month 1..12
    TextStyle? style,
  }) {
    // --- Helpers & styles ---
    final String readableAcctClass =
        acctClass.toUpperCase() == "RES"
            ? "Residential"
            : acctClass.toUpperCase() == "COM"
            ? "Commercial"
            : acctClass;

    final TextStyle baseStyle =
        style ?? TextStyle(fontSize: 13.sp, color: Colors.blueGrey.shade800);
    final TextStyle semiBold = baseStyle.copyWith(fontWeight: FontWeight.w600);
    TextSpan v(String text) => TextSpan(text: text, style: semiBold);

    // --- Determine season ---
    String seasonFromMonth;
    if (month == 12 || month == 1 || month == 2) {
      seasonFromMonth = "Cool";
    } else if (month >= 3 && month <= 6) {
      seasonFromMonth = "Summer";
    } else if (month >= 7 && month <= 11) {
      seasonFromMonth = "Rainy";
    } else {
      seasonFromMonth = "Unknown";
    }

    // --- Parse fluctuation ---
    final double fl = double.tryParse(fluctuation.replaceAll('%', '')) ?? 0.0;
    final bool increase = fl > 0;
    final bool decrease = fl < 0;

    // --- Tier lookup function ---
    Map<String, dynamic> getTier(double cons) {
      if (readableAcctClass == "Residential") {
        if (cons <= 10) return {"range": "0–10 m³", "rate": 33.4};
        if (cons <= 20) return {"range": "11–20 m³", "rate": 34.7};
        if (cons <= 30) return {"range": "21–30 m³", "rate": 36.0};
        if (cons <= 40) return {"range": "31–40 m³", "rate": 37.2};
        if (cons <= 50) return {"range": "41–50 m³", "rate": 41.0};
        return {"range": "Over 50 m³", "rate": 43.6};
      } else {
        if (cons <= 15) return {"range": "0–15 m³", "rate": 58.8};
        if (cons <= 30) return {"range": "16–30 m³", "rate": 60.5};
        if (cons <= 500) return {"range": "31–500 m³", "rate": 63.9};
        if (cons <= 1000) return {"range": "501–1000 m³", "rate": 63.9};
        return {"range": "Over 1000 m³", "rate": 74.0};
      }
    }

    // Current and average tier/rates
    final currTier = getTier(consumption);
    final avgTier = getTier(avgConsumption);

    final String currTierRange = currTier["range"];
    final double currTierRate = currTier["rate"];
    final String avgTierRange = avgTier["range"];
    final double avgTierRate = avgTier["rate"];

    final String currRateStr = "₱${currTierRate.toStringAsFixed(2)}/m³";
    final String avgRateStr = "₱${avgTierRate.toStringAsFixed(2)}/m³";

    List<TextSpan> children = [];

    // --- Explanations ---
    if (increase) {
      if (currTierRange != avgTierRange) {
        // Jumped to higher tier
        children.addAll([
          const TextSpan(text: "Your bill increased because your consumption "),
          const TextSpan(text: "jumped up from "),
          v(avgTierRange),
          const TextSpan(text: " ("),
          v(avgRateStr),
          const TextSpan(text: ") "),
          const TextSpan(text: "to "),
          v(currTierRange),
          const TextSpan(text: " ("),
          v(currRateStr),
          const TextSpan(text: "). "),
          const TextSpan(text: "This move placed you in a higher rate tier."),
        ]);
      } else {
        // Stayed in same tier, just used more
        children.addAll([
          const TextSpan(
            text:
                "Your bill increased because your consumption rose within the ",
          ),
          v(currTierRange),
          const TextSpan(text: " tier ("),
          v(currRateStr),
          const TextSpan(text: "). "),
          const TextSpan(
            text:
                "Even though the rate per cubic meter stayed the same, the total usage went up.",
          ),
        ]);
      }

      // Seasonal notes
      if (seasonFromMonth == "Summer") {
        children.add(
          const TextSpan(
            text:
                " Summer season typically increases water usage and can amplify bill increases.",
          ),
        );
      } else if (seasonFromMonth == "Rainy") {
        children.add(
          const TextSpan(
            text:
                " Rainy season usually reduces usage; an increase during this time may suggest leaks or unusual demand.",
          ),
        );
      } else if (seasonFromMonth == "Cool") {
        children.add(
          const TextSpan(
            text:
                " During Cool season, usage patterns are usually moderate compared to peak summer.",
          ),
        );
      }

      if (fl.abs() >= 15) {
        children.add(
          const TextSpan(
            text:
                " The increase is significant — consider checking for leaks, new appliances, or higher household demand.",
          ),
        );
      }
    } else if (decrease) {
      if (currTierRange != avgTierRange) {
        // Dropped to lower tier
        children.addAll([
          const TextSpan(text: "Your bill decreased because your consumption "),
          const TextSpan(text: "dropped from "),
          v(avgTierRange),
          const TextSpan(text: " ("),
          v(avgRateStr),
          const TextSpan(text: ") "),
          const TextSpan(text: "to "),
          v(currTierRange),
          const TextSpan(text: " ("),
          v(currRateStr),
          const TextSpan(text: "). "),
          const TextSpan(text: "This placed you in a cheaper rate tier."),
        ]);
      } else {
        // Stayed in same tier, just used less
        children.addAll([
          const TextSpan(
            text:
                "Your bill decreased because your consumption lowered within the ",
          ),
          v(currTierRange),
          const TextSpan(text: " tier ("),
          v(currRateStr),
          const TextSpan(text: "). "),
          const TextSpan(
            text: "The rate stayed the same but your usage went down.",
          ),
        ]);
      }

      final bool lowResidential =
          readableAcctClass == "Residential" &&
          (consumption - avgConsumption) >= -5;
      final bool lowCommercial =
          readableAcctClass == "Commercial" &&
          (consumption - avgConsumption) >= -15;
      if (lowResidential || lowCommercial) {
        children.add(
          const TextSpan(
            text:
                " Such a low level of usage suggests effective water conservation or fewer occupants at home.",
          ),
        );
      } else {
        children.add(
          const TextSpan(
            text:
                " The decrease is unusually low compared to the average — check if this is due to conservation efforts, fewer occupants, or possible meter reading issues.",
          ),
        );
      }

      print(consumption - avgConsumption);

      // Seasonal notes
      if (seasonFromMonth == "Rainy") {
        children.add(
          const TextSpan(
            text:
                " This also aligns with the Rainy season, when water usage typically decreases.",
          ),
        );
      } else if (seasonFromMonth == "Summer") {
        children.add(
          const TextSpan(
            text:
                " Additionally, a decrease during Summer is less common — check if conservation efforts or other changes reduced your usage.",
          ),
        );
      }

      if (fl.abs() < 5) {
        children.add(
          const TextSpan(
            text: " The change is small and may reflect normal variation.",
          ),
        );
      }
    } else {
      // Stable case
      children.addAll([
        const TextSpan(
          text:
              "Your bill remained stable because your consumption stayed in the ",
        ),
        v(currTierRange),
        const TextSpan(text: " tier ("),
        v(currRateStr),
        const TextSpan(text: ")."),
      ]);

      if (seasonFromMonth == "Summer") {
        children.add(
          const TextSpan(
            text:
                " Even during Summer, usage remained steady — a good sign for conservation.",
          ),
        );
      } else if (seasonFromMonth == "Rainy") {
        children.add(
          const TextSpan(
            text:
                " During Rainy season, steady consumption is common as usage generally declines.",
          ),
        );
      }
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: children),
      textAlign: TextAlign.justify,
    );
  }

  void _showFluctuationReport(
    BuildContext context,
    String month,
    String fluctuation,
  ) async {
    final year = _selectedYear;

    // Flatten and tag all entries with their respective year
    final List<Map<String, dynamic>> allData = [];
    _yearlyData.forEach((y, entries) {
      for (var entry in entries) {
        allData.add({...entry, 'year': y});
      }
    });

    // Month ordering reference
    const List<String> monthOrder = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    // Sort by year then month
    allData.sort((a, b) {
      int yearComparison = int.parse(a['year']).compareTo(int.parse(b['year']));
      if (yearComparison != 0) return yearComparison;
      return monthOrder
          .indexOf(a['month'])
          .compareTo(monthOrder.indexOf(b['month']));
    });

    // Filter entries that contain valid amount
    final filteredData = allData.where((e) => e['amount'] != null).toList();

    // Find the index of the selected month in selected year
    int warningIndex = filteredData.indexWhere(
      (e) => e['month'] == month && e['year'] == year,
    );
    if (warningIndex == -1) warningIndex = filteredData.length - 1;

    // Slice the last 5 real data points ending at warningIndex
    final int startIndex = (warningIndex - 4).clamp(0, warningIndex);
    final recentChartData = filteredData.sublist(startIndex, warningIndex + 1);

    // Prepare consumptions for chart
    final consumptions = recentChartData
        .map((e) => (e['consumption'] as num).toDouble())
        .toList(growable: false);

    // Min/max values for chart
    double minValue = consumptions.reduce((a, b) => a < b ? a : b);
    double maxValue = consumptions.reduce((a, b) => a > b ? a : b);

    // Round to nearest 5
    double minY = (minValue / 5).floor() * 5;
    double maxY = (maxValue / 5).ceil() * 5;

    // Ensure some spacing if min == max
    if (minY == maxY) {
      minY = (minY - 5).clamp(0, double.infinity);
      maxY += 5;
    }

    // Fixed 5-step intervals
    double yStep = 5;

    // Generate left Y-axis labels
    List<double> leftTitleValues = [];
    for (double val = minY; val <= maxY; val += yStep) {
      leftTitleValues.add(val);
    }

    // Chart width based on points
    final chartWidth = 240.w;

    // Capture parent context before awaiting
    final parentContext = context;

    showDialog(
      context: parentContext,
      builder: (context) {
        final int from = int.tryParse(_avgConsFromController.text) ?? 0;
        final int to = int.tryParse(_avgConsToController.text) ?? 0;
        final double avg = (from + to) / 2.0;
        final year = _selectedYear;
        final billEntry = (_yearlyData[year] ?? []).firstWhere(
          (e) => e['month'] == month,
          orElse: () => {},
        );
        final double currConsumption =
            billEntry.isNotEmpty
                ? (billEntry['consumption'] as num).toDouble()
                : 0.0;

        // Y-axis min/max based on avg and currConsumption
        double minY = [avg, currConsumption].reduce(min);
        double maxY = [avg, currConsumption].reduce(max);

        // Add some padding
        minY = (minY / 5).floor() * 5;
        maxY = (maxY / 5).ceil() * 5;
        if (minY == maxY) {
          minY = (minY - 5).clamp(0, double.infinity);
          maxY += 5;
        }
        double yStep = ((maxY - minY) / 4).ceilToDouble();
        if (yStep < 1) yStep = 1;

        // Chart points: [avg, avg, currConsumption]
        final List<double> chartPoints = [avg, avg, currConsumption];

        final TooltipBehavior _chartTooltip = TooltipBehavior(
          enable: true,
          format: 'point.x : point.y m³',
          header: '',
          textStyle: TextStyle(fontSize: 13.sp, color: Colors.white),
          tooltipPosition: TooltipPosition.pointer,
          color: Colors.blueGrey.shade700,
        );

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(18.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'High Usage Report',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close, size: 22.sp),
                    ),
                  ],
                ),

                /// Chart
                SizedBox(
                  width: chartWidth,
                  height: 200.h,
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    tooltipBehavior: _chartTooltip, // <-- Add this line
                    primaryXAxis: CategoryAxis(
                      majorGridLines: const MajorGridLines(width: 0),
                      labelStyle: TextStyle(fontSize: 13.sp),
                      interval: 1,
                      edgeLabelPlacement: EdgeLabelPlacement.shift,
                      title: AxisTitle(text: ''),
                    ),
                    primaryYAxis: NumericAxis(
                      minimum: minY,
                      maximum: maxY,
                      interval: yStep,
                      labelStyle: TextStyle(fontSize: 13.sp),
                      axisLine: const AxisLine(width: 0),
                      majorTickLines: const MajorTickLines(size: 0),
                    ),
                    series: <CartesianSeries>[
                      LineSeries<double, String>(
                        dataSource: [
                          avg.toDouble(), // From value
                          avg.toDouble(), // To value
                          currConsumption, // Selected month
                        ],
                        xValueMapper: (value, index) {
                          if (index == 0) return "From";
                          if (index == 1) return "To";
                          return "$month";
                        },
                        yValueMapper: (value, _) => value,
                        color: const Color(0xFF2D9FD0),
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: true),
                        enableTooltip: true, // <-- Add this line
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8.h),

                /// Message
                Text(
                  'Unusual increase detected in $month $year',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                Text(
                  'We recommend a job order to check for potential plumbing issues.',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 18.h),

                /// Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(parentContext).pop();
                      // Get predicted category before showing modal
                      String? predictedCategory =
                          await _predictJobOrderCategory(
                            accountNo: "",
                            accountName: "",
                            category: "",
                            note: "",
                            year: year,
                            month: month,
                          );

                      _showJobOrderModal(
                        parentContext,
                        year,
                        month,
                        prefillCategory: predictedCategory,
                        categoryReadOnly: predictedCategory != null,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D9FD0),
                      minimumSize: Size.fromHeight(44.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'Request Job Order',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 15.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _updateWaterBill({
    required int billId,
    required int consumption,
  }) async {
    // Recompute price and amount based on account class
    final selectedAccountDetails = _accounts.firstWhere(
      (acc) => acc['account_number']?.toString() == _selectedAccount,
      orElse: () => {},
    );
    final String accountClass =
        selectedAccountDetails['account_class'] ?? 'Residential';

    double tierPrice(int c) {
      if (accountClass == 'Residential') {
        if (c <= 10) return 33.40;
        if (c <= 20) return 34.70;
        if (c <= 30) return 36.00;
        if (c <= 40) return 37.20;
        if (c <= 50) return 41.00;
        return 43.60;
      } else {
        if (c <= 15) return 58.80;
        if (c <= 30) return 60.50;
        if (c <= 500) return 63.90;
        if (c <= 1000) return 63.90;
        return 74.00;
      }
    }

    double computeAmount(int c) {
      // Same tier accumulation logic as add
      double subTotal = 0.0;
      int remaining = c;
      List<Map<String, dynamic>> tiers;
      if (accountClass == 'Residential') {
        tiers = [
          {"max": 10, "rate": 33.4},
          {"max": 20, "rate": 34.7},
          {"max": 30, "rate": 36.0},
          {"max": 40, "rate": 37.2},
          {"max": 50, "rate": 41.0},
          {"max": 9999, "rate": 43.6},
        ];
      } else {
        tiers = [
          {"max": 15, "rate": 58.8},
          {"max": 30, "rate": 60.5},
          {"max": 500, "rate": 63.9},
          {"max": 1000, "rate": 63.9},
          {"max": 99999, "rate": 74.0},
        ];
      }
      int prev = 0;
      for (final t in tiers) {
        int span = t['max'] - prev;
        int units = remaining > span ? span : remaining;
        if (units > 0) {
          subTotal += units * (t['rate'] as double);
          remaining -= units;
        }
        prev = t['max'];
        if (remaining <= 0) break;
      }
      double extra = 0.0;
      if (accountClass == 'Residential' && c <= 35) {
        extra = c * 4.0;
      }
      return subTotal + extra;
    }

    final double price = tierPrice(consumption);
    final double amount = computeAmount(consumption);

    try {
      final resp = await http.put(
        Uri.parse(
          'https://aquafixsansimon.com/api/update_bill.php?bill_id=$billId',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'consumption': consumption,
          'price': price,
          'amount': amount,
        }),
      );
      if (resp.statusCode == 200) {
        await _fetchWaterBills();
        return true;
      }
    } catch (e) {
      debugPrint('Update bill error: $e');
    }
    return false;
  }

  void _showEditBillModal(Map<String, dynamic> bill, String year) {
    final TextEditingController consumptionController = TextEditingController(
      text: bill['consumption']?.toString() ?? '',
    );
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20.w,
            right: 20.w,
            top: 16.h,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Edit Bill (${bill['month']} $year)',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: consumptionController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Consumption (m³)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon:
                          saving
                              ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        saving ? 'Saving...' : 'Save Changes',
                        style: TextStyle(fontSize: 15.sp, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D9FD0),
                        minimumSize: Size.fromHeight(44.h),
                      ),
                      onPressed:
                          saving
                              ? null
                              : () async {
                                final c = int.tryParse(
                                  consumptionController.text,
                                );
                                if (c == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invalid consumption'),
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => saving = true);
                                final ok = await _updateWaterBill(
                                  billId: bill['bill_id'],
                                  consumption: c,
                                );
                                setSheetState(() => saving = false);
                                if (ok) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Bill updated'),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Update failed'),
                                    ),
                                  );
                                }
                              },
                    ),
                  ),
                  SizedBox(height: 10.h),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showBillActionsSheet(Map<String, dynamic> bill, String year) {
    // --- Compute if this bill should show "Request Job Order" ---
    final int from = int.tryParse(_avgConsFromController.text) ?? 0;
    final int to = int.tryParse(_avgConsToController.text) ?? 0;
    final double avg = (from + to) / 2.0;
    final int consumption = bill['consumption'] ?? 0;
    final bool isStable = consumption >= from && consumption <= to;
    final double fluctuation = avg == 0 ? 0 : ((consumption - avg) / avg) * 100;
    final bool isIncrease = fluctuation > 0;
    // Thresholds depending on average consumption
    double diffThreshold;
    double fluctThreshold;
    if (avg <= 15) {
      diffThreshold = 5;
      fluctThreshold = 30;
    } else if (avg <= 30) {
      diffThreshold = 8;
      fluctThreshold = 30;
    } else {
      diffThreshold = 12;
      fluctThreshold = 25;
    }
    final double diff = (consumption - avg).abs();

    // Check if this is the latest month in the selected year
    final yearEntries = (_yearlyData[year] ?? []);
    String latestMonthName = '';
    if (yearEntries.isNotEmpty) {
      final indices =
          yearEntries
              .map((ent) => _months.indexOf((ent['month'] ?? '').toString()))
              .where((i) => i >= 0)
              .toList();
      if (indices.isNotEmpty) {
        final maxIdx = indices.reduce((a, b) => a > b ? a : b);
        latestMonthName = _months[maxIdx];
      }
    }
    final bool isLatest =
        latestMonthName.isNotEmpty && bill['month'] == latestMonthName;
    final bool isCurrentYear = year == DateTime.now().year.toString();

    final bool showWarning =
        isLatest &&
        isCurrentYear &&
        isIncrease &&
        fluctuation >= fluctThreshold &&
        diff >= diffThreshold &&
        !isStable;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final String month = bill['month'] ?? '';
        final billId = bill['bill_id'];

        return DraggableScrollableSheet(
          initialChildSize: showWarning ? 0.42 : 0.36, // <-- updated here
          minChildSize: 0.22,
          maxChildSize: showWarning ? 0.42 : 0.36,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 22.w,
                    vertical: 18.h,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40.w,
                        height: 5.h,
                        margin: EdgeInsets.only(bottom: 16.h),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            color: Color(0xFF2D9FD0),
                            size: 22.sp,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'Bill for $month $year',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D9FD0),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Divider(thickness: 1, color: Colors.grey.shade200),
                      ListTile(
                        leading: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(8.w),
                          child: Icon(
                            Icons.edit,
                            color: Colors.blue,
                            size: 22.sp,
                          ),
                        ),
                        title: Text(
                          'Edit',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showEditBillModal(bill, year);
                        },
                      ),
                      ListTile(
                        leading: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(8.w),
                          child: Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 22.sp,
                          ),
                        ),
                        title: Text(
                          'Delete',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder:
                                (c) => AlertDialog(
                                  title: const Text('Delete Bill'),
                                  content: const Text(
                                    'Delete this bill? This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                          );
                          if (confirm == true) {
                            await _deleteWaterBill(billId);
                          }
                        },
                      ),
                      if (showWarning)
                        ListTile(
                          leading: Container(
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              shape: BoxShape.circle,
                            ),
                            padding: EdgeInsets.all(8.w),
                            child: Icon(
                              Icons.build,
                              color: Colors.teal,
                              size: 22.sp,
                            ),
                          ),
                          title: Text(
                            'Request Job Order',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.sp,
                            ),
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            String? predictedCategory =
                                await _predictJobOrderCategory(
                                  accountNo: '',
                                  accountName: '',
                                  category: '',
                                  note: '',
                                  year: year,
                                  month: month,
                                );
                            _showJobOrderModal(
                              context,
                              year,
                              month,
                              prefillCategory: predictedCategory,
                              categoryReadOnly: predictedCategory != null,
                            );
                          },
                        ),
                      ListTile(
                        leading: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(8.w),
                          child: Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 22.sp,
                          ),
                        ),
                        title: Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddModal() {
    final TextEditingController consumptionController = TextEditingController();
    String? modalSelectedMonth; // local to modal only
    String? modalSelectedYear =
        _selectedYear.isNotEmpty
            ? _selectedYear
            : DateTime.now().year.toString();

    bool _isAdding = false;

    // Year options: 2020-2025
    final List<String> yearOptions =
        List.generate(6, (i) => (2020 + i).toString()).reversed.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20.h,
            left: 20.w,
            right: 20.w,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              // Helper to get account class for selected account
              String getAccountClass() {
                final selectedAccountDetails = _accounts.firstWhere(
                  (acc) =>
                      acc['account_number']?.toString() == _selectedAccount,
                  orElse: () => {},
                );
                final String accountClassRaw =
                    selectedAccountDetails['account_class'] ?? 'Residential';
                return accountClassRaw;
              }

              // Helper to compute price based on consumption and account class
              double computePrice(int consumption, String accountClass) {
                if (accountClass == 'Residential') {
                  if (consumption <= 10) return 33.40;
                  if (consumption <= 20) return 34.70;
                  if (consumption <= 30) return 36.00;
                  if (consumption <= 40) return 37.20;
                  if (consumption <= 50) return 41.00;
                  return 43.6;
                } else {
                  // Commercial
                  if (consumption <= 15) return 58.80;
                  if (consumption <= 30) return 60.50;
                  if (consumption <= 500) return 63.90;
                  if (consumption <= 1000) return 63.90;
                  return 74.0;
                }
              }

              // Compute bill amount based on tier breakdown and extra charge
              double computeBillAmount(int consumption, String accountClass) {
                double subTotal = 0.0;
                int remaining = consumption;

                // Define tiers for each account class
                List<Map<String, dynamic>> tiers;
                if (accountClass == 'Residential') {
                  tiers = [
                    {"max": 10, "rate": 33.4},
                    {"max": 20, "rate": 34.7},
                    {"max": 30, "rate": 36.0},
                    {"max": 40, "rate": 37.2},
                    {"max": 50, "rate": 41.0},
                    {"max": 9999, "rate": 43.6},
                  ];
                } else {
                  tiers = [
                    {"max": 15, "rate": 58.8},
                    {"max": 30, "rate": 60.5},
                    {"max": 500, "rate": 63.9},
                    {"max": 1000, "rate": 63.9},
                    {"max": 99999, "rate": 74.0},
                  ];
                }

                int prevMax = 0;
                for (var tier in tiers) {
                  int tierMax = tier["max"];
                  double rate = tier["rate"];
                  int units =
                      (remaining > (tierMax - prevMax))
                          ? (tierMax - prevMax)
                          : remaining;
                  if (units > 0) {
                    subTotal += units * rate;
                    remaining -= units;
                  }
                  prevMax = tierMax;
                  if (remaining <= 0) break;
                }

                // Add extra charge only for residential and cu.m <= 35
                double extraCharge = 0.0;
                if (accountClass == 'Residential' && consumption <= 35) {
                  extraCharge = consumption * 4.0;
                }
                double totalBill = subTotal + extraCharge;
                return totalBill;
              }

              double? autoPrice;
              double? autoBillAmount;
              String accountClass = getAccountClass();

              void updateAutoPrice() {
                int consumption = int.tryParse(consumptionController.text) ?? 0;
                accountClass = getAccountClass();
                autoPrice = computePrice(consumption, accountClass);
                autoBillAmount = computeBillAmount(consumption, accountClass);
                setModalState(() {});
              }

              // Helper to check if month already exists for selected year (use modal locals)
              bool monthExists(String? year, String? month) {
                if (year == null || month == null) return false;
                return (_yearlyData[year] ?? []).any(
                  (entry) => entry['month'] == month,
                );
              }

              bool isFutureMonth(String? year, String? month) {
                if (year == null || month == null) return false;
                final now = DateTime.now();
                final selectedMonthIndex = _months.indexOf(month) + 1;
                final selectedYearInt = int.tryParse(year) ?? now.year;
                if (selectedYearInt > now.year) return true;
                if (selectedYearInt == now.year &&
                    selectedMonthIndex > now.month)
                  return true;
                return false;
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Water Bill Data',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15.h),
                    Row(
                      children: [
                        // Month Dropdown (modal-local)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: modalSelectedMonth,
                            hint: const Text('Select Month'),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 12.h,
                              ),
                            ),
                            items: [
                              ..._months.map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              ),
                            ],
                            onChanged:
                                (val) => setModalState(() {
                                  modalSelectedMonth = val;
                                }),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        // Year Dropdown (modal-local)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value:
                                (yearOptions.contains(modalSelectedYear)
                                    ? modalSelectedYear
                                    : null),
                            hint: const Text('Year'),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 12.h,
                              ),
                            ),
                            items:
                                yearOptions
                                    .map(
                                      (y) => DropdownMenuItem(
                                        value: y,
                                        child: Text(y),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (val) => setModalState(() {
                                  modalSelectedYear = val;
                                }),
                          ),
                        ),
                      ],
                    ),
                    // Show warning if month already exists
                    // Show warning if month already exists (use modal locals)
                    if (monthExists(modalSelectedYear, modalSelectedMonth))
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Text(
                          "A bill for this month already exists.",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    if (isFutureMonth(modalSelectedYear, modalSelectedMonth))
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Text(
                          "Bill not out yet.",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: consumptionController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly, // Only allow integer digits
                      ],
                      decoration: InputDecoration(
                        labelText: 'Consumption (m³)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                      ),
                      onChanged: (_) => updateAutoPrice(),
                    ),
                    SizedBox(height: 12.h),

                    // Show computed bill amount
                    if (autoBillAmount != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Row(
                          children: [
                            Text(
                              "Computed Bill Amount: ",
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              "₱${autoBillAmount!.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),

                    ElevatedButton(
                      onPressed:
                          _isAdding
                              ? null
                              : () async {
                                setModalState(() {
                                  _isAdding = true;
                                });

                                // Show loading modal
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder:
                                      (_) => Dialog(
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(24.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(height: 8),
                                              Text(
                                                'Adding Water Bill',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              SizedBox(height: 24),
                                              CircularProgressIndicator(
                                                strokeWidth: 5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Color(0xFF2C9CD9)),
                                              ),
                                              SizedBox(height: 24),
                                              Text(
                                                'Please wait...',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                );

                                // Prevent adding if month exists
                                if (monthExists(
                                  modalSelectedYear,
                                  modalSelectedMonth,
                                )) {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop(); // Close loading
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'A bill for this month already exists.',
                                      ),
                                    ),
                                  );
                                  setModalState(() {
                                    _isAdding = false;
                                  });
                                  return;
                                }
                                // Prevent adding if month/year is in the future
                                if (isFutureMonth(
                                  modalSelectedYear,
                                  modalSelectedMonth,
                                )) {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop(); // Close loading
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Bill not out yet.'),
                                    ),
                                  );
                                  setModalState(() {
                                    _isAdding = false;
                                  });
                                  return;
                                }
                                if (modalSelectedMonth == null ||
                                    modalSelectedYear == null ||
                                    consumptionController.text.isEmpty) {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop(); // Close loading
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please fill all fields'),
                                    ),
                                  );
                                  setModalState(() {
                                    _isAdding = false;
                                  });
                                  return;
                                }

                                int consumption =
                                    int.tryParse(consumptionController.text) ??
                                    0;
                                accountClass = getAccountClass();
                                double price =
                                    autoPrice ??
                                    computePrice(consumption, accountClass);
                                double billAmount =
                                    autoBillAmount ??
                                    computeBillAmount(
                                      consumption,
                                      accountClass,
                                    );

                                // Get clw_account_id from selected account object
                                int? clwAccountId;
                                if (_selectedAccount != null) {
                                  final selectedAccountObj = _accounts
                                      .firstWhere(
                                        (acc) =>
                                            acc['account_number']?.toString() ==
                                            _selectedAccount,
                                      );
                                  if (selectedAccountObj != null &&
                                      selectedAccountObj['clw_account_id'] !=
                                          null) {
                                    clwAccountId = int.tryParse(
                                      selectedAccountObj['clw_account_id']
                                          .toString(),
                                    );
                                  }
                                }
                                await _addWaterBill(
                                  year: modalSelectedYear!,
                                  month: modalSelectedMonth!,
                                  consumption: consumption,
                                  price: price,
                                  amount: billAmount,
                                  clwAccountId: clwAccountId,
                                );

                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop(); // Close loading
                                setModalState(() {
                                  _isAdding = false;
                                });

                                Navigator.of(context).pop();
                              },
                      child:
                          _isAdding
                              ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D9FD0),
                        minimumSize: Size(double.infinity, 44.h),
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> submitJobOrder({
    required int customerId,
    required int clwAccountId,
    required String category,
    required String notes,
    required double fluctuation,
    int? billId,
    int isPredictive = 1,
  }) async {
    final url = 'https://aquafixsansimon.com/api/jo_request.php';
    final Map<String, dynamic> data = {
      "customer_id": customerId,
      "clw_account_id": clwAccountId,
      "category": category,
      "notes": notes.trim(),
      "isPredictive": isPredictive,
      "fluctuation": fluctuation,
      "bill_id": billId,
    };
    print('submitJobOrder data: ' + json.encode(data));
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        final resp = json.decode(response.body);
        return resp["success"] == true;
      }
    } catch (e) {
      debugPrint('submitJobOrder error: $e');
    }
    return false;
  }

  DataColumn _buildDataColumn(String label, {double? columnWidth}) =>
      DataColumn(
        label: SizedBox(
          width: columnWidth,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11.sp,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        numeric:
            label != 'Month' &&
            label != 'Consumption' &&
            label != 'Fluctuation',
      );

  // Modified _fetchAccounts: only sets accounts and selected account
  Future<void> _fetchAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) {
      if (mounted) {
        setState(() {
          _accounts = [];
          _selectedAccount = null;
        });
      }
      return;
    }

    final response = await http.get(
      Uri.parse(
        'https://aquafixsansimon.com/api/clw_accounts.php?customer_id=$customerId',
      ),
    );

    if (response.statusCode == 200) {
      final List accountsList = json.decode(response.body);
      if (mounted) {
        setState(() {
          _accounts = accountsList.cast<Map<String, dynamic>>();
          if (_accounts.isNotEmpty) {
            // ✅ Only set if null, so switching back keeps it
            _selectedClwAccountId ??= int.tryParse(
              _accounts.first['clw_account_id'].toString(),
            );
            _selectedAccount ??= _accounts.first['account_number']?.toString();
          } else {
            _selectedClwAccountId = null;
            _selectedAccount = null;
          }
        });
      }
      await prefs.setString('clw_accounts', json.encode(accountsList));
    } else {
      if (mounted) {
        setState(() {
          _accounts = [];
          _selectedAccount = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,

        body: Stack(
          // <-- changed from Column to Stack to support tutorial overlay
          children: [
            Column(
              children: <Widget>[
                Container(
                  height: 64.h + statusBarHeight,
                  width: double.infinity,
                  padding: EdgeInsets.only(top: statusBarHeight),
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/homepage-header.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Water Consumption Analysis',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Add info icon button
                        IconButton(
                          icon: Icon(
                            Icons.help_outline,
                            color: Colors.white,
                            size: 22.sp,
                          ),
                          tooltip: 'Show tutorial',
                          onPressed: () async {
                            // Show tutorial overlay again
                            setState(() {
                              _tutorialVisible = true;
                              _tutorialStep = 0;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                // --- Gradient Reminder Card ---
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 4.h,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      gradient: LinearGradient(
                        colors: [
                          const Color.fromARGB(255, 29, 130, 173),
                          const Color(0xFF2D9FD0),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 22.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            "Reminder: Input your monthly bill to keep your water usage analysis up to date and receive timely insights.",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Labels row for Year and Account (aligned with dropdowns)
                Padding(
                  padding: EdgeInsets.only(
                    left: 4.w,
                    right: 16.w,
                    top: 0.h,
                    bottom: 2.h,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        flex: 29,
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Text(
                            'Year:',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color.fromARGB(255, 124, 124, 124),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Flexible(
                        flex: 71,
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Text(
                            'CLW Account:',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color.fromARGB(255, 124, 124, 124),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: 16.w,
                    bottom: 4.h,
                    right: 16.w,
                  ),
                  child: Row(
                    children: [
                      // ...existing code...
                      Flexible(
                        flex: 30,
                        child: Container(
                          key: _yearKey, // <-- attach key for tutorial
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.r),
                            color: Colors.grey.shade200,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              isDense: true,
                              value:
                                  _yearlyData.isEmpty
                                      ? ''
                                      : (_yearlyData.keys.contains(
                                            _selectedYear,
                                          )
                                          ? _selectedYear
                                          : _yearlyData.keys.last),
                              iconSize: 22.sp,
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.black87,
                              ),
                              items:
                                  _yearlyData.keys.isNotEmpty
                                      ? _yearlyData.keys
                                          .map(
                                            (y) => DropdownMenuItem(
                                              value: y,
                                              child: Text(
                                                y,
                                                style: TextStyle(
                                                  fontSize: 16.sp,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList()
                                      : [
                                        DropdownMenuItem(
                                          value: '',
                                          child: Text(
                                            'N/A',
                                            style: TextStyle(fontSize: 16.sp),
                                          ),
                                        ),
                                      ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedYear = val ?? '';
                                });
                                print("Year changed by user:");
                                print("Selected year: $_selectedYear");
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Flexible(
                        flex: 70,
                        child: Container(
                          key: _accountKey,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.r),
                            color: Colors.grey.shade200,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              isDense: true,
                              value: _selectedAccount ?? 'No Account',
                              iconSize: 22.sp,
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.black87,
                              ),
                              selectedItemBuilder: (context) {
                                // Show selected value with ellipsis if too long
                                return _accounts.isNotEmpty
                                    ? _accounts.map((acc) {
                                      final display =
                                          (acc['label'] ?? '') +
                                          " : " +
                                          (acc['account_number'] ?? '')
                                              .toString();
                                      return Container(
                                        constraints: BoxConstraints(
                                          maxWidth: 160.w,
                                        ),
                                        child: Text(
                                          display,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(fontSize: 16.sp),
                                        ),
                                      );
                                    }).toList()
                                    : [
                                      Container(
                                        constraints: BoxConstraints(
                                          maxWidth: 160.w,
                                        ),
                                        child: Text(
                                          'No Account',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(fontSize: 16.sp),
                                        ),
                                      ),
                                    ];
                              },
                              items: [
                                ...(_accounts.isNotEmpty
                                    ? _accounts
                                        .map(
                                          (acc) => DropdownMenuItem(
                                            value:
                                                acc['account_number']
                                                    ?.toString(),
                                            // Show full value, no ellipsis, no width constraint
                                            child: Text(
                                              (acc['label'] ?? '') +
                                                  " : " +
                                                  (acc['account_number'] ?? '')
                                                      .toString(),
                                              style: TextStyle(fontSize: 16.sp),
                                            ),
                                            onTap: () {
                                              _selectedClwAccountId =
                                                  int.tryParse(
                                                    acc['clw_account_id']
                                                        .toString(),
                                                  );
                                            },
                                          ),
                                        )
                                        .toList()
                                    : [
                                      DropdownMenuItem(
                                        value: 'No Account',
                                        child: Text(
                                          'No Account',
                                          style: TextStyle(fontSize: 16.sp),
                                        ),
                                      ),
                                    ]),
                                // Add Account option
                                DropdownMenuItem(
                                  value: '__add_account__',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.add,
                                        color: Colors.blue,
                                        size: 18.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        'Add Account...',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (newAccount) async {
                                if (newAccount == '__add_account__') {
                                  final result = await Navigator.of(
                                    context,
                                  ).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => const AddAccountPage(),
                                    ),
                                  );
                                  await _fetchAccounts();
                                  await _fetchWaterBills();
                                  return;
                                }
                                if (mounted) {
                                  setState(() {
                                    _selectedAccount = newAccount;
                                    _yearlyData.clear();
                                    _selectedYear = '';
                                  });
                                }
                                await _fetchWaterBills();

                                if (_yearlyData.isNotEmpty) {
                                  final years =
                                      _yearlyData.keys
                                          .map((y) => int.tryParse(y) ?? 0)
                                          .toList();
                                  years.sort();
                                  setState(() {
                                    _selectedYear = years.last.toString();
                                  });
                                } else {
                                  setState(() {
                                    _selectedYear = '';
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // --- Add Average Consumption Range fields ---
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Month Column ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 4.w, bottom: 2.h),
                            child: Text(
                              'Month:',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color.fromARGB(255, 124, 124, 124),
                              ),
                            ),
                          ),
                          Container(
                            key: _monthKey,
                            width: 105.w,
                            height: 44.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              color: Colors.grey.shade200,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: Builder(
                                builder: (context) {
                                  // Collect, normalize and dedupe months (preserve order)
                                  final rawMonthsIter =
                                      (_yearlyData[_selectedYear] ?? [])
                                          .map(
                                            (e) =>
                                                (e['month'] ?? '')
                                                    .toString()
                                                    .trim(),
                                          )
                                          .where((s) => s.isNotEmpty);

                                  // Remove any accidental "All" values coming from data
                                  final List<String> rawMonths =
                                      rawMonthsIter
                                          .where(
                                            (m) => m.toLowerCase() != 'all',
                                          )
                                          .toList();

                                  // Sort by your _months order
                                  rawMonths.sort(
                                    (a, b) => _months
                                        .indexOf(a)
                                        .compareTo(_months.indexOf(b)),
                                  );

                                  // Build monthOptions with a single "All" at front, ensure uniqueness while preserving order
                                  final List<String> monthOptions = [
                                    'All',
                                    ...rawMonths,
                                  ];
                                  final seen = <String>{};
                                  final List<String> uniqueOptions =
                                      monthOptions
                                          .where((m) => seen.add(m))
                                          .toList();

                                  // Ensure current selected page-filter value is valid (avoid assertion)
                                  String? effectiveValue;
                                  if (_modalSelectedMonth != null &&
                                      uniqueOptions.contains(
                                        _modalSelectedMonth,
                                      )) {
                                    effectiveValue = _modalSelectedMonth;
                                  } else {
                                    effectiveValue =
                                        uniqueOptions.isNotEmpty ? 'All' : null;
                                  }

                                  return DropdownButton<String>(
                                    isExpanded: true,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                      vertical: 10.h,
                                    ),
                                    // Only assign value when it's present in items
                                    value:
                                        (_selectedYear.isNotEmpty &&
                                                uniqueOptions.isNotEmpty)
                                            ? effectiveValue
                                            : null,
                                    hint: const Text('N/A'),
                                    items:
                                        uniqueOptions
                                            .map(
                                              (m) => DropdownMenuItem(
                                                value: m,
                                                child: Text(m),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _modalSelectedMonth = val;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 12.w),
                      // --- Average Consumption Range Column ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 4.w, bottom: 2.h),
                              child: Text(
                                'Average Consumption Range (m³)',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color.fromARGB(
                                    255,
                                    124,
                                    124,
                                    124,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              key: _avgRangeKey,
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 44.h,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8.r),
                                      color: Colors.grey.shade200,
                                    ),
                                    child: TextField(
                                      controller: _avgConsFromController,
                                      decoration: InputDecoration(
                                        hintText: 'From (ex: 10)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16.w,
                                          vertical: 12.h,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade200,
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: TextStyle(fontSize: 14.sp),
                                      onChanged: (_) {
                                        setState(() {});
                                        _saveConsumptionRange();
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Container(
                                    height: 44.h,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8.r),
                                      color: Colors.grey.shade200,
                                    ),
                                    child: TextField(
                                      controller: _avgConsToController,
                                      decoration: InputDecoration(
                                        hintText: 'To (ex: 15)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16.w,
                                          vertical: 12.h,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade200,
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: TextStyle(fontSize: 14.sp),
                                      onChanged: (_) {
                                        setState(() {});
                                        _saveConsumptionRange();
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 1.h, 16.w, 80.h),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Container(
                        constraints: BoxConstraints(maxHeight: 415.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: Colors.grey.shade400,
                            width: 0.5.w,
                          ),
                          color: Colors.white,
                        ),
                        child:
                            _isFetchingBills
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        color: Color(0xFF2D9FD0),
                                        strokeWidth: 3,
                                      ),
                                      SizedBox(height: 12.h),
                                      Text(
                                        "Fetching data...",
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : (_avgConsFromController.text.isEmpty ||
                                    _avgConsToController.text.isEmpty)
                                ? Center(
                                  child: Text(
                                    _avgConsFromController.text.isEmpty &&
                                            _avgConsToController.text.isEmpty
                                        ? "Please fill in both 'From' and 'To' fields."
                                        : _avgConsFromController.text.isEmpty
                                        ? "Please fill in the 'From' field."
                                        : "Please fill in the 'To' field.",
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.red,
                                    ),
                                  ),
                                )
                                : (int.tryParse(_avgConsFromController.text) ==
                                        null ||
                                    int.tryParse(_avgConsToController.text) ==
                                        null)
                                ? Center(
                                  child: Text(
                                    "Please enter valid numbers in both fields.",
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.red,
                                    ),
                                  ),
                                )
                                : (int.parse(_avgConsFromController.text) >=
                                    int.parse(_avgConsToController.text))
                                ? Center(
                                  child: Text(
                                    "'From' value must be less than 'To' value.",
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.red,
                                    ),
                                  ),
                                )
                                : (_selectedAccount == null ||
                                    _selectedAccount == 'No Account' ||
                                    _accounts.isEmpty)
                                ? Center(
                                  child: Text(
                                    "Please select an account. If you don't have an account, please add one.",
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.red,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                                : _yearlyData.isEmpty
                                ? Center(
                                  child: Text(
                                    "No water bills found for this account.",
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                                : (_selectedYear.isEmpty ||
                                    _selectedYear == 'N/A' ||
                                    !_yearlyData.containsKey(_selectedYear))
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        color: Color(0xFF2D9FD0),
                                        strokeWidth: 3,
                                      ),
                                      SizedBox(height: 12.h),
                                      Text(
                                        "Fetching data...",
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : InteractiveViewer(
                                  minScale: 1.0,
                                  maxScale: 2.5,
                                  panEnabled: true,
                                  scaleEnabled: true,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Column(
                                      children: [
                                        // Fixed Header using _buildDataColumn
                                        Container(
                                          color: const Color(0xFF2D9FD0),
                                          height: 36.h,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              _buildDataColumn(
                                                'Month',
                                                columnWidth: 41.w,
                                              ).label,
                                              _buildDataColumn(
                                                'Cons.',
                                                columnWidth: 42.w,
                                              ).label,
                                              _buildDataColumn(
                                                'Price',
                                                columnWidth: 53.w,
                                              ).label,
                                              _buildDataColumn(
                                                'Bill Amount',
                                                columnWidth: 83.w,
                                              ).label,
                                              _buildDataColumn(
                                                'Fluctuation',
                                                columnWidth: 83.w,
                                              ).label,
                                              _buildDataColumn(
                                                '',
                                                columnWidth: 36.w,
                                              ).label,
                                            ],
                                          ),
                                        ),

                                        // Scrollable DataRow body
                                        Expanded(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.vertical,
                                            child: Column(
                                              children: [
                                                // --- Filter rows by selected month if set ---
                                                ...(() {
                                                  // Get filtered rows
                                                  final filteredRows =
                                                      (_yearlyData[_selectedYear] ??
                                                              [])
                                                          .where(
                                                            (row) =>
                                                                _modalSelectedMonth ==
                                                                    null ||
                                                                _modalSelectedMonth ==
                                                                    'All' ||
                                                                row['month'] ==
                                                                    _modalSelectedMonth,
                                                          )
                                                          .toList(); // Convert to List for sort
                                                  // Sort by month order
                                                  filteredRows.sort(
                                                    (a, b) => _months
                                                        .indexOf(a['month'])
                                                        .compareTo(
                                                          _months.indexOf(
                                                            b['month'],
                                                          ),
                                                        ),
                                                  );
                                                  return filteredRows;
                                                }()).map((e) {
                                                  final int from = int.parse(
                                                    _avgConsFromController.text,
                                                  );
                                                  final int to = int.parse(
                                                    _avgConsToController.text,
                                                  );
                                                  final double avg =
                                                      (from + to) / 2.0;
                                                  final int consumption =
                                                      e['consumption'] ?? 0;
                                                  final bool isStable =
                                                      consumption >= from &&
                                                      consumption <= to;
                                                  final double fluctuation =
                                                      avg == 0
                                                          ? 0
                                                          : ((consumption -
                                                                      avg) /
                                                                  avg) *
                                                              100;
                                                  final bool isIncrease =
                                                      fluctuation > 0;
                                                  final bool decrease =
                                                      fluctuation < 0;
                                                  // Thresholds depending on average consumption
                                                  double diffThreshold;
                                                  double fluctThreshold;

                                                  if (avg <= 15) {
                                                    diffThreshold = 5;
                                                    fluctThreshold = 30;
                                                  } else if (avg <= 30) {
                                                    diffThreshold = 8;
                                                    fluctThreshold = 30;
                                                  } else {
                                                    diffThreshold = 12;
                                                    fluctThreshold = 25;
                                                  }

                                                  // Absolute difference from avg
                                                  final double diff =
                                                      (consumption - avg).abs();

                                                  // Check if this is the latest month in the selected year
                                                  final yearEntries =
                                                      (_yearlyData[_selectedYear] ??
                                                          []);
                                                  String latestMonthName = '';
                                                  if (yearEntries.isNotEmpty) {
                                                    final indices =
                                                        yearEntries
                                                            .map(
                                                              (
                                                                ent,
                                                              ) => _months.indexOf(
                                                                (ent['month'] ??
                                                                        '')
                                                                    .toString(),
                                                              ),
                                                            )
                                                            .where(
                                                              (i) => i >= 0,
                                                            )
                                                            .toList();
                                                    if (indices.isNotEmpty) {
                                                      final maxIdx = indices
                                                          .reduce(
                                                            (a, b) =>
                                                                a > b ? a : b,
                                                          );
                                                      latestMonthName =
                                                          _months[maxIdx];
                                                    }
                                                  }
                                                  final bool isLatest =
                                                      latestMonthName
                                                          .isNotEmpty &&
                                                      e['month'] ==
                                                          latestMonthName;

                                                  final bool isCurrentYear =
                                                      _selectedYear ==
                                                      DateTime.now().year
                                                          .toString();

                                                  // Warning logic
                                                  final bool showWarning =
                                                      isLatest &&
                                                      isCurrentYear &&
                                                      isIncrease &&
                                                      fluctuation >=
                                                          fluctThreshold &&
                                                      diff >= diffThreshold &&
                                                      !isStable;

                                                  Color fluctuationColor;
                                                  String fluctuationText;
                                                  if (isStable) {
                                                    fluctuationColor =
                                                        Colors.green;
                                                    fluctuationText = 'Stable';
                                                  } else if (fluctuation == 0) {
                                                    fluctuationColor =
                                                        Colors.grey;
                                                    fluctuationText = '0%';
                                                  } else if (isIncrease) {
                                                    fluctuationColor =
                                                        Colors.red;
                                                    fluctuationText =
                                                        '+' +
                                                        fluctuation
                                                            .toStringAsFixed(
                                                              1,
                                                            ) +
                                                        '%';
                                                  } else {
                                                    fluctuationColor =
                                                        Colors.green;
                                                    fluctuationText =
                                                        fluctuation
                                                            .toStringAsFixed(
                                                              1,
                                                            ) +
                                                        '%';
                                                  }
                                                  final String year =
                                                      _selectedYear;
                                                  final String month =
                                                      e['month'];
                                                  final bool jobOrderSubmitted =
                                                      _jobOrderSubmitted
                                                          .contains(
                                                            '$year|$month',
                                                          );
                                                  return Dismissible(
                                                    key: ValueKey(e['bill_id']),
                                                    direction:
                                                        DismissDirection
                                                            .endToStart,
                                                    background: Container(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 24.w,
                                                          ),
                                                      color: Colors.redAccent,
                                                      child: Icon(
                                                        Icons.delete,
                                                        color: Colors.white,
                                                        size: 18.sp,
                                                      ),
                                                    ),
                                                    confirmDismiss: (
                                                      direction,
                                                    ) async {
                                                      return await showDialog<
                                                        bool
                                                      >(
                                                        context: context,
                                                        builder:
                                                            (
                                                              context,
                                                            ) => AlertDialog(
                                                              title: const Text(
                                                                'Delete Bill',
                                                              ),
                                                              content: const Text(
                                                                'Are you sure you want to delete this bill? This action cannot be undone.',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  child:
                                                                      const Text(
                                                                        'Cancel',
                                                                      ),
                                                                  onPressed:
                                                                      () => Navigator.of(
                                                                        context,
                                                                      ).pop(
                                                                        false,
                                                                      ),
                                                                ),
                                                                TextButton(
                                                                  child: const Text(
                                                                    'Delete',
                                                                    style: TextStyle(
                                                                      color:
                                                                          Colors
                                                                              .red,
                                                                    ),
                                                                  ),
                                                                  onPressed:
                                                                      () => Navigator.of(
                                                                        context,
                                                                      ).pop(
                                                                        true,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                      );
                                                    },
                                                    onDismissed: (
                                                      direction,
                                                    ) async {
                                                      await _deleteWaterBill(
                                                        e['bill_id'],
                                                      );
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                          ),
                                                      child: GestureDetector(
                                                        onLongPress: () {
                                                          final String year =
                                                              _selectedYear;
                                                          _showBillActionsSheet(
                                                            e,
                                                            year,
                                                          );
                                                        },
                                                        onTap: () {
                                                          if (avg == 0) return;
                                                          // --- Check icon logic ---
                                                          final billId =
                                                              e['bill_id'];
                                                          final predictiveJo =
                                                              billId != null
                                                                  ? _predictiveJobOrders[billId]
                                                                  : null;
                                                          final bool
                                                          isHourglassIcon =
                                                              ((predictiveJo !=
                                                                          null &&
                                                                      predictiveJo['job_order_id'] !=
                                                                          null) ||
                                                                  jobOrderSubmitted);
                                                          if (isHourglassIcon) {
                                                            // Show explainConsumptionChange dialog
                                                            showDialog(
                                                              context: context,
                                                              builder: (
                                                                context,
                                                              ) {
                                                                final int from =
                                                                    int.tryParse(
                                                                      _avgConsFromController
                                                                          .text,
                                                                    ) ??
                                                                    0;
                                                                final int to =
                                                                    int.tryParse(
                                                                      _avgConsToController
                                                                          .text,
                                                                    ) ??
                                                                    0;
                                                                final double
                                                                avg =
                                                                    (from +
                                                                        to) /
                                                                    2.0;
                                                                final double
                                                                currConsumption =
                                                                    (e['consumption']
                                                                            as num)
                                                                        .toDouble();
                                                                final selectedAccountDetails = _accounts.firstWhere(
                                                                  (acc) =>
                                                                      acc['account_number']
                                                                          ?.toString() ==
                                                                      _selectedAccount,
                                                                  orElse:
                                                                      () => {},
                                                                );
                                                                final String
                                                                acctClass =
                                                                    selectedAccountDetails['account_class'] ??
                                                                    'Residential';
                                                                final String
                                                                fluctuationStr =
                                                                    fluctuation
                                                                        .toStringAsFixed(
                                                                          1,
                                                                        );
                                                                final int
                                                                monthNum =
                                                                    _months
                                                                        .indexOf(
                                                                          month,
                                                                        ) +
                                                                    1;
                                                                return Dialog(
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          18.r,
                                                                        ),
                                                                  ),
                                                                  child: Padding(
                                                                    padding:
                                                                        EdgeInsets.fromLTRB(
                                                                          22.w,
                                                                          18.h,
                                                                          22.w,
                                                                          22.h,
                                                                        ),
                                                                    child: Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Row(
                                                                          children: [
                                                                            Container(
                                                                              decoration: BoxDecoration(
                                                                                color:
                                                                                    Colors.blue.shade100,
                                                                                shape:
                                                                                    BoxShape.circle,
                                                                              ),
                                                                              padding: EdgeInsets.all(
                                                                                7.w,
                                                                              ),
                                                                              child: Icon(
                                                                                Icons.trending_up_rounded,
                                                                                color:
                                                                                    Colors.blue.shade700,
                                                                                size:
                                                                                    22.sp,
                                                                              ),
                                                                            ),
                                                                            SizedBox(
                                                                              width:
                                                                                  10.w,
                                                                            ),
                                                                            Expanded(
                                                                              child: Text(
                                                                                "Consumption Change",
                                                                                style: TextStyle(
                                                                                  fontWeight:
                                                                                      FontWeight.bold,
                                                                                  fontSize:
                                                                                      16.sp,
                                                                                  color:
                                                                                      Colors.blue.shade700,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            GestureDetector(
                                                                              onTap:
                                                                                  () =>
                                                                                      Navigator.of(
                                                                                        context,
                                                                                      ).pop(),
                                                                              child: Icon(
                                                                                Icons.close,
                                                                                size:
                                                                                    22.sp,
                                                                                color:
                                                                                    Colors.grey[600],
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        SizedBox(
                                                                          height:
                                                                              18.h,
                                                                        ),
                                                                        Container(
                                                                          width:
                                                                              double.infinity,
                                                                          padding: EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                8.w,
                                                                            vertical:
                                                                                10.h,
                                                                          ),
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                Colors.white,
                                                                            borderRadius: BorderRadius.circular(
                                                                              16.r,
                                                                            ),
                                                                            boxShadow: [
                                                                              BoxShadow(
                                                                                color: Colors.black.withOpacity(
                                                                                  0.05,
                                                                                ),
                                                                                blurRadius:
                                                                                    12,
                                                                                offset: const Offset(
                                                                                  0,
                                                                                  4,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          child: SizedBox(
                                                                            height:
                                                                                160.h,
                                                                            child: SfCartesianChart(
                                                                              plotAreaBorderWidth:
                                                                                  0,
                                                                              primaryXAxis: CategoryAxis(
                                                                                majorGridLines: const MajorGridLines(
                                                                                  width:
                                                                                      0,
                                                                                ),
                                                                                labelStyle: TextStyle(
                                                                                  fontSize:
                                                                                      12.sp,
                                                                                ),
                                                                                interval:
                                                                                    1,
                                                                                edgeLabelPlacement:
                                                                                    EdgeLabelPlacement.shift,
                                                                                title: AxisTitle(
                                                                                  text:
                                                                                      '',
                                                                                ),
                                                                              ),
                                                                              primaryYAxis: NumericAxis(
                                                                                minimum:
                                                                                    0,
                                                                                maximum:
                                                                                    (currConsumption >
                                                                                            avg
                                                                                        ? currConsumption
                                                                                        : avg) *
                                                                                    1.3,
                                                                                interval:
                                                                                    5,
                                                                                labelStyle: TextStyle(
                                                                                  fontSize:
                                                                                      11.sp,
                                                                                  color:
                                                                                      Colors.blueGrey.shade500,
                                                                                ),
                                                                                axisLine: const AxisLine(
                                                                                  width:
                                                                                      0,
                                                                                ),
                                                                                majorTickLines: const MajorTickLines(
                                                                                  size:
                                                                                      0,
                                                                                ),
                                                                              ),
                                                                              series: <
                                                                                CartesianSeries
                                                                              >[
                                                                                ColumnSeries<
                                                                                  _BarData,
                                                                                  String
                                                                                >(
                                                                                  dataSource: [
                                                                                    _BarData(
                                                                                      'Average',
                                                                                      avg,
                                                                                      Colors.blueGrey.shade400,
                                                                                    ),
                                                                                    _BarData(
                                                                                      'Current',
                                                                                      currConsumption,
                                                                                      currConsumption >=
                                                                                              avg
                                                                                          ? Colors.red.shade600
                                                                                          : Colors.green.shade600,
                                                                                    ),
                                                                                  ],
                                                                                  xValueMapper:
                                                                                      (
                                                                                        data,
                                                                                        _,
                                                                                      ) =>
                                                                                          data.label,
                                                                                  yValueMapper:
                                                                                      (
                                                                                        data,
                                                                                        _,
                                                                                      ) =>
                                                                                          data.value,
                                                                                  pointColorMapper:
                                                                                      (
                                                                                        data,
                                                                                        _,
                                                                                      ) =>
                                                                                          data.color,
                                                                                  borderRadius: BorderRadius.circular(
                                                                                    10.r,
                                                                                  ),
                                                                                  width:
                                                                                      0.3,
                                                                                  dataLabelSettings: DataLabelSettings(
                                                                                    isVisible:
                                                                                        true,
                                                                                    textStyle: TextStyle(
                                                                                      fontSize:
                                                                                          12.sp,
                                                                                      fontWeight:
                                                                                          FontWeight.w500,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          height:
                                                                              18.h,
                                                                        ),
                                                                        Container(
                                                                          width:
                                                                              double.infinity,
                                                                          padding: EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                16.w,
                                                                            vertical:
                                                                                14.h,
                                                                          ),
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                Colors.blue.shade50,
                                                                            borderRadius: BorderRadius.circular(
                                                                              12.r,
                                                                            ),
                                                                            boxShadow: [
                                                                              BoxShadow(
                                                                                color: Colors.blue.withOpacity(
                                                                                  0.08,
                                                                                ),
                                                                                blurRadius:
                                                                                    8,
                                                                                offset: Offset(
                                                                                  0,
                                                                                  2,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                            border: Border.all(
                                                                              color:
                                                                                  Colors.blue.shade200,
                                                                              width:
                                                                                  1,
                                                                            ),
                                                                          ),
                                                                          child: explainConsumptionChange(
                                                                            fluctuation:
                                                                                fluctuationStr,
                                                                            acctClass:
                                                                                acctClass,
                                                                            consumption:
                                                                                currConsumption,
                                                                            avgConsumption:
                                                                                avg,
                                                                            month:
                                                                                monthNum,
                                                                            style: TextStyle(
                                                                              fontSize:
                                                                                  14.sp,
                                                                              color:
                                                                                  Colors.blueGrey.shade800,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            );
                                                          } else if (showWarning) {
                                                            _showFluctuationReport(
                                                              context,
                                                              month,
                                                              fluctuation
                                                                      .toStringAsFixed(
                                                                        1,
                                                                      ) +
                                                                  '%',
                                                            );
                                                          } else {
                                                            showDialog(
                                                              context: context,
                                                              builder: (
                                                                context,
                                                              ) {
                                                                final int from =
                                                                    int.tryParse(
                                                                      _avgConsFromController
                                                                          .text,
                                                                    ) ??
                                                                    0;
                                                                final int to =
                                                                    int.tryParse(
                                                                      _avgConsToController
                                                                          .text,
                                                                    ) ??
                                                                    0;
                                                                final double
                                                                avg =
                                                                    (from +
                                                                        to) /
                                                                    2.0;
                                                                final double
                                                                currConsumption =
                                                                    (e['consumption']
                                                                            as num)
                                                                        .toDouble();
                                                                final selectedAccountDetails = _accounts.firstWhere(
                                                                  (acc) =>
                                                                      acc['account_number']
                                                                          ?.toString() ==
                                                                      _selectedAccount,
                                                                  orElse:
                                                                      () => {},
                                                                );
                                                                final String
                                                                acctClass =
                                                                    selectedAccountDetails['account_class'] ??
                                                                    'Residential';
                                                                final String
                                                                fluctuationStr =
                                                                    fluctuation
                                                                        .toStringAsFixed(
                                                                          1,
                                                                        );
                                                                final int
                                                                monthNum =
                                                                    _months
                                                                        .indexOf(
                                                                          month,
                                                                        ) +
                                                                    1;
                                                                return Dialog(
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          18.r,
                                                                        ),
                                                                  ),
                                                                  child: Padding(
                                                                    padding:
                                                                        EdgeInsets.fromLTRB(
                                                                          22.w,
                                                                          18.h,
                                                                          22.w,
                                                                          22.h,
                                                                        ),
                                                                    child: Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Row(
                                                                          children: [
                                                                            Container(
                                                                              decoration: BoxDecoration(
                                                                                color:
                                                                                    Colors.blue.shade100,
                                                                                shape:
                                                                                    BoxShape.circle,
                                                                              ),
                                                                              padding: EdgeInsets.all(
                                                                                7.w,
                                                                              ),
                                                                              child: Icon(
                                                                                Icons.trending_up_rounded,
                                                                                color:
                                                                                    Colors.blue.shade700,
                                                                                size:
                                                                                    22.sp,
                                                                              ),
                                                                            ),
                                                                            SizedBox(
                                                                              width:
                                                                                  10.w,
                                                                            ),
                                                                            Expanded(
                                                                              child: Text(
                                                                                "Consumption Change",
                                                                                style: TextStyle(
                                                                                  fontWeight:
                                                                                      FontWeight.bold,
                                                                                  fontSize:
                                                                                      16.sp,
                                                                                  color:
                                                                                      Colors.blue.shade700,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            GestureDetector(
                                                                              onTap:
                                                                                  () =>
                                                                                      Navigator.of(
                                                                                        context,
                                                                                      ).pop(),
                                                                              child: Icon(
                                                                                Icons.close,
                                                                                size:
                                                                                    22.sp,
                                                                                color:
                                                                                    Colors.grey[600],
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        SizedBox(
                                                                          height:
                                                                              18.h,
                                                                        ),
                                                                        Container(
                                                                          width:
                                                                              double.infinity,
                                                                          padding: EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                8.w,
                                                                            vertical:
                                                                                10.h,
                                                                          ),
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                Colors.white,
                                                                            borderRadius: BorderRadius.circular(
                                                                              16.r,
                                                                            ),
                                                                            boxShadow: [
                                                                              BoxShadow(
                                                                                color: Colors.black.withOpacity(
                                                                                  0.05,
                                                                                ),
                                                                                blurRadius:
                                                                                    12,
                                                                                offset: const Offset(
                                                                                  0,
                                                                                  4,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          child: SizedBox(
                                                                            height:
                                                                                160.h,
                                                                            child: SfCartesianChart(
                                                                              plotAreaBorderWidth:
                                                                                  0,
                                                                              primaryXAxis: CategoryAxis(
                                                                                majorGridLines: const MajorGridLines(
                                                                                  width:
                                                                                      0,
                                                                                ),
                                                                                labelStyle: TextStyle(
                                                                                  fontSize:
                                                                                      12.sp,
                                                                                ),
                                                                                interval:
                                                                                    1,
                                                                                edgeLabelPlacement:
                                                                                    EdgeLabelPlacement.shift,
                                                                                title: AxisTitle(
                                                                                  text:
                                                                                      '',
                                                                                ),
                                                                              ),
                                                                              primaryYAxis: NumericAxis(
                                                                                minimum:
                                                                                    0,
                                                                                maximum:
                                                                                    (currConsumption >
                                                                                            avg
                                                                                        ? currConsumption
                                                                                        : avg) *
                                                                                    1.3,
                                                                                interval:
                                                                                    5,
                                                                                labelStyle: TextStyle(
                                                                                  fontSize:
                                                                                      11.sp,
                                                                                  color:
                                                                                      Colors.blueGrey.shade500,
                                                                                ),
                                                                                axisLine: const AxisLine(
                                                                                  width:
                                                                                      0,
                                                                                ),
                                                                                majorTickLines: const MajorTickLines(
                                                                                  size:
                                                                                      0,
                                                                                ),
                                                                              ),
                                                                              series: <
                                                                                CartesianSeries
                                                                              >[
                                                                                ColumnSeries<
                                                                                  _BarData,
                                                                                  String
                                                                                >(
                                                                                  dataSource: [
                                                                                    _BarData(
                                                                                      'Average',
                                                                                      avg,
                                                                                      Colors.blueGrey.shade400,
                                                                                    ),
                                                                                    _BarData(
                                                                                      'Current',
                                                                                      currConsumption,
                                                                                      currConsumption >=
                                                                                              avg
                                                                                          ? Colors.red.shade600
                                                                                          : Colors.green.shade600,
                                                                                    ),
                                                                                  ],
                                                                                  xValueMapper:
                                                                                      (
                                                                                        data,
                                                                                        _,
                                                                                      ) =>
                                                                                          data.label,
                                                                                  yValueMapper:
                                                                                      (
                                                                                        data,
                                                                                        _,
                                                                                      ) =>
                                                                                          data.value,
                                                                                  pointColorMapper:
                                                                                      (
                                                                                        data,
                                                                                        _,
                                                                                      ) =>
                                                                                          data.color,
                                                                                  borderRadius: BorderRadius.circular(
                                                                                    10.r,
                                                                                  ),
                                                                                  width:
                                                                                      0.3,
                                                                                  dataLabelSettings: DataLabelSettings(
                                                                                    isVisible:
                                                                                        true,
                                                                                    textStyle: TextStyle(
                                                                                      fontSize:
                                                                                          12.sp,
                                                                                      fontWeight:
                                                                                          FontWeight.w500,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          height:
                                                                              12.h,
                                                                        ),
                                                                        Container(
                                                                          width:
                                                                              double.infinity,
                                                                          padding: EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                16.w,
                                                                            vertical:
                                                                                14.h,
                                                                          ),
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                Colors.blue.shade50,
                                                                            borderRadius: BorderRadius.circular(
                                                                              12.r,
                                                                            ),
                                                                            boxShadow: [
                                                                              BoxShadow(
                                                                                color: Colors.blue.withOpacity(
                                                                                  0.08,
                                                                                ),
                                                                                blurRadius:
                                                                                    8,
                                                                                offset: Offset(
                                                                                  0,
                                                                                  2,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                            border: Border.all(
                                                                              color:
                                                                                  Colors.blue.shade200,
                                                                              width:
                                                                                  1,
                                                                            ),
                                                                          ),
                                                                          child: explainConsumptionChange(
                                                                            fluctuation:
                                                                                fluctuationStr,
                                                                            acctClass:
                                                                                acctClass,
                                                                            consumption:
                                                                                currConsumption,
                                                                            avgConsumption:
                                                                                avg,
                                                                            month:
                                                                                monthNum,
                                                                            style: TextStyle(
                                                                              fontSize:
                                                                                  14.sp,
                                                                              color:
                                                                                  Colors.blueGrey.shade800,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            );
                                                          }
                                                        },
                                                        child: Row(
                                                          children: [
                                                            SizedBox(
                                                              width: 41.w,
                                                              height: 36.h,
                                                              child: Center(
                                                                child: Text(
                                                                  (e['month'] ??
                                                                          '')
                                                                      .toString()
                                                                      .substring(
                                                                        0,
                                                                        3,
                                                                      ),
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12.sp,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 42.w,
                                                              height: 36.h,
                                                              child: Center(
                                                                child: Text(
                                                                  "$consumption m³",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12.sp,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 53.w,
                                                              height: 36.h,
                                                              child: Center(
                                                                child: Text(
                                                                  "₱${(e['price'] as num).toStringAsFixed(1)}",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12.sp,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 83.w,
                                                              height: 36.h,
                                                              child: Center(
                                                                child: Text(
                                                                  "₱${(e['amount'] as num).toStringAsFixed(2)}",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12.sp,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 83.w,
                                                              height: 36.h,
                                                              child: Center(
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Text(
                                                                      fluctuationText,
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            12.sp,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color:
                                                                            fluctuationColor,
                                                                      ),
                                                                    ),
                                                                    // --- Show job order status icon if job order exists ---
                                                                    Builder(
                                                                      builder: (
                                                                        context,
                                                                      ) {
                                                                        final billId =
                                                                            e['bill_id'];
                                                                        final predictiveJo =
                                                                            billId !=
                                                                                    null
                                                                                ? _predictiveJobOrders[billId]
                                                                                : null;
                                                                        final bool
                                                                        jobOrderSubmitted =
                                                                            _jobOrderSubmitted.contains(
                                                                              '$year|$month',
                                                                            );
                                                                        if (predictiveJo !=
                                                                                null &&
                                                                            predictiveJo['job_order_id'] !=
                                                                                null) {
                                                                          final status =
                                                                              predictiveJo['job_order_status']?.toString()?.toLowerCase() ??
                                                                              '';
                                                                          if (status ==
                                                                              'pending') {
                                                                            return GestureDetector(
                                                                              onTapDown: (
                                                                                details,
                                                                              ) {
                                                                                _showJobOrderStatusTooltip(
                                                                                  context,
                                                                                  status,
                                                                                  details.globalPosition,
                                                                                );
                                                                              },
                                                                              child: AnimatedBuilder(
                                                                                animation:
                                                                                    _hourglassController,
                                                                                builder: (
                                                                                  context,
                                                                                  child,
                                                                                ) {
                                                                                  final double t = _hourglassController.value;
                                                                                  return Transform.rotate(
                                                                                    angle:
                                                                                        t *
                                                                                        2 *
                                                                                        pi,
                                                                                    child: Icon(
                                                                                      Icons.hourglass_top,
                                                                                      color:
                                                                                          Colors.orange,
                                                                                      size:
                                                                                          15.sp,
                                                                                    ),
                                                                                  );
                                                                                },
                                                                              ),
                                                                            );
                                                                          } else if (status ==
                                                                              'accomplished') {
                                                                            return GestureDetector(
                                                                              onTapDown: (
                                                                                details,
                                                                              ) {
                                                                                _showJobOrderStatusTooltip(
                                                                                  context,
                                                                                  status,
                                                                                  details.globalPosition,
                                                                                );
                                                                              },
                                                                              child: Icon(
                                                                                Icons.check_circle,
                                                                                color:
                                                                                    Colors.green,
                                                                                size:
                                                                                    15.sp,
                                                                              ),
                                                                            );
                                                                          } else if (status ==
                                                                              'cancelled') {
                                                                            return GestureDetector(
                                                                              onTapDown: (
                                                                                details,
                                                                              ) {
                                                                                _showJobOrderStatusTooltip(
                                                                                  context,
                                                                                  status,
                                                                                  details.globalPosition,
                                                                                );
                                                                              },
                                                                              child: Icon(
                                                                                Icons.cancel,
                                                                                color:
                                                                                    Colors.red,
                                                                                size:
                                                                                    15.sp,
                                                                              ),
                                                                            );
                                                                          } else {
                                                                            return GestureDetector(
                                                                              onTapDown: (
                                                                                details,
                                                                              ) {
                                                                                _showJobOrderStatusTooltip(
                                                                                  context,
                                                                                  status,
                                                                                  details.globalPosition,
                                                                                );
                                                                              },
                                                                              child: AnimatedBuilder(
                                                                                animation:
                                                                                    _hourglassController,
                                                                                builder: (
                                                                                  context,
                                                                                  child,
                                                                                ) {
                                                                                  final double t = _hourglassController.value;
                                                                                  return Transform.rotate(
                                                                                    angle:
                                                                                        t *
                                                                                        2 *
                                                                                        pi,
                                                                                    child: Icon(
                                                                                      Icons.autorenew,
                                                                                      color:
                                                                                          Colors.blue,
                                                                                      size:
                                                                                          15.sp,
                                                                                    ),
                                                                                  );
                                                                                },
                                                                              ),
                                                                            );
                                                                          }
                                                                        } else if (jobOrderSubmitted) {
                                                                          return GestureDetector(
                                                                            onTapDown: (
                                                                              details,
                                                                            ) {
                                                                              _showJobOrderStatusTooltip(
                                                                                context,
                                                                                'pending',
                                                                                details.globalPosition,
                                                                              );
                                                                            },
                                                                            child: AnimatedBuilder(
                                                                              animation:
                                                                                  _hourglassController,
                                                                              builder: (
                                                                                context,
                                                                                child,
                                                                              ) {
                                                                                final double
                                                                                t = _hourglassController.value;
                                                                                return Transform.rotate(
                                                                                  angle:
                                                                                      t *
                                                                                      2 *
                                                                                      pi,
                                                                                  child: Icon(
                                                                                    Icons.hourglass_top,
                                                                                    color:
                                                                                        Colors.orange,
                                                                                    size:
                                                                                        15.sp,
                                                                                  ),
                                                                                );
                                                                              },
                                                                            ),
                                                                          );
                                                                        } else if (showWarning) {
                                                                          // No job order, show warning icon
                                                                          return Tooltip(
                                                                            message:
                                                                                'No job order sent',
                                                                            child: Icon(
                                                                              Icons.warning_rounded,
                                                                              color:
                                                                                  Colors.red,
                                                                              size:
                                                                                  15.sp,
                                                                            ),
                                                                          );
                                                                        } else {
                                                                          return SizedBox.shrink();
                                                                        }
                                                                      },
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 36.w,
                                                              height: 36.h,
                                                              child: Center(
                                                                child: IconButton(
                                                                  icon: Icon(
                                                                    Icons
                                                                        .delete,
                                                                    color:
                                                                        Colors
                                                                            .red,
                                                                    size: 16.sp,
                                                                  ),
                                                                  tooltip:
                                                                      'Delete bill',
                                                                  padding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                  constraints:
                                                                      BoxConstraints(),
                                                                  onPressed: () async {
                                                                    final confirm = await showDialog<
                                                                      bool
                                                                    >(
                                                                      context:
                                                                          context,
                                                                      builder:
                                                                          (
                                                                            context,
                                                                          ) => AlertDialog(
                                                                            title: const Text(
                                                                              'Delete Bill',
                                                                            ),
                                                                            content: const Text(
                                                                              'Are you sure you want to delete this bill? This action cannot be undone.',
                                                                            ),
                                                                            actions: [
                                                                              TextButton(
                                                                                child: const Text(
                                                                                  'Cancel',
                                                                                ),
                                                                                onPressed:
                                                                                    () => Navigator.of(
                                                                                      context,
                                                                                    ).pop(
                                                                                      false,
                                                                                    ),
                                                                              ),
                                                                              TextButton(
                                                                                child: const Text(
                                                                                  'Delete',
                                                                                  style: TextStyle(
                                                                                    color:
                                                                                        Colors.red,
                                                                                  ),
                                                                                ),
                                                                                onPressed:
                                                                                    () => Navigator.of(
                                                                                      context,
                                                                                    ).pop(
                                                                                      true,
                                                                                    ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                    );
                                                                    if (confirm ==
                                                                        true) {
                                                                      await _deleteWaterBill(
                                                                        e['bill_id'],
                                                                      );
                                                                    }
                                                                  },
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Positioned(
              right: 16,
              bottom: 20,
              child: FloatingActionButton(
                key: _fabKey, // <-- attach key for tutorial
                onPressed: _showAddModal,
                backgroundColor: const Color(0xFF2D9FD0),
                foregroundColor: Colors.white,
                child: Icon(Icons.add, size: 20.sp),
                shape: const CircleBorder(),
              ),
            ),
            if (_tutorialVisible) _buildTutorialOverlay(),
          ],
        ),
      ),
    );
  }
}

class _ProgressModal extends StatelessWidget {
  final Stream<double> progressStream;
  const _ProgressModal({required this.progressStream});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: StreamBuilder<double>(
          stream: progressStream,
          initialData: 0.0,
          builder: (context, snapshot) {
            final percent =
                ((snapshot.data ?? 0.0) * 100).clamp(0, 100).toInt();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8),
                Text(
                  'Submitting Job Order',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 24),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: (snapshot.data ?? 0.0).clamp(0, 1),
                        strokeWidth: 7,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2C9CD9),
                        ),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(
                  percent < 100
                      ? 'Please wait while we process your request...'
                      : 'Done!',
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BarData {
  final String label;
  final double value;
  final Color color;
  _BarData(this.label, this.value, this.color);
}

// Helper widget to show WaterAnalysisPage and open the add modal immediately
class WaterAnalysisPageWithAddModal extends StatefulWidget {
  const WaterAnalysisPageWithAddModal({Key? key}) : super(key: key);

  @override
  State<WaterAnalysisPageWithAddModal> createState() =>
      _WaterAnalysisPageWithAddModalState();
}

class _WaterAnalysisPageWithAddModalState
    extends State<WaterAnalysisPageWithAddModal> {
  bool _modalShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_modalShown) {
        _modalShown = true;
        // Use a Future to ensure context is ready
        Future.delayed(Duration(milliseconds: 100), () {
          final state =
              context.findAncestorStateOfType<_WaterAnalysisPageState>();
          state?._showAddModal();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const WaterAnalysisPage();
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool pointingUp;
  _TrianglePainter({required this.color, this.pointingUp = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (pointingUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
