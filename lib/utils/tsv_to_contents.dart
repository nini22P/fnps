import 'package:csv/csv.dart';
import 'package:vita_dl/models/content.dart';

Future<List<Content>> tsvToContents(
    String content, Platform platform, Category category) async {
  String processedContent = content
      .replaceAll(',', '__COMMA__')
      .replaceAll("'", '__SINGLE_QUOTE__')
      .replaceAll('"', '__DOUBLE_QUOTE__')
      .replaceAll('\t', ',');
  List<List<dynamic>> data =
      const CsvToListConverter().convert(processedContent);
  List<Content> contents = [];
  if (data.isNotEmpty) {
    List<String> headers =
        List<String>.from(data[0].map((item) => item.toString()));
    contents = data.sublist(1).map((row) {
      Map<String, dynamic> rowMap = {};
      for (int i = 0; i < headers.length; i++) {
        if (i < row.length) {
          rowMap[headers[i]] = row[i]
              .toString()
              .replaceAll('__COMMA__', ',')
              .replaceAll('__SINGLE_QUOTE__', "'")
              .replaceAll('__DOUBLE_QUOTE__', '"');
        } else {
          rowMap[headers[i]] = null;
        }
      }
      return Content.convert(rowMap, platform, category);
    }).toList();
  }
  return contents;
}
