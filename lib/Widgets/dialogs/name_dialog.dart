import 'package:flutter/material.dart';

class NameDialog extends StatefulWidget {
  final String? currentName;
  final Function(String) onNameChanged;

  const NameDialog({
    super.key,
    this.currentName,
    required this.onNameChanged,
  });

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Name your File", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      content: Row(
        children: [
          // const Text("Name:"),
          // const SizedBox(width: 12),
          Expanded(
            child: TextField(
              
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon( Icons.edit),
                hintText: 'Enter a name for your file',
              ),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.only(top: 0,right: 16, bottom: 0),
      actions: [
        TextButton(
          onPressed: () {
            if (_controller.text.trim().isEmpty) {
                // Show a warning if the name is empty
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a name'),
                  duration: Duration(seconds: 2),
                ),
                );
              return;
            }
            widget.onNameChanged(_controller.text);
            Navigator.pop(context, _controller.text);
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}