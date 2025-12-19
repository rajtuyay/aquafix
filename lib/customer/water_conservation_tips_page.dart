import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WaterConservationTipsPage extends StatefulWidget {
  const WaterConservationTipsPage({super.key});

  @override
  State<WaterConservationTipsPage> createState() =>
      _WaterConservationTipsPageState();
}

class _WaterConservationTipsPageState extends State<WaterConservationTipsPage> {
  final List<String> _weeklyTips = [
    "Fix leaks immediately — even a small dripping faucet can waste liters of water daily.",
    "Turn off the tap while brushing your teeth or washing hands.",
    "Run washing machines and dishwashers only with full loads.",
    "Water your plants early in the morning or late in the evening to reduce evaporation.",
    "Use water-efficient fixtures like low-flow faucets and dual-flush toilets.",
    "Limit shower time to 5 minutes or less.",
    "Collect rainwater for cleaning outdoor areas or flushing toilets.",
  ];
  // New structure: category -> subcategories -> tips
  final List<Map<String, dynamic>> _categories = [
    {
      "name": "Home",
      "icon": Icons.home,
      "color": Color(0xFF2C9CD9),
      "subcategories": [
        {
          "name": "Leaks & Fixtures",
          "tips": [
            "Fix leaks immediately — even a small dripping faucet can waste liters of water daily.",
            "Use water-efficient fixtures like low-flow faucets and dual-flush toilets.",
          ],
        },
        {
          "name": "Reuse & Rainwater",
          "tips": [
            "Collect rainwater for cleaning outdoor areas or flushing toilets.",
            "Reuse laundry rinse water for cleaning floors or watering plants.",
          ],
        },
        {
          "name": "Appliances",
          "tips": [
            "Run washing machines and dishwashers only with full loads.",
          ],
        },
      ],
    },
    {
      "name": "Habits",
      "icon": Icons.repeat,
      "color": Color(0xFF4CAF50),
      "subcategories": [
        {
          "name": "Daily Habits",
          "tips": [
            "Turn off the tap while brushing your teeth or washing hands.",
            "Limit shower time to 5 minutes or less.",
            "Use a basin when washing dishes instead of running water continuously.",
          ],
        },
        {
          "name": "Monitoring",
          "tips": [
            "Regularly check your water meter for unusual increases that might mean hidden leaks.",
            "Report leaks in your area to your local waterworks immediately.",
          ],
        },
      ],
    },
    {
      "name": "Technology",
      "icon": Icons.devices,
      "color": Color(0xFF9C27B0),
      "subcategories": [
        {
          "name": "Smart Devices",
          "tips": [
            "Install smart water meters to monitor usage in real-time.",
            "Use leak detection sensors to get alerts when unusual water flow is detected.",
          ],
        },
        {
          "name": "Efficient Appliances",
          "tips": [
            "Use water-efficient appliances like inverter washing machines.",
          ],
        },
        {
          "name": "Apps & Recycling",
          "tips": [
            "Take advantage of mobile apps from your waterworks to track your consumption.",
            "Consider water recycling systems for greywater (e.g., laundry water reuse).",
          ],
        },
      ],
    },
    {
      "name": "Garden",
      "icon": Icons.park,
      "color": Color(0xFF388E3C),
      "subcategories": [
        {
          "name": "Watering",
          "tips": [
            "Water your plants early in the morning or late in the evening to reduce evaporation.",
            "Use drip irrigation or soaker hoses instead of sprinklers for efficiency.",
          ],
        },
        {
          "name": "Plant Choice",
          "tips": ["Choose drought-resistant plants that need less water."],
        },
        {
          "name": "Rain & Mulch",
          "tips": [
            "Collect and use rainwater for watering gardens.",
            "Mulch your soil to keep it moist longer and reduce watering frequency.",
          ],
        },
      ],
    },
    {
      "name": "Community",
      "icon": Icons.groups,
      "color": Color(0xFF0288D1),
      "subcategories": [
        {
          "name": "Awareness",
          "tips": [
            "Encourage neighbors to report leaks and busted pipes right away.",
            "Educate children and youth about the importance of saving water.",
            "Share water-saving practices on social media to inspire others.",
          ],
        },
        {
          "name": "Action",
          "tips": [
            "Join community clean-up drives to prevent water pollution.",
            "Support waterworks programs for pipeline maintenance and conservation.",
          ],
        },
      ],
    },
  ];

  // Flatten tips for progress tracking
  late final int _totalTips = _categories.fold<int>(
    0,
    (sum, cat) =>
        sum +
        (cat['subcategories'] as List).fold<int>(
          0,
          (s, sub) => s + (sub['tips'] as List).length,
        ),
  );
  List<bool> _tipViewed = [];

  int _selectedCategoryIndex = 0; // Track selected category
  List<bool> _expandedSubcategories = []; // Track expansion state

  @override
  void initState() {
    super.initState();
    _loadViewedTips();
    _initExpandedSubcategories();
  }

