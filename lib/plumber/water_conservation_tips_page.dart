import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class WaterConservationTipsPage extends StatefulWidget {
  const WaterConservationTipsPage({super.key});

  @override
  State<WaterConservationTipsPage> createState() =>
      _WaterConservationTipsPageState();
}

class _WaterConservationTipsPageState extends State<WaterConservationTipsPage> {
  List<bool> _tipViewed = [];
  final List<Map<String, String>> _tips = [
    {
      "title": "Fix leaks promptly",
      "details":
          "Even a small leak can waste thousands of liters per year. Check faucets, pipes, and toilets regularly.",
    },
    {
      "title": "Install smart irrigation controllers",
      "details":
          "Smart controllers adjust watering schedules based on weather and soil moisture, saving water in your garden.",
    },
    {
      "title": "Collect rainwater for outdoor use",
      "details":
          "Use barrels to capture rainwater and use it for watering gardens or cleaning outdoors.",
    },
    {
      "title": "Use water-efficient appliances",
      "details":
          "Choose washing machines and dishwashers with high water efficiency ratings to reduce consumption.",
    },
    {
      "title": "Shorten shower time",
      "details":
          "Reducing showers by just 2 minutes can save up to 150 liters per week per person.",
    },
    {
      "title": "Mulch your garden",
      "details":
          "Mulch retains soil moisture and reduces the need for frequent watering, especially in hot weather.",
    },
    {
      "title": "Turn off the tap while brushing teeth or shaving",
      "details": "This simple habit can save up to 20 liters of water per day.",
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadViewedTips();
  }

  Future<void> _loadViewedTips() async {
    final prefs = await SharedPreferences.getInstance();
    final viewed =
        prefs.getStringList('viewedTips') ?? List.filled(_tips.length, 'false');
    setState(() {
      _tipViewed = viewed.map((e) => e == 'true').toList();
    });
  }

  Future<void> _markTipViewed(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _tipViewed[index] = true;
    final updated = _tipViewed.map((e) => e.toString()).toList();
    await prefs.setStringList('viewedTips', updated);
    setState(() {});
  }

  double get _progressValue {
    final viewedCount = _tipViewed.where((e) => e).length;
    return viewedCount / _tips.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Water Conservation Tips",
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2C9CD9),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18.sp),
      ),
      body: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTipOfTheDay(),
            SizedBox(height: 20.h),
            _buildCategoryChips(),
            SizedBox(height: 20.h),
            Expanded(child: _buildExpandableTips()),
            SizedBox(height: 20.h),
            _buildViewedProgressBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTipOfTheDay() {
    final now = DateTime.now();
    final dayOfYear = int.parse(
      DateFormat("D").format(now),
    ); // requires intl package
    final tipIndex = dayOfYear % _tips.length;
    final tip = _tips[tipIndex];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 34, 142, 200),
            Color.fromARGB(255, 81, 200, 255),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.white, size: 28.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              "Tip of the Day: ${tip["title"]} – ${tip["details"]}",
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = ["Home", "Garden", "Technology", "Habits", "Community"];
    final icons = [
      Icons.home,
      Icons.park,
      Icons.devices,
      Icons.repeat,
      Icons.groups,
    ];

    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (context, index) {
          return Chip(
            backgroundColor: Colors.white,
            label: Row(
              children: [
                Icon(icons[index], size: 16.sp, color: const Color(0xFF2C9CD9)),
                SizedBox(width: 5.w),
                Text(categories[index], style: TextStyle(fontSize: 13.sp)),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
              side: const BorderSide(color: Color(0xFF2C9CD9)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpandableTips() {
    return ListView.separated(
      itemCount: _tips.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final tip = _tips[index];
        return ExpansionTile(
          onExpansionChanged: (expanded) {
            if (expanded && !_tipViewed[index]) {
              _markTipViewed(index);
            }
          },
          tilePadding: EdgeInsets.symmetric(horizontal: 12.w),
          title: Text(tip["title"]!, style: TextStyle(fontSize: 14.sp)),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 12.h, left: 12.w, right: 12.w),
              child: Text(tip["details"]!, style: TextStyle(fontSize: 13.sp)),
            ),
          ],
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        );
      },
    );
  }

  Widget _buildViewedProgressBar() {
    final percent = (_progressValue * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Tip Viewing Progress", style: TextStyle(fontSize: 13.sp)),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: LinearProgressIndicator(
            value: _progressValue,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2C9CD9)),
            minHeight: 10.h,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          "You've viewed $percent% of the tips!",
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
        ),
      ],
    );
  }
}
