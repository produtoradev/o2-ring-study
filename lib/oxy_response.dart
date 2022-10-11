class OxyResponse {
  late int number;
  late int length;
  late bool state;
  late List<int> content;
  late var json;

  OxyResponse(List<int> bytes) {
    print(bytes);
    state = bytes.elementAt(1).toInt() == 0x00;
    number = bytes.elementAt(4).toUnsigned(2); // idk
    length = bytes.length - 8;
    content = bytes.getRange(7, 7 + length).toList();
    // json = jsonDecode(String.fromCharCodes(content));
  }
}
