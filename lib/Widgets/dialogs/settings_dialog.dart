import 'package:docu_scan/Utils/tools.dart';
import 'package:flutter/material.dart';

class SettingsDialog extends StatefulWidget {
  final bool currentCompressionSetting;
  final Function(bool) onCompressionChanged;

  const SettingsDialog({
    super.key,
    required this.currentCompressionSetting,
    required this.onCompressionChanged,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late bool _compress;

  @override
  void initState() {
    super.initState();
    _compress = widget.currentCompressionSetting;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Settings"),
      content: Row(
        children: [
          const Text("Compress Images?"),
          const SizedBox(width: 12),
          Switch(
            value: _compress,
            onChanged: (value) {
              setState(() => _compress = value);
              widget.onCompressionChanged(value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Close", style: Tools.h3(context).copyWith(color: Theme.of(context).colorScheme.inverseSurface),),
        ),
      ],
    );
  }
}