import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AllFaqsPage extends StatelessWidget {
  const AllFaqsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        "question": "How do I accept a job request?",
        "answer":
            "Go to the job requests section and tap 'Accept' on the job you want to take.",
      },
      {
        "question": "How do I update my availability?",
        "answer":
            "Navigate to your profile and select 'Edit Availability' to update your working hours.",
      },
      {
        "question": "How do I contact a customer?",
        "answer":
            "Once you accept a job, you can view the customer's contact details in the job details page.",
      },
      {
        "question": "How do I mark a job as completed?",
        "answer":
            "Open the job details and tap the 'Mark as Completed' button after finishing the work.",
      },
      {
        "question": "How do I view my earnings?",
        "answer":
            "Go to the 'Earnings' section from the main menu to see your completed jobs and total earnings.",
      },
      {
        "question": "How do I edit my profile?",
        "answer":
            "Tap your profile picture or name on the main menu, then select 'Edit Profile' to update your information.",
      },
      {
        "question": "What if I can't make it to a scheduled job?",
        "answer":
            "Contact the customer as soon as possible and update your availability in the app.",
      },
      {
        "question": "How do I get more job requests?",
        "answer":
            "Keep your profile updated, maintain good ratings, and set your availability to receive more requests.",
      },
      {
        "question": "How do I reset my password?",
        "answer":
            "On the login screen, tap 'Forgot Password' and follow the instructions to reset your password.",
      },
      {
        "question": "Who do I contact for technical support?",
        "answer":
            "Use the 'Support' section in the app to email or call our support team.",
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C9CD9),
        title: Text(
          'All FAQs',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 22.sp, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 10.h),
        child: ListView.separated(
          itemCount: faqs.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder:
              (context, i) => Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: EdgeInsets.all(16.w),
                  title: Text(
                    faqs[i]["question"]!,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Text(
                      faqs[i]["answer"]!,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
