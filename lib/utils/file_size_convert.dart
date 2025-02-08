String? fileSizeConvert(int fileSize) =>
    fileSize == 0 ? '0' : (fileSize / 1024 / 1024).toStringAsFixed(2);
