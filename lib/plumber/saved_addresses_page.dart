import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'add_address_page.dart';
import 'edit_address_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({super.key});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  List<Map<String, dynamic>> addresses = [];
  final String apiUrl =
      'https://aquafixsansimon.com/api/addresses.php'; // Change to your API URL

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('customer_id') ?? '';
      if (customerId.isEmpty) {
        setState(() {
          addresses = [];
        });
        return;
      }
      final response = await http.get(
        Uri.parse('$apiUrl?customer_id=$customerId'),
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          addresses = data.cast<Map<String, dynamic>>();
        });
        // Debug: print addresses to check id field
        print('Fetched addresses: $addresses');
      }
    } catch (e) {
      // Handle error (show snackbar, etc.)
    }
  }

  Future<void> _addAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAddressPage()),
    );
    if (result != null && result is Map<String, dynamic>) {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(result),
      );
      if (response.statusCode == 200) {
        _fetchAddresses();
      }
    }
  }

  Future<void> _editAddress(int index) async {
    final address = addresses[index];

    String? street = address['street'] ?? '';
    String? barangay = address['barangay'];
    String? municipality = address['municipality'];
    String? province = address['province'];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditAddressPage(
              initialLabel: address['label'],
              initialStreet: street,
              initialProvince: province,
              initialMunicipality: municipality,
              initialBarangay: barangay,
            ),
      ),
    );
    if (result != null && result is Map<String, dynamic>) {
      // Ensure id is int
      final rawId = address['address_id'];
      int? id;
      if (rawId is int) {
        id = rawId;
      } else if (rawId is String) {
        id = int.tryParse(rawId);
      }
      if (id == null || id <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid address id: $rawId')));
        return;
      }
      result['id'] = id.toString(); // Ensure id is a String
      result.remove(
        'address_id',
      ); // Remove address_id to avoid confusion in backend

      // Ensure all required fields are present
      result['street'] = result['street'] ?? address['street'] ?? '';
      result['barangay'] = result['barangay'] ?? address['barangay'] ?? '';
      result['municipality'] =
          result['municipality'] ?? address['municipality'] ?? '';
      result['province'] = result['province'] ?? address['province'] ?? '';

      // Remove any combined 'address' field if present
      result.remove('address');

      print('Sending PUT payload: ${json.encode(result)}');
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(result),
      );
      print('PUT response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        _fetchAddresses();
      }
    }
  }

  Future<void> _deleteAddress(int index) async {
    final address = addresses[index];
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Delete Address"),
            content: const Text(
              "Are you sure you want to delete this address?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  // Debug: print address before parsing id
                  print('Attempting to delete address: $address');
                  final rawId = address['address_id'];
                  // Accept both int and string representations
                  int? id;
                  if (rawId is int) {
                    id = rawId;
                  } else if (rawId is String) {
                    id = int.tryParse(rawId);
                  }
                  if (id == null || id <= 0) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invalid address id: $rawId')),
                    );
                    return;
                  }
                  print('Deleting address with id: $id');
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
                    _fetchAddresses();
                  } else {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to delete address: ${response.body}',
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
        title: Text(
          "CLW Accounts",
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Expanded(
              child:
                  addresses.isEmpty
                      ? Center(
                        child: Text(
                          "No CLW accounts yet.",
                          style: TextStyle(fontSize: 14.sp),
                        ),
                      )
                      : ListView.separated(
                        itemCount: addresses.length,
                        separatorBuilder: (_, __) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final item = addresses[index];
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
                              leading: Icon(
                                Icons.account_balance_wallet,
                                color: buttonColor,
                              ),
                              title: Text(
                                item['label']!,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                [
                                      item['street'],
                                      item['barangay'],
                                      item['municipality'],
                                      item['province'],
                                    ]
                                    .where((e) => e != null && e.isNotEmpty)
                                    .join(', '),
                                style: TextStyle(fontSize: 13.sp),
                              ),
                              trailing: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_vert, size: 20.sp),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editAddress(index);
                                  } else if (value == 'delete') {
                                    _deleteAddress(index);
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
                onPressed: _addAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                icon: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                ),
                label: Text(
                  "Add New CLW Account",
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
