import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/models/config.dart';
import 'package:fnps/utils/get_localizations.dart';

Future<Source?> showSourceDialog(
        BuildContext context, Source source, String title) async =>
    await showDialog<Source>(
      context: context,
      builder: (context) => SourceDialog(source: source, title: title),
    );

class SourceDialog extends HookWidget {
  const SourceDialog({super.key, required this.source, required this.title});

  final Source source;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final textController = useTextEditingController(text: source.url);
    final selectedUrl = useState(source.url);

    final initSource = Config.initConfig.sources.firstWhereOrNull((item) =>
        item.platform == source.platform && item.category == source.category);

    final initUrl = initSource?.url;

    return AlertDialog(
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (initUrl != null)
                _buildRadioTile(
                  title: '使用内置地址',
                  value: initUrl,
                  groupValue: selectedUrl.value,
                  onChanged: (value) {
                    selectedUrl.value = initUrl;
                    textController.text = initUrl;
                  },
                ),
              _buildRadioTile(
                title: '使用自定义地址',
                value: 'custom',
                groupValue: selectedUrl.value,
                onChanged: (value) {
                  selectedUrl.value = 'custom';
                  textController.clear();
                },
              ),
              _buildRadioTile(
                title: '选择本地文件',
                value: null,
                groupValue: selectedUrl.value,
                onChanged: (value) {
                  selectedUrl.value = null;
                  textController.clear();
                },
              ),
              if (selectedUrl.value != null)
                TextFormField(
                  autofocus: true,
                  controller: textController,
                  keyboardType: TextInputType.url,
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(t.cancel),
        ),
        if (selectedUrl.value != null)
          TextButton(
            onPressed: () {
              if (textController.text.isEmpty ||
                  !textController.text.startsWith('http')) {
                return;
              }
              Navigator.pop(
                context,
                Source(
                  platform: source.platform,
                  category: source.category,
                  url: textController.text,
                ),
              );
            },
            child: Text(t.ok),
          ),
        if (selectedUrl.value == null)
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                Source(
                  platform: source.platform,
                  category: source.category,
                  url: null,
                ),
              );
            },
            child: Text(t.select_local_file),
          )
      ],
    );
  }

  ListTile _buildRadioTile({
    required String title,
    required String? value,
    required String? groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      contentPadding: const EdgeInsets.only(left: 8),
      leading: Radio<String?>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(value),
    );
  }
}
