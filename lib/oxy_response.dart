import 'dart:convert';

import 'package:o2ring/oxy_manager.dart';

class OxyException implements Exception {}

class OxyResponse {
  late OxyCommand command;
  late List<int> bytes;
  late int number;
  late int length;
  late bool state;
  late List<int> ackBufList;
  late List<int> content;
  late var json;

  // OxyFile
  int fileSize = 0;

  OxyResponse(this.command, this.bytes) {
    if (bytes[0] == 0x55) {
      state = bytes.elementAt(1).toInt() == 0x00;
      number = bytes.elementAt(4).toUnsigned(64); // idk
      length = bytes.length - 8;
      ackBufList = bytes.getRange(5, 7).toList();
      content = bytes.getRange(7, 7 + length).toList();
      if (isValid) {}
    } else {
      throw OxyException();
    }
  }

  int get ackBufSize {
    int result = 0;
    for (int index = 0; index < ackBufList.length; index++) {
      result = result | ((ackBufList[index] & 0xFF) << 8 * index);
    }
    return result;
  }

  bool get isValid {
    return state && length == ackBufSize;
  }

  int toUInt(List<int> content) {
    int result = 0;
    for (int index = 0; index < content.length; index++) {
      result = result | ((content[index] & 0xFF) << 8 * index);
    }
    return result;
  }

  void getInformation() {
    List<int> ackData = bytes.getRange(7, 7 + ackBufSize).toList();
    ackData.retainWhere((element) => element != 0);
    String stringifiedAckData = String.fromCharCodes(ackData);
    json = jsonDecode(stringifiedAckData);
  }

  void startToReadFile() {
    print('startToReadFile');
    fileSize = toUInt(content);
  }
}
