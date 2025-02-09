String? fileSizeConv(int? fileSize) => fileSize == 0 || fileSize == null
    ? '0 MB'
    : '${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB';
