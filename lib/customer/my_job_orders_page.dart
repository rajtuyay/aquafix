import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_detail_page.dart';
import 'dart:io';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:typed_data'; // <-- Add this import for Uint8List
import 'package:url_launcher/url_launcher.dart';

class MyJobOrdersPage extends StatefulWidget {
  const MyJobOrdersPage({super.key});

  @override
  _MyJobOrdersPageState createState() => _MyJobOrdersPageState();
}

class _MyJobOrdersPageState extends State<MyJobOrdersPage> {
  String selectedFilter = 'All';
  List<dynamic> jobOrders = [];
  List<dynamic> filteredJobOrders = [];
  final Set<int> _ratedJobIds = {};
  String _searchText = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchJobOrders();
  }

  Future<void> _showLoadingModal(
    BuildContext context, {
    String message = "Sending...",
  }) async {
    StreamController<double> _progressController = StreamController<double>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ProgressModal(
          progressStream: _progressController.stream,
          title: "Sending",
          message: message,
        );
      },
    );
    // Simulate progress for UI only
    for (int i = 1; i <= 100; i += 5) {
      await Future.delayed(Duration(milliseconds: 20));
      _progressController.add(i / 100);
    }
    _progressController.close();
  }

  Future<void> _showThankYouModal(BuildContext context, String message) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFFE6F1FA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF2C9CD9), size: 54),
                SizedBox(height: 18),
                Text(
                  "Thank You!",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2C9CD9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      "Close",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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

  Future<void> _fetchJobOrders() async {
    setState(() {
      _loading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) {
      setState(() {
        jobOrders = [];
        filteredJobOrders = [];
        _loading = false;
      });
      return;
    }
    final response = await http.get(
      Uri.parse(
        'https://aquafixsansimon.com/api/job_orders.php?customer_id=$customerId',
      ),
    );
    if (response.statusCode == 200) {
      final List<dynamic> orders = json.decode(response.body);

      // --- ADD: Fetch plumbers and merge plumber contact into job objects ---
      try {
        final plumberResp = await http.get(
          Uri.parse('https://aquafixsansimon.com/api/plumbers.php'),
        );
        if (plumberResp.statusCode == 200) {
          final List<dynamic> plumbers = json.decode(plumberResp.body);
          final Map<String, String> plumberMap = {};
          for (var p in plumbers) {
            final id = p['plumber_id']?.toString() ?? '';
            final phone = (p['contact_no'] ?? '').toString();
            if (id.isNotEmpty) plumberMap[id] = phone;
          }
          for (var job in orders) {
            final pid = job['plumber_id']?.toString() ?? '';
            if (pid.isNotEmpty && plumberMap.containsKey(pid)) {
              job['plumber_contact'] = plumberMap[pid];
            }
            // if job already has contact on job record, keep it as fallback
            job['plumber_contact'] =
                job['plumber_contact'] ?? job['contact_no'];
          }
        } else {
          print('plumbers.php fetch failed: ${plumberResp.statusCode}');
        }
      } catch (e) {
        print('Error fetching plumbers.php: $e');
      }
      // --- END: plumber merge ---

      setState(() {
        jobOrders = orders;
        _applyFilterAndSearch();
        _loading = false;
      });
    } else {
      setState(() {
        jobOrders = [];
        filteredJobOrders = [];
        _loading = false;
      });
    }
  }

  void _applyFilterAndSearch() {
    List<dynamic> filtered = jobOrders;
    if (selectedFilter != 'All') {
      filtered =
          filtered.where((job) {
            // Treat 'Dispatched' as 'Ongoing' for filtering
            final jobStatus = (job['status'] ?? '').toString();
            final normalizedStatus =
                jobStatus == 'Dispatched' ? 'Ongoing' : jobStatus;
            return normalizedStatus.toLowerCase() ==
                selectedFilter.toLowerCase();
          }).toList();
    }
    if (_searchText.trim().isNotEmpty) {
      filtered =
          filtered.where((job) {
            final plumberName =
                ((job['plumber_first_name'] ?? '') +
                        ' ' +
                        (job['plumber_last_name'] ?? ''))
                    .toLowerCase();
            final jobId = (job['jo_number'] ?? '').toString().toLowerCase();
            return plumberName.contains(_searchText.toLowerCase()) ||
                jobId.contains(_searchText.toLowerCase());
          }).toList();
    }
    filteredJobOrders = filtered;
  }

  void _sortJobOrders(String filter) {
    setState(() {
      selectedFilter = filter;
      _applyFilterAndSearch();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchText = value;
      _applyFilterAndSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C9CD9),
        title: Text(
          'My Job Orders',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 22.sp, color: Colors.white),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          children: [
            SizedBox(height: 16.h),
            // Dropdown for filtering
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade500),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: DropdownButton<String>(
                value: selectedFilter,
                isExpanded: true,
                isDense: true,
                icon: Icon(Icons.arrow_drop_down, size: 24.sp),
                items:
                    ['All', 'Pending', 'Ongoing', 'Accomplished', 'Cancelled']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    _sortJobOrders(newValue);
                  }
                },
                underline: SizedBox(),
              ),
            ),
            SizedBox(height: 8.h),
            // Search Bar
            TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by Plumber Name or Job ID',
                hintStyle: TextStyle(fontSize: 15.sp),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey.shade100),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8.h),
              ),
            ),
            SizedBox(height: 16.h),
            // List of Job Orders
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredJobOrders.isEmpty
                      ? Center(
                        child: Text(
                          "No job orders found.",
                          style: TextStyle(fontSize: 15.sp, color: Colors.grey),
                        ),
                      )
                      : ListView(
                        children:
                            filteredJobOrders.map((job) {
                              // Use created_at for both date and time
                              DateTime? createdAt;
                              if (job['created_at'] != null &&
                                  job['created_at'].toString().isNotEmpty &&
                                  job['created_at'].toString().toLowerCase() !=
                                      'null') {
                                try {
                                  createdAt = DateTime.parse(
                                    job['created_at'].toString(),
                                  );
                                } catch (_) {}
                              }
                              String date =
                                  createdAt != null
                                      ? "${_monthName(createdAt.month)} ${createdAt.day}, ${createdAt.year}"
                                      : '';
                              String time =
                                  createdAt != null
                                      ? "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}"
                                      : '';

                              return _buildJobCard(
                                status: job['status'] ?? '',
                                statusColor: _getStatusColor(
                                  job['status'] ?? '',
                                ),
                                date: date,
                                time: time,
                                jobId: (job['jo_number'] ?? '').toString(),
                                jobOrderId: job['job_order_id'],
                                title: job['category'] ?? '',
                                plumber:
                                    ((job['plumber_first_name'] ?? '') +
                                                ' ' +
                                                (job['plumber_last_name'] ??
                                                    ''))
                                            .trim()
                                            .isEmpty
                                        ? 'Unassigned'
                                        : ((job['plumber_first_name'] ?? '') +
                                            ' ' +
                                            (job['plumber_last_name'] ?? '')),
                                address: _formatAddress(job),
                                actionText: _getActionText(job),
                                actionColor: _getActionColor(job),
                                onRate:
                                    _getActionText(job) == 'Rate Us'
                                        ? () => _showRatePlumberModal(
                                          context,
                                          ((job['plumber_first_name'] ?? '') +
                                              ' ' +
                                              (job['plumber_last_name'] ?? '')),
                                          (job['job_order_id'] ?? '')
                                              .toString(),
                                        )
                                        : null,
                                isRated: _ratedJobIds.contains(
                                  job['job_order_id'],
                                ),
                              );
                            }).toList(),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date, dynamic createdAt) {
    // Try to format the date string, fallback to created_at if needed
    String? raw = date?.toString();
    if (raw == null || raw.isEmpty || raw == 'null') {
      raw = createdAt?.toString();
    }
    if (raw == null || raw.isEmpty || raw == 'null') return '';
    try {
      final dt = DateTime.parse(raw);
      return "${_monthName(dt.month)} ${dt.day}, ${dt.year}";
    } catch (_) {
      return raw;
    }
  }

  String _monthName(int month) {
    const months = [
      '',
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
    return months[month];
  }

  String _formatAddress(dynamic job) {
    final label = job['address_label'] ?? '';
    final street = job['street'] ?? '';
    final barangay = job['barangay'] ?? '';
    final municipality = job['municipality'] ?? '';
    final province = job['province'] ?? '';
    return [
      label,
      street,
      barangay,
      municipality,
      province,
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
  }

  String _getActionText(dynamic job) {
    final status = (job['status'] ?? '').toString().toLowerCase();
    final jobId = job['job_order_id'];
    // Accept is_rated as int 1, string '1', or true
    final isRated =
        job['is_rated'] == 1 ||
        job['is_rated'] == '1' ||
        job['is_rated'] == true ||
        _ratedJobIds.contains(jobId);

    // Fix: Dispatched should always be "Message" unless rated
    if (status == 'pending') return 'Cancel';
    if (status == 'dispatched') {
      return 'Message';
    }
    if (status == 'accomplished') {
      if (isRated && status == 'accomplished') return 'View Details';
      return 'Rate Us';
    }
    if (status == 'cancelled') return 'View Details';
    return '';
  }

  Color _getActionColor(dynamic job) {
    final status = (job['status'] ?? '').toString().toLowerCase();
    if (status == 'pending') return Color(0xFFEF5350);
    return Color(0xFF2196F3);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accomplished':
        return Colors.green;
      case 'ongoing':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildJobCard({
    required String status,
    required Color statusColor,
    required String date,
    required String time,
    required String jobId,
    required dynamic jobOrderId,
    required String title,
    required String plumber,
    required String address,
    required String actionText,
    required Color actionColor,
    VoidCallback? onRate,
    bool isRated = false,
  }) {
    // Use jobOrderId directly
    final job = jobOrders.firstWhere(
      (j) => (j['job_order_id'] ?? '') == jobOrderId,
      orElse: () => {},
    );
    final isRatedFlag =
        job['is_rated'] == 1 ||
        job['is_rated'] == '1' ||
        job['is_rated'] == true ||
        _ratedJobIds.contains(jobId);

    final bool isRateUs = actionText == 'Rate Us' && !isRatedFlag;
    final bool isViewDetails = actionText == 'View Details';
    final bool isCancel = actionText == 'Cancel';
    final bool isMessage = actionText == 'Message';
    final String statusLower = (job['status'] ?? '').toString().toLowerCase();
    final bool isDispatched = status.toLowerCase() == 'dispatched';

    // Show only HH:mm (e.g., "13:45:00.000" or "13:45:00" -> "13:45")
    String displayTime = time;
    if (displayTime.contains('.')) {
      displayTime = displayTime.split('.').first;
    }
    if (displayTime.length >= 5) {
      displayTime = displayTime.substring(0, 5);
    } else {
      displayTime = '';
    }
    // Display 'ongoing' if status is 'Dispatched'
    String displayStatus = status == 'Dispatched' ? 'Ongoing' : status;
    Color displayStatusColor =
        status == 'Dispatched' ? _getStatusColor('ongoing') : statusColor;
    return GestureDetector(
      onTap: () {
        // Show details modal on card tap
        if (statusLower == 'accomplished') {
          _showRatingDetailsModal(context, jobId);
        } else {
          _showJobOrderDetailsModal(context, jobId);
        }
      },
      child: Card(
        margin: EdgeInsets.only(bottom: 12.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        elevation: 3,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Stack(
            children: [
              // Main card content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: displayStatusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          displayStatus,
                          style: TextStyle(
                            color: displayStatusColor,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color.fromARGB(255, 98, 98, 98),
                            ),
                          ),
                          Text(
                            ' ' + time,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color.fromARGB(255, 98, 98, 98),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '$jobId $title',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(plumber, style: TextStyle(fontSize: 13.sp)),
                  SizedBox(height: 2.h),
                  Text(
                    address,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8.h),
                  Align(
                    alignment: Alignment.centerRight,
                    child:
                        isRateUs
                            ? IgnorePointer(
                              ignoring: isRatedFlag,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.only(bottom: 0),
                                  minimumSize: Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: isRatedFlag ? null : onRate,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color:
                                          isRatedFlag
                                              ? Colors.grey
                                              : Colors.orange,
                                      size: 16.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      isRatedFlag
                                          ? "Thank you for your feedback"
                                          : "Rate Us",
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color:
                                            isRatedFlag
                                                ? Colors.grey
                                                : Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : isCancel
                            ? TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.only(bottom: 0),
                                minimumSize: Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                if (jobOrderId != null &&
                                    jobOrderId != 0 &&
                                    jobOrderId.toString().isNotEmpty) {
                                  _cancelJobOrder(context, jobOrderId);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invalid job order ID.'),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cancel,
                                    color: Color(0xFFEF5350),
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    "Cancel",
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Color(0xFFEF5350),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : isViewDetails
                            ? TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.only(bottom: 0),
                                minimumSize: Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                if (statusLower == 'accomplished') {
                                  _showRatingDetailsModal(context, jobId);
                                } else {
                                  _showJobOrderDetailsModal(context, jobId);
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Color(0xFF2D9FD0),
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    "View Details",
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Color(0xFF2D9FD0),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : isMessage
                            ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // --- CALL BUTTON (left of Message) ---
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.only(right: 8.w),
                                    minimumSize: Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () async {
                                    final plumberContact =
                                        job['plumber_contact']?.toString() ??
                                        '';
                                    print(
                                      'Plumber contact: $plumberContact',
                                    ); // <-- Added print
                                    if (plumberContact.isNotEmpty) {
                                      final uri = Uri(
                                        scheme: 'tel',
                                        path: plumberContact,
                                      );
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Cannot make a call.',
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Plumber contact not available.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.call,
                                        color: Color(0xFF00897B),
                                        size: 16.sp,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        "Call",
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Color(0xFF00897B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // --- MESSAGE BUTTON ---
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.only(left: 8.w),
                                    minimumSize: Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () async {
                                    // Start or open chat with plumber
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    final customerId =
                                        prefs.getString('customer_id') ?? '';
                                    final plumberId =
                                        job['plumber_id']?.toString() ?? '';
                                    if (customerId.isEmpty ||
                                        plumberId.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Missing customer or plumber ID.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    // 1. Check if chat exists
                                    final chatRes = await http.get(
                                      Uri.parse(
                                        'https://aquafixsansimon.com/api/chats_util.php?customer_id=$customerId&plumber_id=$plumberId',
                                      ),
                                    );
                                    int? chatId;
                                    if (chatRes.statusCode == 200) {
                                      final chatData = json.decode(
                                        chatRes.body,
                                      );
                                      if (chatData['chat_id'] != null) {
                                        chatId = int.tryParse(
                                          chatData['chat_id'].toString(),
                                        );
                                      }
                                    }
                                    // 2. If not, create chat
                                    if (chatId == null) {
                                      final createRes = await http.post(
                                        Uri.parse(
                                          'https://aquafixsansimon.com/api/chats_util.php',
                                        ),
                                        headers: {
                                          'Content-Type': 'application/json',
                                        },
                                        body: json.encode({
                                          'customer_id': customerId,
                                          'plumber_id': plumberId,
                                        }),
                                      );
                                      if (createRes.statusCode == 200) {
                                        final chatData = json.decode(
                                          createRes.body,
                                        );
                                        chatId = int.tryParse(
                                          chatData['chat_id'].toString(),
                                        );
                                      }
                                    }
                                    if (chatId == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Failed to start chat.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final plumberName =
                                        ((job['plumber_first_name'] ?? '') +
                                                    ' ' +
                                                    (job['plumber_last_name'] ??
                                                        ''))
                                                .trim()
                                                .isEmpty
                                            ? 'Plumber'
                                            : ((job['plumber_first_name'] ??
                                                    '') +
                                                ' ' +
                                                (job['plumber_last_name'] ??
                                                    ''));
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => ChatDetailPage(
                                              userName: plumberName,
                                              chatId: chatId,
                                              customerId: int.tryParse(
                                                customerId,
                                              ),
                                              plumberId: int.tryParse(
                                                plumberId,
                                              ),
                                            ),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.message,
                                        color: Color(0xFF2196F3),
                                        size: 16.sp,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        "Message",
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Color(0xFF2196F3),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                            : TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: null,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.grey,
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    actionText,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ),
                ],
              ),
              // Add map/navigate icon for dispatched jobs
              if (isDispatched)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: -7.w,
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 34.sp,
                              height: 34.sp,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 3,
                                    offset: Offset(0, 0),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 5.sp,
                              child: Icon(
                                Icons.location_on,
                                color: Color(0xFF2D9FD0),
                                size: 25.sp,
                              ),
                            ),
                            Positioned(
                              bottom: 3.sp,
                              child: CustomPaint(
                                size: Size(12.sp, 6.sp),
                                painter: _CircleBelowPainter(),
                              ),
                            ),
                          ],
                        ),
                        tooltip: "Navigate",
                        onPressed: () async {
                          final job = jobOrders.firstWhere(
                            (j) =>
                                (j['job_order_id']?.toString() ==
                                    jobOrderId.toString()),
                            orElse: () => null,
                          );
                          if (job != null) {
                            // Get customer location from Firebase
                            final customerId = job['customer_id']?.toString();
                            double? customerLat;
                            double? customerLng;
                            String? customerProfileImage;
                            if (customerId != null && customerId.isNotEmpty) {
                              final ref = FirebaseDatabase.instance.ref(
                                'locations/customers/$customerId',
                              );
                              final snapshot = await ref.get();
                              final data = snapshot.value;
                              if (data is Map) {
                                customerLat = (data['lat'] as num?)?.toDouble();
                                customerLng = (data['lng'] as num?)?.toDouble();
                              }
                              // Fetch customer profile image from tbl_customers
                              final customerRes = await http.get(
                                Uri.parse(
                                  'https://aquafixsansimon.com/api/customers.php',
                                ),
                              );
                              if (customerRes.statusCode == 200) {
                                final List users = json.decode(
                                  customerRes.body,
                                );
                                final user = users.firstWhere(
                                  (u) =>
                                      u['customer_id'].toString() == customerId,
                                  orElse: () => null,
                                );
                                if (user != null &&
                                    user['profile_image'] != null &&
                                    user['profile_image']
                                        .toString()
                                        .isNotEmpty) {
                                  customerProfileImage = user['profile_image'];
                                }
                              }
                            }

                            // --- ADD: Fetch plumber location from Firebase ---
                            final plumberId = job['plumber_id']?.toString();
                            double? plumberLat;
                            double? plumberLng;
                            String? plumberName;
                            String? plumberAvatar;
                            Uint8List? plumberProfileImageBytes;
                            if (plumberId != null && plumberId.isNotEmpty) {
                              final ref = FirebaseDatabase.instance.ref(
                                'locations/plumbers/$plumberId',
                              );
                              final snapshot = await ref.get();
                              final data = snapshot.value;
                              if (data is Map) {
                                plumberLat = (data['lat'] as num?)?.toDouble();
                                plumberLng = (data['lng'] as num?)?.toDouble();
                              }
                              // Fetch plumber name and avatar from tbl_plumbers
                              final plumberRes = await http.get(
                                Uri.parse(
                                  'https://aquafixsansimon.com/api/plumbers.php',
                                ),
                              );
                              if (plumberRes.statusCode == 200) {
                                final List users = json.decode(plumberRes.body);
                                final user = users.firstWhere(
                                  (u) =>
                                      u['plumber_id'].toString() == plumberId,
                                  orElse: () => null,
                                );
                                if (user != null) {
                                  plumberName =
                                      ((user['first_name'] ?? '') +
                                              ' ' +
                                              (user['last_name'] ?? ''))
                                          .trim();
                                  plumberAvatar =
                                      user['average_rating']?.toString();
                                  if (user['profile_image'] != null &&
                                      user['profile_image']
                                          .toString()
                                          .isNotEmpty) {
                                    final url =
                                        'https://aquafixsansimon.com/uploads/profiles/plumbers/${user['profile_image']}';
                                    final imgResp = await http.get(
                                      Uri.parse(url),
                                    );
                                    if (imgResp.statusCode == 200) {
                                      plumberProfileImageBytes =
                                          imgResp.bodyBytes;
                                    }
                                  }
                                }
                              }
                            }

                            if (!mounted) return;
                            if (customerLat != null &&
                                customerLng != null &&
                                plumberLat != null &&
                                plumberLng != null) {
                              // Set navigation flag and pass jobOrderId and plumber data
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(
                                'show_plumber_location',
                                true,
                              );
                              await prefs.setInt(
                                'navigate_job_order_id',
                                int.tryParse(job['job_order_id'].toString()) ??
                                    0,
                              );
                              Navigator.pushNamed(
                                context,
                                '/customer_plumber',
                                arguments: {
                                  'customerLat': customerLat,
                                  'customerLng': customerLng,
                                  'customerProfileImage': customerProfileImage,
                                  'jobOrderId': job['job_order_id'],
                                  'plumberLat': plumberLat,
                                  'plumberLng': plumberLng,
                                  'plumberName': plumberName,
                                  'plumberAvatar': plumberAvatar,
                                  'plumberProfileImageBytes':
                                      plumberProfileImageBytes,
                                  // Pass plumber_id so PlumberPage can use it directly
                                  'plumber_id': plumberId,
                                },
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Customer or plumber location not available.',
                                  ),
                                ),
                              );
                            }
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Customer location not available.',
                                ),
                              ),
                            );
                          }
                        },
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

  Future<void> _cancelJobOrder(BuildContext context, dynamic jobOrderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel Job Order'),
            content: const Text(
              'Are you sure you want to cancel this job order?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    final response = await http.post(
      Uri.parse('https://aquafixsansimon.com/api/job_orders.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'job_order_id': jobOrderId,
        'status': 'Cancelled',
        'action': 'cancel',
      }),
    );
    print(
      'Cancel response: ${response.statusCode} ${response.body}',
    ); // <-- Add this line
    if (response.statusCode == 200) {
      setState(() {
        final idx = jobOrders.indexWhere(
          (j) => (j['job_order_id'] ?? '').toString() == jobOrderId.toString(),
        );
        if (idx != -1) {
          jobOrders[idx]['status'] = 'Cancelled';
        }
        _applyFilterAndSearch();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job order cancelled.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel job order.')),
      );
    }
  }

  void _showJobOrderDetailsModal(BuildContext context, String jobId) async {
    // Find by either job_order_id or jo_number
    final job = jobOrders.firstWhere(
      (j) =>
          (j['job_order_id']?.toString() == jobId) ||
          (j['jo_number']?.toString() == jobId),
      orElse: () => null,
    );
    if (job == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job order details not found.')),
      );
      return;
    }

    // Fetch attachments from backend
    List<dynamic> attachments = [];
    try {
      print(
        'Fetching attachments for job_order_id: ${job['job_order_id'] ?? jobId}',
      );
      final resp = await http.get(
        Uri.parse(
          'https://aquafixsansimon.com/api/jo_media_list.php?job_order_id=${job['job_order_id'] ?? jobId}',
        ),
      );
      print('Attachments API response status: ${resp.statusCode}');
      print('Attachments API response body: ${resp.body}');
      if (resp.statusCode == 200) {
        // Try/catch for JSON decode to handle HTML or error responses
        try {
          final decoded = json.decode(resp.body);
          print('Decoded attachments: $decoded');
          if (decoded is List && decoded.isNotEmpty) {
            attachments = decoded;
          }
        } catch (e) {
          print(
            'Error decoding attachments JSON: $e\nRAW RESPONSE:\n${resp.body}',
          );
          // Print first 200 chars for easier debugging
          print(
            'First 200 chars of response: ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}',
          );
        }
      } else {
        print('Attachment API error: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      print('Error fetching attachments: $e');
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(18.w),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Job Order Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Divider(),
                  Text(
                    'Job Order #: ${job['jo_number'] ?? ''}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Account Number: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${job['account_number'] ?? job['account_no'] ?? ''}',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Account Name: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['account_name'] ?? ''}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Meter Number: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['meter_no'] ?? ''}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Reason/Issue: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['category'] ?? ''}'),
                      ],
                    ),
                  ),
                  if ((job['other_issue'] ?? '').toString().isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 15.sp, color: Colors.black),
                        children: [
                          TextSpan(
                            text: 'Other Issue: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.sp,
                            ),
                          ),
                          TextSpan(text: '${job['other_issue']}'),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Status: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['status'] ?? ''}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Date and Time: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${_formatDate(job['created_at'], null)}'
                              '${job['created_at'] != null && job['created_at'].toString().isNotEmpty && job['created_at'].toString().toLowerCase() != 'null' ? ' ${DateTime.tryParse(job['created_at'].toString()) != null ? DateTime.parse(job['created_at'].toString()).hour.toString().padLeft(2, '0') + ':' + DateTime.parse(job['created_at'].toString()).minute.toString().padLeft(2, '0') : ''}' : ''}',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Plumber: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(
                          text:
                              ((job['plumber_first_name'] ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty &&
                                      (job['plumber_last_name'] ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty)
                                  ? 'Unassigned'
                                  : '${job['plumber_first_name'] ?? ''} ${job['plumber_last_name'] ?? ''}',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Address: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: _formatAddress(job)),
                      ],
                    ),
                  ),
                  if ((job['notes'] ?? '').toString().isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 15.sp, color: Colors.black),
                        children: [
                          TextSpan(
                            text: 'Notes: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.sp,
                            ),
                          ),
                          TextSpan(text: '${job['notes']}'),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 18.h),
                  // Attachments section
                  Text(
                    'Attachments',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (attachments.isEmpty)
                    Text(
                      'No attachments.',
                      style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: () {
                        int imageCount = 1;
                        int videoCount = 1;
                        return attachments.map<Widget>((att) {
                          final isImage = att['media_type'] == 'image';
                          final isVideo = att['media_type'] == 'video';
                          final fileName = att['file_path'] ?? '';
                          final url =
                              'https://aquafixsansimon.com/uploads/jo_media/$fileName';
                          String displayLabel;
                          if (isImage) {
                            displayLabel =
                                'Image_${imageCount.toString().padLeft(2, '0')}';
                            imageCount++;
                          } else if (isVideo) {
                            displayLabel =
                                'Video_${videoCount.toString().padLeft(2, '0')}';
                            videoCount++;
                          } else {
                            displayLabel = fileName;
                          }
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8.h),
                            child: GestureDetector(
                              onTap: () {
                                if (isImage) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => _FullImageViewNetwork(
                                            imageUrl: url,
                                          ),
                                    ),
                                  );
                                } else if (isVideo) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => _FullVideoViewNetwork(
                                            videoUrl: url,
                                          ),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    isImage ? Icons.image : Icons.videocam,
                                    color: isImage ? Colors.blue : Colors.red,
                                    size: 22.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Flexible(
                                    child: Text(
                                      displayLabel,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.blueAccent,
                                        decoration: TextDecoration.underline,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList();
                      }(),
                    ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D9FD0),
                        minimumSize: Size.fromHeight(40.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'Close',
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
          ),
        );
      },
    );
  }

  void _showRatingDetailsModal(BuildContext context, String jobId) async {
    // Find by either job_order_id or jo_number
    final job = jobOrders.firstWhere(
      (j) =>
          (j['job_order_id']?.toString() == jobId) ||
          (j['jo_number']?.toString() == jobId),
      orElse: () => null,
    );
    if (job == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job order details not found.')),
      );
      return;
    }
    // Fetch rating details from backend
    final jobOrderIdInt = job['job_order_id']?.toString() ?? jobId;
    print('Requesting ratings for job_order_id: $jobOrderIdInt');
    final response = await http.get(
      Uri.parse(
        'https://aquafixsansimon.com/api/ratings.php?job_order_id=$jobOrderIdInt',
      ),
    );
    List ratings = [];
    if (response.statusCode == 200) {
      ratings = json.decode(response.body);
    }
    print('Fetched ratings: ' + ratings.toString()); // <-- Debugging line

    // Fetch attachments from backend
    List<dynamic> attachments = [];
    try {
      print(
        'Fetching attachments for job_order_id: ${job['job_order_id'] ?? jobId}',
      );
      final resp = await http.get(
        Uri.parse(
          'https://aquafixsansimon.com/api/jo_media_list.php?job_order_id=${job['job_order_id'] ?? jobId}',
        ),
      );
      print('Attachments API response status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        // Try/catch for JSON decode to handle HTML or error responses
        try {
          final decoded = json.decode(resp.body);
          if (decoded is List && decoded.isNotEmpty) {
            attachments = decoded;
          }
        } catch (e) {
          print(
            'Error decoding attachments JSON: $e\nRAW RESPONSE:\n${resp.body}',
          );
          // Print first 200 chars for easier debugging
          print(
            'First 200 chars of response: ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}',
          );
        }
      } else {
        print('Attachment API error: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      print('Error fetching attachments: $e');
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(18.w),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Job Order Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Divider(),
                  Text(
                    'Job Order #: ${job['jo_number'] ?? ''}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Account Number: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${job['account_number'] ?? job['account_no'] ?? ''}',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Account Name: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['account_name'] ?? ''}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Meter Number: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['meter_no'] ?? ''}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Reason/Issue: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['category'] ?? ''}'),
                      ],
                    ),
                  ),
                  if ((job['other_issue'] ?? '').toString().isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 15.sp, color: Colors.black),
                        children: [
                          TextSpan(
                            text: 'Other Issue: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.sp,
                            ),
                          ),
                          TextSpan(text: '${job['other_issue']}'),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Status: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['status'] ?? ''}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Date: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${_formatDate(job['date'], job['created_at'])}',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Plumber: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(
                          text:
                              ((job['plumber_first_name'] ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty &&
                                      (job['plumber_last_name'] ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty)
                                  ? 'Unassigned'
                                  : '${job['plumber_first_name'] ?? ''} ${job['plumber_last_name'] ?? ''}',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Address: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: _formatAddress(job)),
                      ],
                    ),
                  ),
                  if ((job['notes'] ?? '').toString().isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 15.sp, color: Colors.black),
                        children: [
                          TextSpan(
                            text: 'Notes: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.sp,
                            ),
                          ),
                          TextSpan(text: '${job['notes']}'),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 18.h),
                  // Attachments section
                  Text(
                    'Attachments',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (attachments.isEmpty)
                    Text(
                      'No attachments.',
                      style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: () {
                        int imageCount = 1;
                        int videoCount = 1;
                        return attachments.map<Widget>((att) {
                          final isImage = att['media_type'] == 'image';
                          final isVideo = att['media_type'] == 'video';
                          final fileName = att['file_path'] ?? '';
                          final url =
                              'https://aquafixsansimon.com/uploads/jo_media/$fileName';
                          String displayLabel;
                          if (isImage) {
                            displayLabel =
                                'Image_${imageCount.toString().padLeft(2, '0')}';
                            imageCount++;
                          } else if (isVideo) {
                            displayLabel =
                                'Video_${videoCount.toString().padLeft(2, '0')}';
                            videoCount++;
                          } else {
                            displayLabel = fileName;
                          }
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8.h),
                            child: GestureDetector(
                              onTap: () {
                                if (isImage) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => _FullImageViewNetwork(
                                            imageUrl: url,
                                          ),
                                    ),
                                  );
                                } else if (isVideo) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => _FullVideoViewNetwork(
                                            videoUrl: url,
                                          ),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    isImage ? Icons.image : Icons.videocam,
                                    color: isImage ? Colors.blue : Colors.red,
                                    size: 22.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Flexible(
                                    child: Text(
                                      displayLabel,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.blueAccent,
                                        decoration: TextDecoration.underline,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList();
                      }(),
                    ),
                  Divider(height: 24.h),
                  if (ratings.isNotEmpty) ...[
                    Text(
                      'Your Rating',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                    ),

                    SizedBox(height: 4.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i <
                                  (ratings[0]['ratings'] is int
                                      ? ratings[0]['ratings']
                                      : int.tryParse(
                                            ratings[0]['ratings'].toString(),
                                          ) ??
                                          0)
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.orange,
                          size: 22.sp,
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      ratings[0]['comment'] ?? '',
                      style: TextStyle(fontSize: 15.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      ratings[0]['created_at'] ?? '',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                    ),
                  ],

                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D9FD0),
                        minimumSize: Size.fromHeight(40.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'Close',
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
          ),
        );
      },
    );
  }

  void _showRatePlumberModal(
    BuildContext context,
    String plumberName,
    String jobId,
  ) {
    int _rating = 5;
    final TextEditingController _commentController = TextEditingController();

    Future<void> _submitRating() async {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('customer_id') ?? '';
      // Find the job order in filteredJobOrders or jobOrders
      final job = jobOrders.firstWhere(
        (j) => (j['job_order_id'] ?? '').toString() == jobId,
        orElse: () => null,
      );
      if (job == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Job order not found.')));
        return;
      }
      final plumberId = job['plumber_id']?.toString() ?? '';
      final data = {
        "job_order_id": jobId,
        "plumber_id": plumberId,
        "customer_id": customerId,
        "ratings": _rating,
        "comment": _commentController.text.trim(),
      };
      // --- Show loading modal ---
      Navigator.of(context).pop(); // Close the rating modal first
      await _showLoadingModal(context, message: "Sending Rating...");
      final response = await http.post(
        Uri.parse('https://aquafixsansimon.com/api/ratings.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      Navigator.of(context, rootNavigator: true).pop(); // Close loading modal

      if (response.statusCode == 200) {
        setState(() {
          _ratedJobIds.add(int.tryParse(jobId) ?? 0);
        });
        await _showThankYouModal(
          context,
          "Thank you for your feedback! Your rating has been submitted.",
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit rating.')),
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(18.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rate the Plumber',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close, size: 20.sp),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  plumberName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                StatefulBuilder(
                  builder: (context, setModalState) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _rating = index + 1;
                            });
                          },
                          child: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: Colors.orange,
                            size: 38.sp,
                          ),
                        );
                      }),
                    );
                  },
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _commentController,
                  minLines: 4,
                  maxLines: 7,
                  decoration: InputDecoration(
                    hintText: 'Leave a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 14.h,
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D9FD0),
                      minimumSize: Size.fromHeight(40.h),
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
  }
}

