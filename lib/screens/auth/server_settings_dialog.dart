import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../services/api_client.dart';
import '../../services/server_settings.dart';

/// Szerver cím beállító dialógus megnyitása.
///
/// `true`-val tér vissza, ha a cím megváltozott. A mentés a
/// SharedPreferences-be kerül, és azonnal érvénybe lép a megosztott
/// [ApiClient] példányon, így nem kell újraindítani az alkalmazást.
Future<bool> showServerSettingsDialog(BuildContext context) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => const _ServerSettingsDialog(),
  );

  return changed ?? false;
}

class _ServerSettingsDialog extends StatefulWidget {
  const _ServerSettingsDialog();

  @override
  State<_ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<_ServerSettingsDialog> {
  final _settings = ServerSettings();
  late final TextEditingController _controller;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<ApiClient>().baseUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyPreset(String url) {
    _controller.text = url;
    setState(() => _error = null);
  }

  Future<void> _save() async {
    final normalized = ApiConfig.normalizeBaseUrl(_controller.text);

    if (normalized == null) {
      setState(() {
        _error = 'Érvénytelen cím. Példa: http://192.168.1.10:3000/api';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final apiClient = context.read<ApiClient>();

    await _settings.write(normalized);
    apiClient.baseUrl = normalized;

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API szerver címe'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('serverUrlField'),
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Szerver URL',
                hintText: 'http://192.168.1.10:3000/api',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'USB-vel csatlakoztatott telefonhoz indítsd el a számítógépen:\n'
              'adb reverse tcp:3000 tcp:3000\n'
              'majd használd a http://localhost:3000/api címet.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('USB / localhost'),
                  onPressed: () =>
                      _applyPreset('http://localhost:3000/api'),
                ),
                ActionChip(
                  label: const Text('Emulátor'),
                  onPressed: () => _applyPreset('http://10.0.2.2:3000/api'),
                ),
                ActionChip(
                  label: const Text('Alapértelmezett'),
                  onPressed: () => _applyPreset(ApiConfig.baseUrl),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('MÉGSE'),
        ),
        FilledButton(
          key: const Key('serverUrlSaveButton'),
          onPressed: _isSaving ? null : _save,
          child: const Text('MENTÉS'),
        ),
      ],
    );
  }
}
