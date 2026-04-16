import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';


import '../models/page_size.dart';
import '../providers/font_size.dart';

class DefaultFontSizeCheckbox extends ConsumerWidget {
  final int selectedFontSize;

  const DefaultFontSizeCheckbox({super.key, required this.selectedFontSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    PageSize size = GetIt.instance.get<PageSize>();
    var defaultFontSizeAsync = ref.watch(fontSizeProvider);

    return defaultFontSizeAsync.when(error: (error, stackTrace) {
      return const Text("It's time to panic; we find a default font size!");
    }, loading: () {
      return const Center(child: CircularProgressIndicator());
    }, data: (int fontSize) {
      return Padding(
            padding: EdgeInsetsGeometry.only(left: size.leftIndent, top: 12, bottom: 12),
            child: CheckboxListTile(
              value: selectedFontSize == fontSize,
              onChanged: (bool? setDefault) {
                  if (setDefault != null && setDefault) {
                    ref.read(fontSizeProvider.notifier).setDefaultFontSize(selectedFontSize);
                  }
              },
              title: Text('Make this size the default (for new books)', style: Theme.of(context).textTheme.labelMedium),
            ),
          );
    });
  }
}