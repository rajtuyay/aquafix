import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final List<Map<String, String>> _faqs = [
    {
      "question": "How do I receive a job order?",
      "answer":
          "You don’t pick jobs directly. The admin reviews all customer requests and assigns them to you when you are available.",
    },
    {
      "question": "How will I know if I have a new job?",
      "answer":
          "You’ll receive a notification from the app once the admin assigns a job to you.",
    },
    {
      "question": "Can I decline a job assigned by the admin?",
      "answer":
          "If you’re unavailable, inform the admin immediately through the app or phone. Repeated declines may affect your record.",
    },
    {
      "question": "How do I update the status of my assigned job?",
      "answer":
          "You can mark the job as Accomplished or Cancelled through the app.",
    },
    {
      "question": "How do I set the status of the job as finished?",
      "answer":
          "Once the work is done, submit a report so the admin and customer are notified.",
    },
    {
      "question": "How do I navigate to the customer’s location?",
      "answer":
          "After the admin assigns you a job, click the map icon in the app to view the customer’s location and directions.",
    },
    {
      "question": "Do I need internet to receive assignments?",
      "answer":
          "Yes, you need mobile data or Wi-Fi to get job notifications and update job status.",
    },
    {
      "question": "What if the location is wrong or hard to find?",
      "answer":
          "You can contact the customer through phone call or message feature.",
    },
    {
      "question": "Can I use the app on more than one device?",
      "answer":
          "You should use one device at a time to avoid errors with job updates.",
    },
    {
      "question": "What if the app crashes during a job?",
      "answer":
          "Restart the app. If the problem continues, contact the admin or support team immediately.",
    },
    {
      "question": "What if a job requires more time than expected?",
      "answer":
          "Save a report first and then notify the admin so they are aware of the delay.",
    },
    {
      "question": "Can I communicate directly with customers?",
      "answer":
          "Yes, but only for job-related updates such as directions or clarifications.",
    },
    {
      "question": "Can multiple plumbers be assigned to one job?",
      "answer":
          "Yes, for larger jobs, the admin may assign a team of plumbers.",
    },
    {
      "question": "How do I get support if I have issues with the app or job?",
      "answer": "Contact the admin or use the app’s Help & Support feature.",
    },
  ];

  List<bool> _faqExpanded = [];
  String _faqSearch = "";
  bool _showAllFaqs = false;

  @override
  void initState() {
    super.initState();
    _faqExpanded = List.filled(_faqs.length, false);
  }

  void _expandAllFaqs() {
    setState(() {
      _showAllFaqs = true;
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C9CD9),
        title: Text(
          'Help',
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
      body: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 10.w),
        child: ListView(
          children: [
            _sectionTitle("Frequently Asked Questions"),
            SizedBox(height: 8.h),
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
            Padding(
              padding: EdgeInsets.only(top: 4.h, bottom: 10.h),
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
            _sectionTitle("Contact Support"),
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

            // Section: Report an Issue
            _sectionTitle("Report an Issue"),
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
          ],
        ),
      ),
    );
  }

  // Section title widget
  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 10.h, bottom: 10.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
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
                final Uri telUri = Uri(scheme: 'tel', path: '+639352811980');
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

  void _showFeedbackModal(BuildContext context) {
    int _rating = 5;
    final TextEditingController _commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFFE6F1FA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double modalWidth = MediaQuery.of(context).size.width * 0.9;
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
                                  index < _rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: const Color(0xFF2D9FD0),
                                  size: 34.sp,
                                ),
                              );
                            }),
                          );
                        },
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
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 16.h,
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Optionally show a thank you snackbar or dialog
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
          ),
        );
      },
    );
  }

  void _showReportBugModal(BuildContext context) {
    final TextEditingController _descController = TextEditingController();
    final TextEditingController _emailController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFFF8FBFD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double modalWidth = MediaQuery.of(context).size.width * 0.9;
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
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 16.h,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: "Your email (optional, for follow-up)",
                          hintStyle: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 14.h,
                          ),
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
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Optionally show a thank you snackbar or dialog
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
          ),
        );
      },
    );
  }
}
