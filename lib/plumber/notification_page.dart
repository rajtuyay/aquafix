import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationPage extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  const NotificationPage({Key? key, required this.notifications})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sortedNotifications = List<Map<String, dynamic>>.from(notifications);
    sortedNotifications.sort((a, b) {
      final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
      final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF2D9FD0),
        title: Text(
          'All Notifications',
          style: TextStyle(
            fontSize: 18.sp,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleSpacing: 0,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        color: Color(0xFFF7F8FA),
        child:
            sortedNotifications.isEmpty
                ? Center(
                  child: Text(
                    'No notifications yet.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
                : ListView.separated(
                  padding: EdgeInsets.all(18.w),
                  itemCount: sortedNotifications.length,
                  separatorBuilder: (_, __) => SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final notif = sortedNotifications[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _getNotifIcon(notif['title']),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    notif['title'] ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              notif['body'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 15,
                                  color: Colors.grey[500],
                                ),
                                SizedBox(width: 4),
                                Text(
                                  notif['timestamp'] != null
                                      ? notif['timestamp'].toString().substring(
                                        0,
                                        16,
                                      )
                                      : '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }

  Icon _getNotifIcon(String? title) {
    if (title != null && title.toLowerCase().contains('accomplished')) {
      return Icon(Icons.verified, color: Colors.green, size: 20);
    } else if (title != null && title.toLowerCase().contains('created')) {
      return Icon(Icons.hourglass_top, color: Color(0xFF2D9FD0), size: 20);
    } else if (title != null && title.toLowerCase().contains('cancelled')) {
      return Icon(Icons.cancel, color: Colors.red, size: 20);
    }
    return Icon(Icons.notifications_active, color: Color(0xFF2D9FD0), size: 20);
  }
}
