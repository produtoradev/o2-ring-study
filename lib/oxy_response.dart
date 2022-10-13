import 'dart:convert';

class OxyResponse {
  late int number;
  late int length;
  late bool state;
  late List<int> ackBufList;
  late List<int> content;
  late var json;

  OxyResponse(List<int> bytes) {
    if (bytes[0] == 0x55) {
      print(bytes);
      state = bytes.elementAt(1).toInt() == 0x00;
      number = bytes.elementAt(4).toUnsigned(64); // idk
      length = bytes.length - 8;
      ackBufList = bytes.getRange(5, 7).toList();
      content = bytes.getRange(7, 7 + length).toList();
      if (isValid) {
        List<int> ackData = bytes.getRange(7, 7 + ackBufSize).toList();
        ackData.retainWhere((element) => element != 0);
        String stringifiedAckData = String.fromCharCodes(ackData);
        json = jsonDecode(stringifiedAckData);
      }
    } else {
      throw Exception('erro');
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
}
