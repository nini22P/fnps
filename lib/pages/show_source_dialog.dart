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

    final initSource = Config.initConfig.sources.firstWhereOrNull((item) =>
        item.platform == source.platform && item.category == source.category);

    final initUrl = initSource?.url;

    final textController = useTextEditingController(text: source.url);
    final selectedUrl = useState(source.url == null
        ? null
        : source.url == initUrl
            ? initUrl
            : 'custom');

    return AlertDialog(
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: RadioGroup<String?>(
            groupValue: selectedUrl.value,
            onChanged: (String? value) {
              if (value == initUrl && initUrl != null && initUrl.isNotEmpty) {
                selectedUrl.value = initUrl;
                textController.text = initUrl;
              } else {
                selectedUrl.value = value;
                textController.clear();
              }
            },
            child: Column(
              children: [
                if (initUrl != null && initUrl.isNotEmpty)
                  ListTile(
                    title: Text(t.use_built_in_url),
                    leading: Radio<String?>(value: initUrl),
                    onTap: () {
                      selectedUrl.value = initUrl;
                      textController.text = initUrl;
                    },
                  ),
                ListTile(
                  title: Text(t.use_custom_url),
                  leading: Radio<String?>(value: 'custom'),
                  onTap: () {
                    selectedUrl.value = 'custom';
                    textController.clear();
                  },
                ),
                ListTile(
                  title: Text(t.select_local_file),
                  leading: Radio<String?>(value: null),
                  onTap: () {
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
}
