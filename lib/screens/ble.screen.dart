import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:o2ring/crc8.dart';
import 'package:o2ring/oxy_data_file.dart';
import 'package:o2ring/oxy_file.dart';
import 'package:o2ring/oxy_manager.dart';

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

  var responseFromOxymeter;

  int fileSize = 0;
  OxyFile? currentFile;

  late OxyManager oxyManager;

  bool loading = false;

  @override
  initState() {
    setState(() => loading = true);
    oxyManager = OxyManager(widget.device);
    oxyManager.initialize().then((_) {
      setState(() => loading = false);
    });
  }

  getInfo() {
    print('getInfo');
    oxyManager.onDone = (oxyResponse) {
      oxyManager.clearTimeout();
      oxyResponse.getInformation();
      print('oxyResponse ${oxyResponse.json}');
    };
    oxyManager.getInfo();
  }

  readFile() async {
    /*OxyManager mManager = OxyManager(widget.device, (oxyResponse) {
      print('continuando: ${oxyResponse.content}');
      currentFile!.addContent(oxyResponse.content);
      if (currentFile!.index < currentFile!.fileSize) {
        print('index: ${currentFile!.index}');
        print('fileSize: ${currentFile!.fileSize}');
        readFile();
      } else {
        print('ACABOU, É TETRA ${currentFile!.fileContent}');
      }
    });
    await mManager.initialize();
    mManager.continueReadingFile(currentFile!.packageNumber);*/
  }

  readLastFile() async {
    if (lastFileName == null) {
      getLastFileName();
    } else {
      oxyManager.onDone = (oxyResponse) {
        oxyManager.clearTimeout();
        oxyResponse.startToReadFile();
        setState(() {
          fileSize = oxyResponse.toUInt(oxyResponse.content);
          responseFromOxymeter = 'O tamanho do arquivo é: $fileSize';
          currentFile = OxyFile(lastFileName!, fileSize);
          readFileContent(0);
        });
      };
      oxyManager.readFile(lastFileName!);
    }
  }

  getLastFileName() async {
    oxyManager.onDone = (oxyResponse) {
      oxyManager.clearTimeout();
      oxyResponse.getInformation();
      List<String> fileNameList = oxyResponse.json['FileList'].split(',');
      fileNameList.remove('');
      setState(() => lastFileName = fileNameList.last);
      readLastFile();
    };
    oxyManager.getInfo();
  }

  readFileContent(int packageNumber) {
    oxyManager.onDone = (oxyResponse) {
      oxyManager.clearTimeout();
      currentFile!.addContent(oxyResponse.content);
      int index = currentFile!.index;
      int fileSize = currentFile!.fileSize;
      print('read file: ${currentFile!.fileName} => ${index} / ${fileSize}');

      if (index < fileSize) {
        readFileContent(packageNumber + 1);
      } else {
        readFileEnd();
      }
    };
    oxyManager.continueReadingFile(packageNumber);
  }

  readFileEnd() {
    oxyManager.onDone = (oxyResponse) {
      oxyManager.clearTimeout();
      print('read file finished');
      print(currentFile!.fileContent);
      OxyDataFile oxyDataFile = OxyDataFile(currentFile!.fileContent);
      currentFile = null;
    };
    oxyManager.endFileRead();
  }

  disconnectDevice() async {
    await widget.device.disconnect();
    Navigator.of(context).pop();
  }

  Widget loadBody() {
    if (loading) {
      return Center(
        child: Text('Carregando...'),
      );
    } else {
      return Column(
        children: [
          Center(
            child: Text('$lastFileName'),
          ),
          Center(
            child: Text('$responseFromOxymeter'),
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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device'),
      ),
      body: loadBody(),
    );
  }
}
