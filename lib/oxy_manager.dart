import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue/flutter_blue.dart';
import 'package:o2ring/crc8.dart';
import 'package:o2ring/oxy_response.dart';

enum OxyCommand {
  cmdIdle(0x00),
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
  late Function(OxyResponse) onDone;
  late BluetoothCharacteristic writeCharacteristic;
  late BluetoothCharacteristic readCharacteristic;

  String? lastFileName;

  StreamSubscription<List<int>>? subscription;

  OxyCommand currentCommand = OxyCommand.cmdIdle;

  Timer? timeout;

  OxyManager(this.device);

  // OxyManager(this.device, this.onDone);

  initialize() async {
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
      if (response.elementAt(0) != 0x55) {
        response.clear();
      } else {
        OxyResponse oxyResponse = OxyResponse(currentCommand, response);
        if (oxyResponse.isValid) {
          onDone(oxyResponse);
        }
      }
    });
  }

  __sendCommand(List<int> bytes) {
    List<List<int>> byteList = [];
    int times = (bytes.length / mtuSize).ceil();
    for (int index = 0; index < times; index++) {
      int start = mtuSize * index;
      List<int> remainingBytes = bytes.sublist(start);
      List<int> currentBytes = remainingBytes.take(mtuSize).toList();
      byteList.add(currentBytes);
    }

    byteList.forEach((element) {
      writeCharacteristic.write(element, withoutResponse: true);
    });
  }

  sendCommand(OxyCommand command, List<int> bytes) {
    if (currentCommand != OxyCommand.cmdIdle) {
      print('sorry... I\'m busy');
      // busy
      return;
    }

    currentCommand = command;
    response.clear();

    __sendCommand(bytes);
    timeout = Timer(const Duration(seconds: 3), () {
      if (currentCommand == OxyCommand.cmdParaSync) {
        currentCommand = OxyCommand.cmdIdle;
      } else {
        currentCommand = OxyCommand.cmdIdle;
      }
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

  readFile(String filename) {
    List<int> filenameCharCodes = filename.codeUnits;
    int length = filenameCharCodes.length + 1;

    Int8List bytes = Int8List(8 + length);
    bytes[0] = 0xAA;
    bytes[1] = 0x03;
    bytes[2] = ~0x03;
    bytes[5] = length;
    bytes[6] = (length >> 8);

    for (int index = 0; index < length - 1; index++) {
      bytes[7 + index] = filenameCharCodes.elementAt(index);
    }

    bytes[bytes.length - 1] = Crc8.convert(bytes);

    sendCommand(OxyCommand.cmdGetFileStart, bytes);
  }

  continueReadingFile(int packageNumber) {
    Int8List bytes = Int8List(8);
    bytes[0] = 0xAA;
    bytes[1] = 0x04;
    bytes[2] = ~0x04;
    bytes[3] = packageNumber;
    bytes[4] = packageNumber >> 8;

    bytes[7] = Crc8.convert(bytes);

    sendCommand(OxyCommand.cmdGetFileData, bytes);
  }

  endFileRead() {
    Int8List bytes = Int8List(8);
    bytes[0] = 0xAA;
    bytes[1] = 0x05;
    bytes[2] = ~0x05;
    bytes[7] = Crc8.convert(bytes);

    sendCommand(OxyCommand.cmdGetFileStart, bytes);
  }

  clearTimeout() {
    currentCommand = OxyCommand.cmdIdle;
    timeout?.cancel();
    timeout = null;
  }
}
