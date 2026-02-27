import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_state_management.g.dart';

@Riverpod(keepAlive: true)
class BookStateManagement extends _$BookStateManagement {
  // State flags as bit masks
  static const int created     = 1 << 0; // 0000 0001
  static const int initialised = 1 << 1; // 0000 0010
  static const int sized       = 1 << 2; // 0000 0100
  static const int progress    = 1 << 3; // 0000 1000
  static const int parsing     = 1 << 4; // 0001 0000
  static const int complete    = 1 << 5; // 0010 0000

  @override
  int build () {
    return 0;
  }

  // ── Core operations ──────────────────────────────────────────

  /// Set one or more states
  void set(int flags) => state |= flags;

  /// Clear one or more states
  void clear(int flags) => state &= ~flags;

  /// Toggle one or more states
  void toggle(int flags) => state ^= flags;

  /// Replace all state at once
  void reset([int flags = 0]) => state = flags;

  // ── Queries ───────────────────────────────────────────────────

  /// Returns true if ALL of the given flags are set
  bool hasAll(int flags) => (state & flags) == flags;

  /// Returns true if ANY of the given flags are set
  bool hasAny(int flags) => (state & flags) != 0;

  /// Returns true if NONE of the given flags are set
  bool hasNone(int flags) => (state & flags) == 0;

  // ── Named convenience getters ─────────────────────────────────

  bool get isCreated     => hasAll(created);
  bool get isInitialised => hasAll(initialised);
  bool get isSized       => hasAll(sized);
  bool get inProgress    => hasAll(progress);
  bool get isParsing     => hasAll(parsing);
  bool get isComplete    => hasAll(complete);

  // ── Debug ─────────────────────────────────────────────────────

  @override
  String toString() {
    final active = {
      'created':     created,
      'initialised': initialised,
      'sized':       sized,
      'progress':    progress,
      'parsing':     parsing,
      'complete':    complete,
    }.entries
        .where((e) => hasAll(e.value))
        .map((e) => e.key)
        .toList();

    return 'Book State: (0b${state.toRadixString(2).padLeft(6, '0')}'
        ' | ${active.isEmpty ? 'none' : active.join(', ')})';
  }
}