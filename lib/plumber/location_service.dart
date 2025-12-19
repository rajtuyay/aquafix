import 'package:firebase_database/firebase_database.dart';

void updatePlumberLocation(String plumberId, double lat, double lng) {
  final ref = FirebaseDatabase.instance.ref('locations/plumbers/$plumberId');
  ref.set({
    'lat': lat,
    'lng': lng,
    'timestamp': DateTime.now().toIso8601String(),
  });
}

void updateCustomerLocation(String customerId, double lat, double lng) {
  final ref = FirebaseDatabase.instance.ref('locations/customers/$customerId');
  ref.set({
    'lat': lat,
    'lng': lng,
    'timestamp': DateTime.now().toIso8601String(),
  });
}

void listenToCustomerLocation(
  String customerId,
  void Function(double, double) onUpdate,
) {
  final ref = FirebaseDatabase.instance.ref('locations/customers/$customerId');
  ref.onValue.listen((event) {
    final data = event.snapshot.value as Map?;
    if (data != null) {
      onUpdate(data['lat'], data['lng']);
    }
  });
}

void listenToPlumberLocation(
  String plumberId,
  void Function(double, double) onUpdate,
) {
  final ref = FirebaseDatabase.instance.ref('locations/plumbers/$plumberId');
  ref.onValue.listen((event) {
    final data = event.snapshot.value as Map?;
    if (data != null) {
      onUpdate(data['lat'], data['lng']);
    }
  });
}
