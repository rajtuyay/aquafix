import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:dio/dio.dart';
import 'dart:async';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final List<Map<String, String>> _faqs = [
    {
      "question": "How do I create a job order request?",
      "answer":
          "To create a job order, navigate to the Home page, select ‘Request Job Order’, fill out the required details, and submit your request.",
    },
    {
      "question": "How can I track the status of my job order?",
      "answer":
          "You can track the status of your job order by visiting the 'My Job Orders' section in your account.",
    },
    {
      "question": "Can I cancel my job order?",
      "answer":
          "Yes. Go to the Profile section and select My Job Orders, choose your request, and select Cancel Job Order.",
    },
    {
      "question": "How do I know if my job order is approved?",
      "answer":
          "You will receive a notification once your job order has been approved by the administrator. You can also check the status in the Profile section under My Job Orders.",
    },
    // --- Add new FAQs below ---
    {
      "question": "What should I do if my plumber has not arrived?",
      "answer":
          "If your plumber is delayed, go to the Profile section and select My Job Orders and click the location button to track the plumber.",
    },
    {
      "question":
          "How long does it take for a plumber to be dispatched after I submit a job order?",
      "answer":
          "Dispatch time may vary depending on the plumber's availability and the urgency of the request. You will be notified once a plumber has been assigned.",
    },
    {
      "question": "What happens if no plumber is available for my request?",
      "answer":
          "If no plumber is available at the moment, your request will remain in Pending status until a plumber is assigned.",
    },
    {
      "question": "Can I request a specific plumber?",
      "answer":
          "No. The assignment of plumbers is managed by the administrator, based on availability and service location.",
    },
    {
      "question": "Can I rate the plumber’s service?",
      "answer":
          "Yes. After your job order is marked as Accomplished, you can rate and review your plumber’s performance.",
    },
    {
      "question": "What does the water bill graph show?",
      "answer":
          "The graph displays a comparison between your previous and current water bills. It helps you see changes in your consumption and understand whether your bill has increased or decreased.",
    },
    {
      "question": "What are the possible charges for a job order?",
      "answer":
          "Charges depend on the type of service requested and the materials used. The estimated cost will be shown before confirming your job order.",
    },
    {
      "question": "What should I do if I experience recurring water problems?",
      "answer":
          "If the issue persists, you can submit a new job order or report it directly in the Customer Support section for priority checking.",
    },
    {
      "question": "How do I update my account details?",
      "answer":
          "You can update your profile details—such as your name, contact number, and more—in the Edit Profile section under Settings.",
    },
    {
      "question": "How do I recover my account if I forgot my login details?",
      "answer":
          "Use the Forgot Password option on the login page or contact support for assistance.",
    },
    {
      "question": "How do I contact support?",
      "answer":
          "You can reach our team via Email Support or Call Support listed in the Help section.",
    },
    {
      "question": "Is my personal information secure in the application?",
      "answer":
          "Yes. All personal and account information is stored securely in compliance with data privacy regulations.",
    },
  ];

  List<bool> _faqExpanded = [];
  String _faqSearch = "";
  bool _showAllFaqs = false; // Add this flag

  @override
  void initState() {
    super.initState();
    _faqExpanded = List.filled(_faqs.length, false);
  }

  void _expandAllFaqs() {
    setState(() {
      _showAllFaqs = true;
      // Ensure all accordions are closed when showing all
      _faqExpanded = List.filled(_faqs.length, false);
    });
  }

  void _collapseAllFaqs() {
    setState(() {
      _showAllFaqs = false;
      _faqExpanded = List.filled(_faqs.length, false);
    });
  }

  List<Map<String, String>> get _filteredFaqs {
    if (_faqSearch.trim().isEmpty) return _faqs;
    return _faqs
        .where(
          (faq) =>
              faq["question"]!.toLowerCase().contains(_faqSearch.toLowerCase()),
        )
        .toList();
  }

  List<Map<String, String>> get _visibleFaqs {
    final faqs = _filteredFaqs;
    if (_showAllFaqs || faqs.length <= 3) return faqs;
    return faqs.sublist(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C9CD9),
        elevation: 0,
        title: Text(
          'Help & Support',
          style: TextStyle(
            fontSize: 18.sp,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 22.sp, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.w),
        child: ListView(
          children: [
            SizedBox(height: 18.h),
            // Modern Section Title
            _sectionTitle(
              "Frequently Asked Questions",
              icon: Icons.help_outline,
            ),
            SizedBox(height: 8.h),
            // Search Bar
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: Color(0xFF2C9CD9)),
                  hintText: "Search FAQs...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                style: TextStyle(fontSize: 15.sp),
                onChanged: (val) => setState(() => _faqSearch = val),
              ),
            ),
            SizedBox(height: 14.h),
            // FAQ Accordions
            ...List.generate(_visibleFaqs.length, (index) {
              final faq = _visibleFaqs[index];
              final origIndex = _faqs.indexOf(faq);
              return Card(
                elevation: 3,
                margin: EdgeInsets.only(bottom: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    key: PageStorageKey('faq_$origIndex'),
                    initiallyExpanded: _faqExpanded[origIndex],
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _faqExpanded[origIndex] = expanded;
                      });
                    },

                    title: Text(
                      faq["question"]!,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          left: 16.w,
                          right: 16.w,
                          bottom: 12.h,
                          top: 4.h,
                        ),
                        child: Text(
                          faq["answer"]!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Button to expand/collapse all FAQs
            Padding(
              padding: EdgeInsets.only(top: 4.h, bottom: 18.h),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(
                        _showAllFaqs ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C9CD9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        elevation: 2,
                      ),
                      onPressed:
                          _showAllFaqs ? _collapseAllFaqs : _expandAllFaqs,
                      label: Text(
                        _showAllFaqs ? "Collapse All FAQs" : "See All FAQs",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Section: Support
            _sectionTitle("Call Support", icon: Icons.support_agent),
            SizedBox(height: 6.h),
            _supportTile(
              title: "Email Contact",
              icon: Icons.email,
              contactInfo: "contact@aquafixsansimon.com",
            ),
            _supportTile(
              title: "Call Contact",
              icon: Icons.phone,
              contactInfo: "0916 371 3652",
            ),
            SizedBox(height: 18.h),
            // Section: Report an Issue
            _sectionTitle("Report an Issue", icon: Icons.report_problem),
            SizedBox(height: 6.h),
            _simpleTile(
              title: "Report a Bug",
              icon: Icons.bug_report,
              onTap: () {
                _showReportBugModal(context);
              },
            ),
            _simpleTile(
              title: "Send Feedback",
              icon: Icons.feedback,
              onTap: () {
                _showFeedbackModal(context);
              },
            ),
            SizedBox(height: 18.h),
          ],
        ),
      ),
    );
  }

  IconData expandedIcon(bool expanded) =>
      expanded ? Icons.remove_circle_outline : Icons.add_circle_outline;

  Widget _sectionTitle(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null)
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF2C9CD9).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            padding: EdgeInsets.all(6.w),
            child: Icon(icon, color: Color(0xFF2C9CD9), size: 22.sp),
          ),
        if (icon != null) SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // Support tile widget
  Widget _supportTile({
    required String title,
    required IconData icon,
    required String contactInfo,
  }) {
    return Builder(
      builder:
          (context) => ListTile(
            leading: Icon(icon, size: 22.sp, color: Color(0xFF2C9CD9)),
            title: Text(title, style: TextStyle(fontSize: 15.sp)),
            subtitle: Text(contactInfo, style: TextStyle(fontSize: 14.sp)),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16.sp,
              color: Colors.grey,
            ),
            onTap: () async {
              if (title == "Email Contact") {
                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: 'contact@aquafixsansimon.com',
                  query: 'subject=Aquafix Support Inquiry',
                );
                try {
                  await launchUrl(
                    emailUri,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open email app.')),
                  );
                }
              } else if (title == "Call Contact") {
                final Uri telUri = Uri(scheme: 'tel', path: '+639163713652');
                try {
                  // Check if the device can launch the dialer
                  if (await canLaunchUrl(telUri)) {
                    await launchUrl(
                      telUri,
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No dialer found on device.')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not initiate call.')),
                  );
                }
              }
            },
          ),
    );
  }

  // Simple tile for actions like reporting bugs or providing feedback
  Widget _simpleTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22.sp, color: Colors.black54),
      title: Text(title, style: TextStyle(fontSize: 14.sp)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16.sp, color: Colors.grey),
      onTap: onTap,
    );
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
    // Simulate progress for UI only (remove if you have real progress)
    for (int i = 1; i <= 100; i += 5) {
      await Future.delayed(Duration(milliseconds: 20));
      _progressController.add(i / 100);
    }
    _progressController.close();
  }

  // Use Dio for sending email (simulate async process)
  Future<bool> _sendSupportEmail({
    required String subject,
    required String body,
  }) async {
    // If you want to use Dio for a REST API, replace below:
    // final dio = Dio();
    // await dio.post('https://your-api/send-email', data: {...});
    // For now, keep SMTP logic.
    final smtpServer = SmtpServer(
      'smtp.gmail.com',
      username: 'rajtuyay24@gmail.com',
      password: 'muke nauu udqq ydfr',
      port: 587,
      ssl: false,
    );
    final message =
        Message()
          ..from = Address('rajtuyay24@gmail.com', 'Aquafix User')
          ..recipients.add('support@aquafixsansimon.com')
          ..subject = subject
          ..text = body;
    try {
      final sendReport = await send(message, smtpServer);
      print('SendReport: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Send error: $e');
      return false;
    }
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

  void _showFeedbackModal(BuildContext parentContext) {
    int _rating = 5;
    final TextEditingController _commentController = TextEditingController();
    String errorText = '';

    showDialog(
      context: parentContext,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFFE6F1FA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double modalWidth = MediaQuery.of(context).size.width * 0.9;
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: modalWidth,
                      maxWidth: modalWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 24.h,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(child: SizedBox()),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Icon(
                                  Icons.close,
                                  size: 22.sp,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            "We appreciate your\nfeedback.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 21.sp,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 14.h),
                          Text(
                            "We are always looking for ways to improve your experience.\nPlease take a moment to evaluate and tell us what you think.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.sp,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 18.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    _rating = index + 1;
                                  });
                                },
                                child: Icon(
                                  index < _rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber, // <-- gold color
                                  size: 34.sp,
                                ),
                              );
                            }),
                          ),
                          SizedBox(height: 18.h),
                          TextField(
                            controller: _commentController,
                            minLines: 5,
                            maxLines: 7,
                            decoration: InputDecoration(
                              hintText:
                                  "What can we do to improve your experience?",
                              hintStyle: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 16.h,
                              ),
                              errorText:
                                  errorText.isNotEmpty ? errorText : null,
                            ),
                          ),
                          SizedBox(height: 18.h),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_commentController.text.trim().isEmpty) {
                                  setModalState(() {
                                    errorText = "Comment is required.";
                                  });
                                  return;
                                }
                                Navigator.of(dialogContext).pop();
                                await _showLoadingModal(
                                  parentContext,
                                  message: "Sending Feedback...",
                                );
                                final sent = await _sendSupportEmail(
                                  subject:
                                      "Aquafix Feedback (Rating: $_rating)",
                                  body: _commentController.text,
                                );
                                Navigator.of(
                                  parentContext,
                                  rootNavigator: true,
                                ).pop(); // Close loading modal
                                await _showThankYouModal(
                                  parentContext,
                                  sent
                                      ? "Your feedback has been sent to support. We appreciate your input!"
                                      : "Sorry, we couldn't send your feedback. Please try again later.",
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
                                "Submit My Feedback",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16.sp,
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
          ),
        );
      },
    );
  }

  void _showReportBugModal(BuildContext parentContext) {
    final TextEditingController _descController = TextEditingController();
    String errorText = '';

    showDialog(
      context: parentContext,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFFF8FBFD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double modalWidth = MediaQuery.of(context).size.width * 0.9;
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: modalWidth,
                      maxWidth: modalWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 24.h,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(child: SizedBox()),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Icon(
                                  Icons.close,
                                  size: 22.sp,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Icon(
                            Icons.bug_report,
                            color: Color(0xFF2D9FD0),
                            size: 38.sp,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            "Report a Bug",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20.sp,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            "Found something not working as expected?\nLet us know so we can fix it!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 18.h),
                          TextField(
                            controller: _descController,
                            minLines: 5,
                            maxLines: 8,
                            decoration: InputDecoration(
                              hintText: "Describe the issue in detail...",
                              hintStyle: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 16.h,
                              ),
                              errorText:
                                  errorText.isNotEmpty ? errorText : null,
                            ),
                          ),
                          SizedBox(height: 18.h),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(
                                Icons.bug_report,
                                color: Colors.white,
                                size: 18.sp,
                              ),
                              label: Text(
                                "Submit Bug Report",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                ),
                              ),
                              onPressed: () async {
                                if (_descController.text.trim().isEmpty) {
                                  setModalState(() {
                                    errorText = "Description is required.";
                                  });
                                  return;
                                }
                                Navigator.of(dialogContext).pop();
                                await _showLoadingModal(
                                  parentContext,
                                  message: "Sending Bug Report...",
                                );
                                final sent = await _sendSupportEmail(
                                  subject: "Aquafix Bug Report",
                                  body: _descController.text,
                                );
                                Navigator.of(
                                  parentContext,
                                  rootNavigator: true,
                                ).pop(); // Close loading modal
                                await _showThankYouModal(
                                  parentContext,
                                  sent
                                      ? "Your bug report has been sent to support. Thank you for helping us improve!"
                                      : "Sorry, we couldn't send your report. Please try again later.",
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2D9FD0),
                                minimumSize: Size.fromHeight(44.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
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
          ),
        );
      },
    );
  }
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
