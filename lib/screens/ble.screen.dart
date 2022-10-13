import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:o2ring/crc8.dart';
import 'package:o2ring/oxy_manager.dart';
import 'package:o2ring/oxy_response.dart';

class BleScreen extends StatefulWidget {
  final BluetoothDevice device;

  const BleScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<BleScreen> createState() => _BleScreenState();
}

class _BleScreenState extends State<BleScreen> {
  int mtuSize = 20;

  Guid service = Guid('14839ac4-7d7e-415c-9a42-167340cf2339');
  Guid writeCharacteristic = Guid('8B00ACE7-EB0B-49B0-BBE9-9AEE0A26E1A3');
  Guid readCharacteristic = Guid('0734594A-A8E7-4B1A-A6B1-CD5243059A57');

  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;

  StreamSubscription<List<int>>? subscription;

  List<int> response = [];

  String? lastFileName;

  bool initialized = false;

  getInfo() async {
    OxyManager mManager = OxyManager(widget.device, (OxyResponse oxyResponse) {
      print(oxyResponse.json);
    });
    await mManager.initialize();
    mManager.getInfo();
  }

  readLastFile() async {
    OxyManager mManager = OxyManager(widget.device, (oxyResponse) {
      print(oxyResponse);
    });
    await mManager.initialize();
  }

  getLastFileName() async {
    OxyManager mManager = OxyManager(widget.device, (oxyResponse) {
      List<String> fileNameList = oxyResponse.json['FileList'].split(',');
      fileNameList.remove('');
      setState(() => lastFileName = fileNameList.last);
    });
    await mManager.initialize();
    mManager.getInfo();
  }

  disconnectDevice() async {
    await widget.device.disconnect();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device'),
      ),
      body: Column(
        children: [
          Center(
            child: Text('$lastFileName'),
          ),
          TextButton(
            onPressed: getInfo,
            child: const Text('informações'),
          ),
          TextButton(
            onPressed: readLastFile,
            child: const Text('ler aquivo'),
          ),
          TextButton(
            onPressed: disconnectDevice,
            child: const Text('desconectar'),
          ),
          TextButton(
            child: const Text('definir horário'),
            onPressed: () {
              var json = {"SetTIME": "2022-10-05,09:30:00"};
              List<int> chars = jsonEncode(json).codeUnits;
              int size = chars.length;

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
              // sendCommand(bytes);
            },
          ),
          TextButton(
              child: Text('iniciar leitura'),
              onPressed: () {
                if (lastFileName == null) {
                  print('last file name is null');
                  return;
                }

                List<int> filename = lastFileName!.codeUnits;
                int length = filename.length + 1;

                Int8List bytes = Int8List(8 + length);
                bytes[0] = 0xAA;
                bytes[1] = 0x03;
                bytes[2] = ~0x03;
                bytes[5] = 0;
                bytes[6] = 0;

                for (int i = 0; i < length - 1; i++) {
                  bytes[7 + i] = filename.elementAt(i);
                }

                bytes[bytes.length - 1] = Crc8.convert(bytes);

                print('aqui');
                // sendCommand(bytes);
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

              // sendCommand(bytes);
            },
          ),
          TextButton(
            child: const Text('foo bar'),
            onPressed: () {
              /*OxyResponse oxyResponse = OxyResponse(response);
              String encodedJson = String.fromCharCodes(oxyResponse.content);
              int jsonEnd = encodedJson.lastIndexOf('}');
              String content = encodedJson.substring(0, jsonEnd + 1);
              var decodedJson = jsonDecode(content);
              List<String> fileList = decodedJson['FileList'].split(',');
              if (fileList.isNotEmpty) {
                lastFileName = fileList.lastWhere((element) => element != '');
              }
              print('último arquivo: ${lastFileName}');
              print(decodedJson);*/
            },
          )
        ],
      ),
    );
  }
}
