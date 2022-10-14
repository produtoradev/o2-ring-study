class OxyFile {
  late String fileName;
  late int fileSize;
  List<int> fileContent = [];
  int index = 0;
  int packageNumber = 0;

  OxyFile(this.fileName, this.fileSize);

  addContent(List<int> bytes) {
    if (index < fileSize) {
      fileContent.addAll(bytes);
      index += bytes.length;
    }
  }
}
