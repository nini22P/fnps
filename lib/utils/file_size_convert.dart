String? fileSizeConvert(int fileSize) =>
    fileSize == 0 ? null : (fileSize / 1024 / 1024).toStringAsFixed(2);
