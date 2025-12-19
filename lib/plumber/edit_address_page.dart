import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class EditAddressPage extends StatefulWidget {
  final String? initialLabel;
  final String? initialStreet;
  final String? initialProvince;
  final String? initialMunicipality;
  final String? initialBarangay;

  const EditAddressPage({
    super.key,
    this.initialLabel,
    this.initialStreet,
    this.initialProvince,
    this.initialMunicipality,
    this.initialBarangay,
  });

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _labelController;
  late TextEditingController _streetController;

  String? selectedProvince;
  String? selectedMunicipality;
  String? selectedBarangay;

  final List<String> barangays = [
    "Concepcion",
    "Dela Paz",
    "San Pedro",
    "San Juan",
    "San Pablo Proper",
    "San Miguel",
    "Sta. Monica",
    "Sta. Cruz",
    "San Nicolas",
    "San Jose",
    "San Agustin",
    "San Isidro",
    "Santo Niño",
    "San Pablo Libutad",
    "San Pablo Propio",
  ];

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.initialLabel ?? "");
    _streetController = TextEditingController(text: widget.initialStreet ?? "");
    // Only allow "Pampanga" for province and "San Simon" for municipality
    selectedProvince = "Pampanga";
    selectedMunicipality = "San Simon";
    // Only set barangay if it's in the list, else null
    selectedBarangay =
        barangays.contains(widget.initialBarangay)
            ? widget.initialBarangay
            : null;
  }

  void _saveAddress() {
    if (_formKey.currentState!.validate()) {
      final newAddress = {
        "label": _labelController.text,
        "street": _streetController.text,
        "barangay": selectedBarangay,
        "municipality": selectedMunicipality,
        "province": selectedProvince,
      };

      Navigator.pop(context, newAddress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF2C9CD9);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          "Edit CLW Account",
          style: TextStyle(fontSize: 18.sp, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Label
              TextFormField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: "Account Label (e.g., Home, Office)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? "Please enter a label"
                            : null,
              ),
              SizedBox(height: 16.h),

              // Street
              TextFormField(
                controller: _streetController,
                decoration: InputDecoration(
                  labelText: "House No. / Purok / Street",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? "Please enter street details"
                            : null,
              ),
              SizedBox(height: 16.h),

              // Province Dropdown (Fixed)
              DropdownButtonFormField<String>(
                value: selectedProvince,
                decoration: InputDecoration(
                  labelText: "Province",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                items: [
                  DropdownMenuItem(value: "Pampanga", child: Text("Pampanga")),
                ],
                onChanged: (_) {},
              ),
              SizedBox(height: 16.h),

              // Municipality Dropdown (Fixed)
              DropdownButtonFormField<String>(
                value: selectedMunicipality,
                decoration: InputDecoration(
                  labelText: "Municipality",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: "San Simon",
                    child: Text("San Simon"),
                  ),
                ],
                onChanged: (_) {},
              ),
              SizedBox(height: 16.h),

              // Barangay Dropdown (Dynamic)
              DropdownButtonFormField<String>(
                value: selectedBarangay,
                decoration: InputDecoration(
                  labelText: "Barangay",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                items:
                    barangays
                        .map(
                          (bgy) =>
                              DropdownMenuItem(value: bgy, child: Text(bgy)),
                        )
                        .toList(),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? "Please select a barangay"
                            : null,
                onChanged: (value) {
                  setState(() {
                    selectedBarangay = value;
                  });
                },
              ),
              SizedBox(height: 30.h),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    "Save CLW Account",
                    style: TextStyle(fontSize: 15.sp, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
