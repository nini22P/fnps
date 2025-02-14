import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/utils/content_info.dart';

List<Change> useChangeInfo(Content content, String? hmacKey) {
  if (content.category != Category.update || hmacKey == null) return [];

  final changeInfo = useState<List<Change>>([]);

  useEffect(() {
    () async {
      final updateInfo = await getUpdateInfo(content, hmacKey);
      final changeInfoUrl = updateInfo?.changeInfoUrl;
      if (changeInfoUrl != null) {
        changeInfo.value = await getChangeInfo(changeInfoUrl);
      }
    }();
    return null;
  }, []);

  return changeInfo.value;
}
