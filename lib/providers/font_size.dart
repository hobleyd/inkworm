import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../database/reading_db.dart';

part 'font_size.g.dart';

@Riverpod(keepAlive: true)
class FontSize extends _$FontSize {
  @override
  Future <int> build() async {
    var readingHistory = ref.read(readingDBProvider.notifier);
    return readingHistory.getDefaultFontSize();
  }

  void setDefaultFontSize(int size) {
    var readingHistory = ref.read(readingDBProvider.notifier);
    readingHistory.setDefaultFontSize(size);

    state = AsyncValue.data(size);
  }
}