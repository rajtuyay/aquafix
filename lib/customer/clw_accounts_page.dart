import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'add_account_page.dart';
import 'edit_account_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class SavedAccountsPage extends StatefulWidget {
  const SavedAccountsPage({super.key});

  @override
  State<SavedAccountsPage> createState() => _SavedAccountsPageState();
}

class _SavedAccountsPageState extends State<SavedAccountsPage> {
  List<Map<String, dynamic>> accounts = [];
  final String apiUrl =
      'https://aquafixsansimon.com/api/clw_accounts.php'; // Updated API URL

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('customer_id') ?? '';
      if (customerId.isEmpty) {
        setState(() {
          accounts = [];
        });
        // Update SharedPreferences to empty
        await prefs.setString('clw_accounts', json.encode([]));
        return;
      }
      final response = await http.get(
        Uri.parse('$apiUrl?customer_id=$customerId'),
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          accounts = data.cast<Map<String, dynamic>>();
        });
        // Save fetched accounts to SharedPreferences for other pages
        await prefs.setString('clw_accounts', json.encode(data));
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _addAccount() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAccountPage()),
    );
    // Always fetch accounts after returning from AddAccountPage
    await _fetchAccounts();
  }

  Future<void> _editAccount(int index) async {
    final account = accounts[index];

    String? street = account['street'] ?? '';
    String? barangay = account['barangay'];
    String? municipality = account['municipality'];
    String? province = account['province'];
    String? accountNumber = account['account_number']?.toString();
    String? accountName = account['account_name'];
    String? meterNo = account['meter_no']?.toString();
    String? accountClass = account['account_class'];
    String? bookSeq = account['book_seq'];

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => EditAccountPage(
                initialLabel: account['label'],
                initialStreet: street,
                initialProvince: province,
                initialMunicipality: municipality,
                initialBarangay: barangay,
                initialAccountNumber: accountNumber,
                initialAccountName: accountName,
                initialMeterNo: meterNo,
                initialAccountClass: accountClass,
                initialBookSeq: bookSeq,
              ),
        ),
      );
      if (result != null && result is Map<String, dynamic>) {
        final rawId = account['clw_account_id'];
        int? id;
        if (rawId is int) {
          id = rawId;
        } else if (rawId is String) {
          id = int.tryParse(rawId);
        }
        if (id == null || id <= 0) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Invalid account id: $rawId')));
          return;
        }
        result['id'] = id.toString();
        result['label'] = result['label'] ?? account['label'] ?? '';
        result['street'] = result['street'] ?? account['street'] ?? '';
        result['barangay'] = result['barangay'] ?? account['barangay'] ?? '';
        result['municipality'] =
            result['municipality'] ?? account['municipality'] ?? '';
        result['province'] = result['province'] ?? account['province'] ?? '';
        result['account_number'] =
            result['account_number'] ?? account['account_number'] ?? '';
        result['account_name'] =
            result['account_name'] ?? account['account_name'] ?? '';
        result['meter_no'] = result['meter_no'] ?? account['meter_no'] ?? '';
        result['book_seq'] = result['book_seq'] ?? account['book_seq'] ?? '';
        result.remove('clw_account_id');
        result.remove('address');
        // Add updated_at timestamp in 'yyyy-MM-dd HH:mm:ss' format
        result['updated_at'] = DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(DateTime.now());

        final response = await http.put(
          Uri.parse('https://aquafixsansimon.com/api/clw_accounts.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(result),
        );
        print('PUT response: ${response.statusCode} ${response.body}');
        if (response.statusCode == 200) {
          // Show success/failure message from API response
          try {
            final resp = json.decode(response.body);
            final msg = resp['message'] ?? 'Account updated successfully.';
            final success = resp['success'] == true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
          } catch (_) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Account updated.')));
          }
          await _fetchAccounts();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update account: ${response.body}'),
            ),
          );
        }
      }
    } catch (e, stack) {
      print('Edit account error: $e');
      print(stack);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    }
  }

  Future<void> _deleteAccount(int index) async {
    final account = accounts[index];
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Delete Account"),
            content: const Text(
              "Are you sure you want to delete this account?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  print('Attempting to delete account: $account');
                  final rawId = account['clw_account_id'];
                  int? id;
                  if (rawId is int) {
                    id = rawId;
                  } else if (rawId is String) {
                    id = int.tryParse(rawId);
                  }
                  if (id == null || id <= 0) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invalid account id: $rawId')),
                    );
                    return;
                  }
                  print('Deleting account with id: $id');
                  final response = await http.delete(
                    Uri.parse(apiUrl),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({'id': id}),
                  );
                  print(
                    'Delete response: ${response.statusCode} ${response.body}',
                  );
                  if (response.statusCode == 200) {
                    Navigator.of(ctx).pop();
                    _fetchAccounts();
                  } else {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to delete account: ${response.body}',
                        ),
                      ),
                    );
                  }
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = const Color(0xFF2C9CD9);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: buttonColor,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Text(
          "Crystal Liquid Waterworks Accounts",
          style: TextStyle(color: Colors.white, fontSize: 17.sp),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Column(
          children: [
            Expanded(
              child:
                  accounts.isEmpty
                      ? Center(
                        child: Text(
                          "No account yet.",
                          style: TextStyle(fontSize: 14.sp),
                        ),
                      )
                      : ListView.separated(
                        itemCount: accounts.length,
                        separatorBuilder: (_, __) => SizedBox(height: 4.h),
                        itemBuilder: (context, index) {
                          final item = accounts[index];
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            elevation: 2,
                            child: ListTile(
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.fromLTRB(
                                12.w,
                                4.h,
                                0,
                                4.h,
                              ),
                              leading: Icon(Icons.person, color: buttonColor),
                              title: Text(
                                (item['label'] ?? '') +
                                    " : " +
                                    (item['account_number'] ?? '').toString(),
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if ((item['account_name'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Text(
                                      'Account Name: ${item['account_name']}',
                                      style: TextStyle(fontSize: 12.sp),
                                    ),
                                  if ((item['meter_no'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Text(
                                      'Meter No: ${item['meter_no']}',
                                      style: TextStyle(fontSize: 12.sp),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_vert, size: 20.sp),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editAccount(index);
                                  } else if (value == 'delete') {
                                    _deleteAccount(index);
                                  }
                                },
                                itemBuilder:
                                    (_) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                icon: const Icon(Icons.person, color: Colors.white),
                label: Text(
                  "Add New Account",
                  style: TextStyle(fontSize: 15.sp, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
