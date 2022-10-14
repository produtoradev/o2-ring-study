class OxyDataFile {
  int? _version;
  int? _mode;
  DateTime? _startTime;
  int? _size;

  // result
  int? _recordTime;
  int? _asleepTime;
  int? _avgSpo2;
  int? _minSpo2;
  int? _drop3;
  int? _drop4;
  int? _duration90;
  int? _drops90;
  double? _percent90;
  double? _score;
  int? _steps;
  dynamic _spo2Wave;

  OxyDataFile(List<int> bytes) {
    // _setGeneral(bytes.getRange(0, 13));
    int index = 0;
    _version = bytes[index].toInt();
    _mode = bytes[1];
    print(_version);
  }

  _setGeneral(List<int> bytes) {}

  int toUInt(List<int> content) {
    int result = 0;
    for (int index = 0; index < content.length; index++) {
      result = result | ((content[index] & 0xFF) << 8 * index);
    }
    return result;
  }
}
