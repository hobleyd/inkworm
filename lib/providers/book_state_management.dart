import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/book_state.dart';

part 'book_state_management.g.dart';

@Riverpod(keepAlive: true)
class BookStateManagement extends _$BookStateManagement {
  @override
  BookState build() {
    return BookState(state: 0);
  }

  void clear() {
    state = BookState(state: 0);
  }

  void set(int flags) {
    state = state.set(flags);
  }
}