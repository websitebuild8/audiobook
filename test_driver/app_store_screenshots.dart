import 'dart:io';
import 'dart:typed_data';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory('build/app-store-screenshots/ipad-13');
  await directory.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final data = ByteData.sublistView(Uint8List.fromList(bytes));
      final width = data.getUint32(16);
      final height = data.getUint32(20);
      if (!((width == 2064 && height == 2752) ||
          (width == 2048 && height == 2732))) {
        throw StateError(
            'Unexpected iPad screenshot dimensions: $width x $height');
      }
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
