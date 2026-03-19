import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:get_it/get_it.dart';

import '../../structure/epub_chapter.dart';
import '../epub_parser.dart';
import 'isolate_parse_request.dart';
import 'isolate_parse_response.dart';

/// Maintains a pool of isolates — one per CPU core — and distributes
/// [IsolateParseRequest] items across them as isolates become free.
///
/// Results are returned in the **same order** as the input list.
///
/// ```dart
/// final pool = EpubParserWorker();
/// final results = await pool.parseAll(requests);
/// await pool.dispose();
/// ```
class IsolateWorker {
  IsolateWorker({int? concurrency}) : _concurrency = concurrency ?? Platform.numberOfProcessors;

  final int _concurrency;
  final List<_WorkerSlot> _slots = [];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Parse every item in [requests], returning one [EpubParseResult] per item.
  ///
  /// At most [_concurrency] isolates run simultaneously. Each isolate is
  /// reused for multiple items so spawn overhead is paid only once per core.
  Future<List<IsolateParseResponse>> parseAll(List<IsolateParseRequest> requests,) async {
    if (requests.isEmpty) return const [];

    final int workerCount = _concurrency.clamp(1, requests.length);

    // Boot isolates (or reuse already-running ones).
    if (_slots.isEmpty) {
      for (var i = 0; i < workerCount; i++) {
        final slot = _WorkerSlot();
        await slot.start();
        _slots.add(slot);
      }
    }

    // Result buffer — indexed to preserve input order.
    List<IsolateParseResponse?> results = List<IsolateParseResponse?>.filled(requests.length, null);

    // Shared queue index, advanced atomically inside the single-threaded event loop.
    int nextJob = 0;

    // Each slot runs a loop: grab the next available job until the queue is empty.
    Future<void> runSlot(_WorkerSlot slot) async {
      while (true) {
        final jobIndex = nextJob;
        if (jobIndex >= requests.length) return; // nothing left
        nextJob++; // claim this job

        results[jobIndex] = await slot.process(requests[jobIndex]);
      }
    }

    // Start all slots concurrently and wait for every job to finish.
    await Future.wait(_slots.map(runSlot));

    return results.cast<IsolateParseResponse>();
  }

  /// Shut down all isolates. Call when the pool is no longer needed.
  Future<void> dispose() async {
    await Future.wait(_slots.map((s) => s.stop()));
    _slots.clear();
  }
}

class _WorkerSlot {
  late Isolate _isolate;
  late SendPort _sendPort;
  late ReceivePort _receivePort;

  /// Spawns the isolate and waits for it to report its [SendPort].
  Future<void> start() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _receivePort.sendPort,
      debugName: 'EpubParserWorker',
    );
    // First message back is the isolate's own SendPort.
    _sendPort = await _receivePort.first as SendPort;
  }

  /// Sends one [IsolateParseRequest] and waits for the [IsolateParseResponse].
  Future<IsolateParseResponse> process(IsolateParseRequest request) async {
    final replyPort = ReceivePort();
    _sendPort.send(
      _WorkMessage(request: request, replyPort: replyPort.sendPort),
    );
    final result = await replyPort.first as IsolateParseResponse;
    replyPort.close();
    return result;
  }

  /// Terminates the isolate and cleans up ports.
  Future<void> stop() async {
    _isolate.kill(priority: Isolate.immediate);
    _receivePort.close();
  }
}

class _WorkMessage {
  const _WorkMessage({required this.request, required this.replyPort});

  final IsolateParseRequest request;
  final SendPort replyPort;
}

/// Top-level function required by [Isolate.spawn].
void _isolateEntryPoint(SendPort parentPort) {
  final inbox = ReceivePort();
  parentPort.send(inbox.sendPort);

  inbox.listen((dynamic msg) async {
    if (msg is _WorkMessage) {
      final result = await _process(msg.request);
      msg.replyPort.send(result);
    }
  });
}

// ---------------------------------------------------------------------------
// Parsing logic — replace with your real implementation
// ---------------------------------------------------------------------------

/// Runs inside the worker isolate. Must be a top-level (or static) function.
/// Replace the body with your actual EPUB parsing code.
Future<IsolateParseResponse> _process(IsolateParseRequest req) async {
  try {
    EpubParser parser = GetIt.instance.get<EpubParser>();
    EpubChapter chapter = await parser.parseChapter(req.id, req.href);
    return IsolateParseResponse(id: req.id, chapter: chapter);
  } catch (e, st) {
    return IsolateParseResponse(id: req.id, error: '$e\n$st');
  }
}

// ---------------------------------------------------------------------------
// Example usage (remove in production)
// ---------------------------------------------------------------------------

Future<void> main() async {
  final requests = List.generate(
    20,
        (i) => IsolateParseRequest(id: i, href: '/epub/book_$i.epub'),
  );

  final pool = IsolateWorker();
  print('Parsing \${requests.length} EPUBs across '
      '\${Platform.numberOfProcessors} cores...');

  final results = await pool.parseAll(requests);
  await pool.dispose();

  for (final r in results) {
    print(r);
  }
}