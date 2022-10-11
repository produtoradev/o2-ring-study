import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue/flutter_blue.dart';
import 'package:o2ring/crc8.dart';

enum OxyCommand {
  cmdGetFileStart(0x03),
  cmdGetFileData(0x04),
  cmdGetFileEnd(0x05),
  cmdGetDeviceInfo(0x14),
  cmdPing(0x15),
  cmdParaSync(0x16),
  cmdGetRTData(0x17),
  cmdFactoryDReset(0x18);

  const OxyCommand(this.value);
  final num value;
}

class OxyManager {
  final mtuSize = 20;
  final Guid serviceGuid = Guid('14839ac4-7d7e-415c-9a42-167340cf2339');
  final Guid writeCharacteristicGuid =
      Guid('8B00ACE7-EB0B-49B0-BBE9-9AEE0A26E1A3');
  final Guid readCharacteristicGuid =
      Guid('0734594A-A8E7-4B1A-A6B1-CD5243059A57');

  List<int> response = [];

  late BluetoothDevice device;
  late BluetoothCharacteristic writeCharacteristic;
  late BluetoothCharacteristic readCharacteristic;

  String? lastFileName;

  StreamSubscription<List<int>>? subscription;

  OxyManager(this.device);

  initialize() async {
    if (subscription != null) {
      subscription!.cancel();
    }

    List<BluetoothService> services = await device.discoverServices();
    BluetoothService service =
        services.firstWhere((element) => element.uuid == serviceGuid);
    writeCharacteristic = service.characteristics
        .firstWhere((element) => element.uuid == writeCharacteristicGuid);
    readCharacteristic = service.characteristics
        .firstWhere((element) => element.uuid == readCharacteristicGuid);

    if (!readCharacteristic.isNotifying) {
      readCharacteristic.setNotifyValue(true);
    }

    subscription = readCharacteristic.value.listen((event) {
      response.addAll(event);
    });
  }

  sendCommand(OxyCommand command, List<int> bytes) {
    List<List<int>> byteList = [];
    int times = (bytes.length / mtuSize).ceil();
    for (int index = 0; index < times; index++) {
      int start = mtuSize * index;
      List<int> remainingBytes = bytes.sublist(start);
      List<int> currentBytes = remainingBytes.take(mtuSize).toList();
      byteList.add(currentBytes);
    }
    response = [];
    byteList.forEach((element) {
      writeCharacteristic.write(element, withoutResponse: true);
    });
  }

  getInfo() {
    Int8List bytes = Int8List(8);
    bytes[0] = 0xAA;
    bytes[1] = 0x14;
    bytes[2] = ~0x14;
    bytes[7] = Crc8.convert(bytes);
    sendCommand(OxyCommand.cmdGetDeviceInfo, bytes);
  }
}
