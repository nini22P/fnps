String? fileSizeConv(int? size) => size == 0 || size == null
    ? '0 MB'
    : size > 1024 * 1024 * 1024
    ? '${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB'
    : size > 1024 * 1024
    ? '${(size / 1024 / 1024).toStringAsFixed(2)} MB'
    : '${(size / 1024).toStringAsFixed(0)} KB';
