import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:o2ring/crc8.dart';

class BleScreen extends StatefulWidget {
  final BluetoothDevice device;

  const BleScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<BleScreen> createState() => _BleScreenState();
}

class _BleScreenState extends State<BleScreen> {
  Guid service = Guid('14839ac4-7d7e-415c-9a42-167340cf2339');
  Guid writeCharacteristic = Guid('8B00ACE7-EB0B-49B0-BBE9-9AEE0A26E1A3');
  Guid readCharacteristic = Guid('0734594A-A8E7-4B1A-A6B1-CD5243059A57');

  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;

  StreamSubscription<List<int>>? subscription;

  List<int> response = [];

  sendCommand(Int8List bytes) {
    print(bytes);
    response = [];
    _writeChar!.write(bytes, withoutResponse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device'),
      ),
      body: Column(
        children: [
          TextButton(
            child: Text('iniciar notificações'),
            onPressed: () async {
              await widget.device.requestMtu(185);
              if (subscription != null) {
                subscription!.cancel();
              }
              List<BluetoothService> services =
                  await widget.device.discoverServices();
              var service = services
                  .firstWhere((element) => element.uuid == this.service);
              _writeChar = service.characteristics
                  .firstWhere((element) => element.uuid == writeCharacteristic);
              _notifyChar = service.characteristics
                  .firstWhere((element) => element.uuid == readCharacteristic);

              if (!_notifyChar!.isNotifying) {
                _notifyChar!.setNotifyValue(true);
              }

              subscription = _notifyChar!.value.listen((event) {
                response.addAll(event);
              });
            },
          ),
          TextButton(
            child: const Text('informações'),
            onPressed: () {
              Int8List bytes = Int8List(8);
              bytes[0] = 0xAA;
              bytes[1] = 0x14;
              bytes[2] = ~0x14;
              bytes[7] = Crc8.convert(bytes);
              sendCommand(bytes);
            },
          ),
          TextButton(
            child: const Text('definir horário'),
            onPressed: () {
              var json = {"SetTIME": "2022-10-05,17:28:00"};
              var chars = jsonEncode(json).codeUnits;
              var size = chars.length;

              Int8List bytes = Int8List(8 + size);
              bytes[0] = 0xAA;
              bytes[1] = 0x16;
              bytes[2] = ~0x16;
              bytes[5] = size;
              bytes[6] = (size >> 8);

              for (int i = 0; i < size; i++) {
                bytes[7 + i] = chars.elementAt(i);
              }

              bytes[7 + size] = Crc8.convert(bytes);
              sendCommand(bytes);
            },
          ),
          TextButton(
              child: Text('iniciar leitura'),
              onPressed: () {
                String filename = '20220521151715';
                int len = filename.length;

                Int8List bytes = Int8List(8);
                bytes[0] = 0xAA;
                bytes[1] = 0x03;
                bytes[2] = ~0x03;
                bytes[5] = 0;
                bytes[6] = 0;

                /*for (int i = 0; i < len - 1; i++) {
                  bytes[7 + i] = 0;
                }*/

                bytes[bytes.length - 1] = Crc8.convert(bytes);

                print('aqui');
                sendCommand(bytes);
                print('ali');
              }),
          TextButton(
            child: Text('ler'),
            onPressed: () {
              print('ler');
            },
          ),
          TextButton(
            child: Text('finalizar leitura'),
            onPressed: () {
              Int8List bytes = Int8List(8);
              bytes[0] = 0xAA;
              bytes[1] = 0x05;
              bytes[2] = ~0x05;
              bytes[7] = Crc8.convert(bytes);

              sendCommand(bytes);
            },
          ),
          TextButton(
            child: const Text('foo bar'),
            onPressed: () {
              print('foo');
            },
          )
        ],
      ),
    );
  }
}
