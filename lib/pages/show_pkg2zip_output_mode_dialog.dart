import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/models/config.dart';
import 'package:fnps/provider/config_provider.dart';
import 'package:fnps/utils/get_localizations.dart';
import 'package:provider/provider.dart';

Future<Source?> showPkg2zipOutputModeDialog(BuildContext context) async =>
    await showDialog<Source>(
      context: context,
      builder: (context) => Pkg2zipOutputModeDialog(),
    );

class Pkg2zipOutputModeDialog extends HookWidget {
  const Pkg2zipOutputModeDialog({super.key});
  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    final configProvider = Provider.of<ConfigProvider>(context);
    final config = configProvider.config;

    return AlertDialog(
      title: Text(
        t.pkg2zip_output_mode,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: RadioGroup<Pkg2zipOutputMode>(
            groupValue: config.pkg2zipOutputMode,
            onChanged: (Pkg2zipOutputMode? value) {
              if (value != null) {
                configProvider.updateConfig(
                  config.copyWith(pkg2zipOutputMode: value),
                );
              }
              Navigator.pop(context);
            },
            child: Column(
              children: [
                ListTile(
                  title: Text(t.extract_to_folder),
                  leading: Radio<Pkg2zipOutputMode>(
                    value: Pkg2zipOutputMode.folder,
                  ),
                  onTap: () {
                    configProvider.updateConfig(
                      config.copyWith(
                        pkg2zipOutputMode: Pkg2zipOutputMode.folder,
                      ),
                    );
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text(t.convert_to_zip),
                  leading: Radio<Pkg2zipOutputMode>(
                    value: Pkg2zipOutputMode.zip,
                  ),
                  onTap: () {
                    configProvider.updateConfig(
                      config.copyWith(pkg2zipOutputMode: Pkg2zipOutputMode.zip),
                    );
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
      ],
    );
  }
}