  void _initExpandedSubcategories() {
    final subLen =
        (_categories[_selectedCategoryIndex]['subcategories'] as List).length;
    _expandedSubcategories = List<bool>.filled(subLen, false);
  }

  Future<void> _loadViewedTips() async {
    final prefs = await SharedPreferences.getInstance();
    final viewed =
        prefs.getStringList('viewedTips') ?? List.filled(_totalTips, 'false');
    setState(() {
      _tipViewed = List<bool>.filled(_totalTips, false);
      for (int i = 0; i < viewed.length && i < _totalTips; i++) {
        _tipViewed[i] = viewed[i] == 'true';
      }
    });
  }

  Future<void> _markTipViewed(int flatIndex) async {
    if (flatIndex < 0 || flatIndex >= _totalTips) return;
    if (_tipViewed[flatIndex]) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tipViewed[flatIndex] = true;
    });
    final updated = _tipViewed.map((e) => e.toString()).toList();
    await prefs.setStringList('viewedTips', updated);
  }

  double get _progressValue {
    final viewedCount = _tipViewed.where((e) => e).length;
    return viewedCount / _totalTips;
  }

  // Helper to get flat index for a tip in a subcategory
  int _getFlatIndex(int catIndex, int subIndex, int tipIndex) {
    int flatIndex = 0;
    for (int i = 0; i < catIndex; i++) {
      final subs = _categories[i]['subcategories'] as List;
      for (var sub in subs) {
        flatIndex += (sub['tips'] as List).length;
      }
    }
    for (int j = 0; j < subIndex; j++) {
      flatIndex +=
          (_categories[catIndex]['subcategories'][j]['tips'] as List).length;
    }
    return flatIndex + tipIndex;
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
        titleSpacing: 0,
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
            Expanded(child: _buildSubcategoryAccordion()),
            SizedBox(height: 20.h),
            _buildViewedProgressBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTipOfTheDay() {
    final weekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
    final tipIndex = (weekday - 1) % _weeklyTips.length;
    final tip = _weeklyTips[tipIndex];
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
              "Tip of the Day: $tip",
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final selected = index == _selectedCategoryIndex;
          return ChoiceChip(
            selected: selected,
            backgroundColor: Colors.white,
            selectedColor: cat['color'].withOpacity(0.15),
            label: Row(
              children: [
                Icon(cat['icon'], size: 16.sp, color: cat['color']),
                SizedBox(width: 5.w),
                Text(cat['name'], style: TextStyle(fontSize: 13.sp)),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
              side: BorderSide(color: cat['color']),
            ),
            onSelected: (_) {
              setState(() {
                _selectedCategoryIndex = index;
                _initExpandedSubcategories(); // Reset all accordions closed
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildSubcategoryAccordion() {
    final cat = _categories[_selectedCategoryIndex];
    final subcategories = cat['subcategories'] as List;
    // Ensure expansion state matches subcategory count
    if (_expandedSubcategories.length != subcategories.length) {
      _expandedSubcategories = List<bool>.filled(subcategories.length, false);
    }
    return ListView.separated(
      itemCount: subcategories.length,
      separatorBuilder: (_, __) => SizedBox(height: 16.h),
      itemBuilder: (context, subIndex) {
        final sub = subcategories[subIndex];
        final tips = sub['tips'] as List<String>;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ExpansionTile(
              key: PageStorageKey('${_selectedCategoryIndex}_$subIndex'),
              leading: Icon(
                Icons.folder_open,
                color: cat['color'],
                size: 22.sp,
              ),
              title: Text(
                sub['name'],
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: cat['color'],
                ),
              ),
              initiallyExpanded: _expandedSubcategories[subIndex],
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedSubcategories[subIndex] = expanded;
                  // Optionally, close others for single open accordion:
                  // for (int i = 0; i < _expandedSubcategories.length; i++) {
                  //   if (i != subIndex) _expandedSubcategories[i] = false;
                  // }
                });
              },
              children: List.generate(tips.length, (tipIndex) {
                final flatIndex = _getFlatIndex(
                  _selectedCategoryIndex,
                  subIndex,
                  tipIndex,
                );
                final viewed =
                    _tipViewed.length > flatIndex && _tipViewed[flatIndex];
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      if (!viewed) _markTipViewed(flatIndex);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            viewed
                                ? cat['color'].withOpacity(0.08)
                                : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: viewed ? cat['color'] : Colors.grey[300]!,
                          width: viewed ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Icon(
                          viewed ? Icons.check_circle : Icons.lightbulb_outline,
                          color: viewed ? cat['color'] : Colors.grey[400],
                          size: 22.sp,
                        ),
                        title: Text(
                          tips[tipIndex],
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: viewed ? cat['color'] : Colors.black87,
                          ),
                        ),
                        trailing:
                            viewed
                                ? Icon(
                                  Icons.visibility,
                                  color: cat['color'],
                                  size: 18.sp,
                                )
                                : null,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 0,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
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
