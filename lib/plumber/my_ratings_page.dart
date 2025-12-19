import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MyRatingsPage extends StatefulWidget {
  const MyRatingsPage({super.key});

  @override
  State<MyRatingsPage> createState() => _MyRatingsPageState();
}

class _MyRatingsPageState extends State<MyRatingsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _ratings = [];
  int _totalRatings = 0;
  double _averageRating = 0.0;
  Map<int, int> _ratingsCount = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
  int _selectedFilter = 0; // 0 = All, 1-5 = star rating

  @override
  void initState() {
    super.initState();
    _fetchRatings();
  }

  Future<void> _fetchRatings() async {
    setState(() {
      _loading = true;
    });

    // Use plumber_id from session
    final prefs = await SharedPreferences.getInstance();
    final plumberId = prefs.getString('plumber_id') ?? '';
    if (plumberId.isEmpty) {
      setState(() {
        _ratings = [];
        _totalRatings = 0;
        _averageRating = 0.0;
        _ratingsCount = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
        _loading = false;
      });
      return;
    }

    final url = Uri.parse(
      'https://aquafixsansimon.com/api/plumber_ratings.php?plumber_id=$plumberId',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      _ratings = data.map((e) => Map<String, dynamic>.from(e)).toList();

      // Compute stats
      _totalRatings = _ratings.length;
      _averageRating =
          _totalRatings == 0
              ? 0
              : _ratings.fold<num>(
                    0,
                    (sum, r) =>
                        sum +
                        (r['ratings'] is num
                            ? r['ratings']
                            : num.tryParse(r['ratings'].toString()) ?? 0),
                  ) /
                  _totalRatings;

      _ratingsCount = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      for (var r in _ratings) {
        int val =
            r['ratings'] is num
                ? (r['ratings'] as num).toInt()
                : int.tryParse(r['ratings'].toString()) ?? 0;
        if (_ratingsCount.containsKey(val)) {
          _ratingsCount[val] = _ratingsCount[val]! + 1;
        }
      }
    }

    setState(() {
      _loading = false;
    });
  }

  // Helper to get filtered ratings
  List<Map<String, dynamic>> get _filteredRatings {
    if (_selectedFilter == 0) return _ratings;
    return _ratings.where((r) {
      int val =
          r['ratings'] is num
              ? (r['ratings'] as num).toInt()
              : int.tryParse(r['ratings'].toString()) ?? 0;
      return val == _selectedFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C9CD9),
        title: Text(
          'My Ratings',
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
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h),
        child:
            _loading
                ? Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // Ratings summary box (fixed)
                    Container(
                      padding: EdgeInsets.all(18.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Ratings breakdown
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(5, (i) {
                                int star = 5 - i;
                                int count = _ratingsCount[star] ?? 0;
                                double percent =
                                    _totalRatings > 0
                                        ? count / _totalRatings
                                        : 0;
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2.h),
                                  child: Row(
                                    children: [
                                      Text(
                                        '$star',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Icon(
                                        Icons.star,
                                        color: Color(0xFFFFC107),
                                        size: 16.sp,
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: percent,
                                          minHeight: 7.h,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Color(0xFF2C9CD9),
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        count.toString(),
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                          SizedBox(width: 18.w),
                          // Average rating
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _averageRating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 32.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < _averageRating.round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Color(0xFFFFC107),
                                    size: 18.sp,
                                  ),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                '$_totalRatings ratings',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Filter bar
                    SizedBox(
                      height: 36.h,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildFilterChip(0, "All"),
                          SizedBox(width: 8.w),
                          for (int i = 5; i >= 1; i--)
                            Padding(
                              padding: EdgeInsets.only(right: 8.w),
                              child: _buildFilterChip(
                                i,
                                "$i",
                                icon: Icons.star,
                                iconColor: Color(0xFFFFC107),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18.h),
                    // Comments section (scrollable)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Comments",
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Expanded(
                            child:
                                _filteredRatings.isEmpty
                                    ? Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24.h,
                                      ),
                                      child: Center(
                                        child: Text(
                                          "No ratings yet.",
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    )
                                    : ListView.builder(
                                      itemCount: _filteredRatings.length,
                                      itemBuilder: (context, idx) {
                                        final c = _filteredRatings[idx];
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: 14.h,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(14.r),
                                            ),
                                            padding: EdgeInsets.all(14.w),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Avatar
                                                CircleAvatar(
                                                  radius: 26.r,
                                                  backgroundColor:
                                                      Colors.grey.shade300,
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 32.sp,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                SizedBox(width: 12.w),
                                                // Comment content
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            c["customer_id"] !=
                                                                    null
                                                                ? "Anonymous"
                                                                : "",
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15.sp,
                                                            ),
                                                          ),
                                                          SizedBox(width: 8.w),
                                                          Row(
                                                            children: List.generate(
                                                              5,
                                                              (i) => Icon(
                                                                i <
                                                                        (c["ratings"]
                                                                                is int
                                                                            ? c["ratings"]
                                                                            : int.tryParse(
                                                                                  c["ratings"].toString(),
                                                                                ) ??
                                                                                0)
                                                                    ? Icons.star
                                                                    : Icons
                                                                        .star_border,
                                                                color: Color(
                                                                  0xFFFFC107,
                                                                ),
                                                                size: 16.sp,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 4.h),
                                                      Text(
                                                        c["comment"] ?? "",
                                                        style: TextStyle(
                                                          fontSize: 14.sp,
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
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  // Modern pill-style filter chip
  Widget _buildFilterChip(
    int value,
    String label, {
    IconData? icon,
    Color? iconColor,
  }) {
    final bool selected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: selected ? Color(0xFF2C9CD9) : Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: selected ? Color(0xFF2C9CD9) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: Color(0xFF2C9CD9).withOpacity(0.18),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                  : [],
        ),
        child: Row(
          children: [
            if (icon != null)
              Icon(icon, color: iconColor ?? Colors.black54, size: 16.sp),
            if (icon != null) SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
