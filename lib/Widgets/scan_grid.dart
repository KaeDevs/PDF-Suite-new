import 'dart:io';
import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class ScanGrid extends StatelessWidget {
  final List<String> imagePaths;
  final Function(int)? onImageDelete;
  final void Function(int oldIndex, int newIndex)? onReorder;

  const ScanGrid({
    super.key,
    required this.imagePaths,
    this.onImageDelete,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final items = List.generate(imagePaths.length, (index) {
      final path = imagePaths[index];
      return ClipRRect(
        key: ValueKey(path),
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                spreadRadius: 0,
                offset: const Offset(0, 2),
                color: Colors.black.withOpacity(0.08),
              )
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                ),
              ),
              if (onImageDelete != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.red,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => onImageDelete!(index),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });

    if (onReorder == null) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        padding: const EdgeInsets.all(16),
        children: items,
      );
    }

    return ReorderableGridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      onReorder: onReorder!,
      dragWidgetBuilder: (index, child) => Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
      children: items,
    );
  }
}