// Full screen image viewer for network images
class _FullImageViewNetwork extends StatelessWidget {
  final String imageUrl;
  const _FullImageViewNetwork({required this.imageUrl, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: 80.h),
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            scaleEnabled: true,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              width: 1.sw,
              height: 0.8.sh,
            ),
          ),
        ),
      ),
    );
  }
}

// Full screen video viewer for network videos
class _FullVideoViewNetwork extends StatefulWidget {
  final String videoUrl;
  const _FullVideoViewNetwork({required this.videoUrl, Key? key})
    : super(key: key);

  @override
  State<_FullVideoViewNetwork> createState() => _FullVideoViewNetworkState();
}

class _FullVideoViewNetworkState extends State<_FullVideoViewNetwork> {
  late VideoPlayerController _videoPlayerController;
  bool _isInitialized = false;

  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _videoPlayerController.initialize().then((_) {
      setState(() {
        _isInitialized = true;
        _videoPlayerController.play();
      });
      if (_videoPlayerController.value.isPlaying) {
        _hideControlsAfterDelay();
      }
    });
    _videoPlayerController.addListener(() {
      if (mounted) setState(() {});
      if (_videoPlayerController.value.isPlaying && _showControls) {
        _hideControlsAfterDelay();
      }
    });
  }

  void _hideControlsAfterDelay() {
    _hideTimer?.cancel();
    if (_videoPlayerController.value.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child:
                _isInitialized
                    ? AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              setState(() {
                                _showControls = !_showControls;
                                if (_showControls &&
                                    _videoPlayerController.value.isPlaying) {
                                  _hideControlsAfterDelay();
                                } else if (!_showControls) {
                                  _hideTimer?.cancel();
                                }
                              });
                            },
                            child: VideoPlayer(_videoPlayerController),
                          ),
                          if (_showControls)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: null,
                              bottom: null,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.replay_10,
                                      color: Colors.white,
                                      size: 38.sp,
                                    ),
                                    onPressed: () {
                                      final current =
                                          _videoPlayerController.value.position;
                                      final newPosition =
                                          current - Duration(seconds: 10);
                                      _videoPlayerController.seekTo(
                                        newPosition > Duration.zero
                                            ? newPosition
                                            : Duration.zero,
                                      );
                                    },
                                  ),
                                  SizedBox(width: 16.w),
                                  IconButton(
                                    icon: Icon(
                                      _videoPlayerController.value.isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                      color: Colors.white,
                                      size: 48.sp,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (_videoPlayerController
                                            .value
                                            .isPlaying) {
                                          _videoPlayerController.pause();
                                          _showControls = true;
                                          _hideTimer?.cancel();
                                        } else {
                                          _videoPlayerController.play();
                                          _hideControlsAfterDelay();
                                        }
                                      });
                                    },
                                  ),
                                  SizedBox(width: 16.w),
                                  IconButton(
                                    icon: Icon(
                                      Icons.forward_10,
                                      color: Colors.white,
                                      size: 38.sp,
                                    ),
                                    onPressed: () {
                                      final current =
                                          _videoPlayerController.value.position;
                                      final duration =
                                          _videoPlayerController.value.duration;
                                      final newPosition =
                                          current + Duration(seconds: 10);
                                      _videoPlayerController.seekTo(
                                        newPosition < duration
                                            ? newPosition
                                            : duration,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          // Progress bar and timer at the very bottom
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: double.infinity,
                              color: Colors.black.withOpacity(0.7),
                              padding: EdgeInsets.only(
                                left: 0,
                                right: 0,
                                top: MediaQuery.of(context).padding.bottom,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 8.w,
                                      right: 8.w,
                                      top: 8.h,
                                      bottom: 0,
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            _videoPlayerController
                                                    .value
                                                    .isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 24.sp,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              if (_videoPlayerController
                                                  .value
                                                  .isPlaying) {
                                                _videoPlayerController.pause();
                                                _showControls = true;
                                                _hideTimer?.cancel();
                                              } else {
                                                _videoPlayerController.play();
                                                _hideControlsAfterDelay();
                                              }
                                            });
                                          },
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          "${_formatDuration(_videoPlayerController.value.position)} / ${_formatDuration(_videoPlayerController.value.duration)}",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.sp,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12.r),
                                        topRight: Radius.circular(12.r),
                                      ),
                                      child: VideoProgressIndicator(
                                        _videoPlayerController,
                                        allowScrubbing: true,
                                        colors: VideoProgressColors(
                                          playedColor: Colors.white,
                                          backgroundColor: Colors.white24,
                                          bufferedColor: Colors.white54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : const CircularProgressIndicator(),
          ),
          Positioned(
            top: 50.h,
            left: 10.w,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 28.sp),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "${d.inHours > 0 ? '${twoDigits(d.inHours)}:' : ''}$minutes:$seconds";
  }
}

// Add this class at the bottom of the file (outside the MyJobOrdersPage class)
class _CircleBelowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = Colors.black12
          ..style = PaintingStyle.fill;
    Rect ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height * 0.7,
    );
    canvas.drawOval(ovalRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProgressModal extends StatelessWidget {
  final Stream<double> progressStream;
  final String title;
  final String message;
  const _ProgressModal({
    required this.progressStream,
    this.title = 'Sending',
    this.message = 'Please wait while we process your request...',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFE6F1FA),
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
                  title,
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
                  percent < 100 ? message : 'Done!',
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
