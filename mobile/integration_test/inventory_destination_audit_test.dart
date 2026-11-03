import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/inventory_destination_test.dart' as destination;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  destination.inventoryPickerCapture = (name, bytes) async {
    final path = '${Directory.systemTemp.path}/inventory-picker-$name.png';
    await File(path).writeAsBytes(bytes);
    debugPrint('INVENTORY_PICKER_VISUAL $path');
  };
  destination.main();
}
