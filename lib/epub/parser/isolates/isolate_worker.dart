import 'dart:async';
import 'dart:collection';
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
  IsolateWorker({int? concurrency})
    : _concurrency = concurrency ?? Platform.numberOfProcessors;

  final int _concurrency;
  final List<_WorkerSlot> _slots = [];
  final Queue<_WorkerSlot> _idleSlots = Queue<_WorkerSlot>();
  final Queue<_QueuedRequest> _requestQueue = Queue<_QueuedRequest>();
  final Set<Future<void>> _inFlightRequests = <Future<void>>{};

  Future<void>? _startFuture;
  bool _isDisposed = false;

  /// Shut down all isolates. Call when the pool is no longer needed.
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    final error = StateError('IsolateWorker was disposed before queued requests could be processed.',);

    while (_requestQueue.isNotEmpty) {
      final queuedRequest = _requestQueue.removeFirst();
      if (!queuedRequest.completer.isCompleted) {
        queuedRequest.completer.completeError(error);
      }
    }

    if (_inFlightRequests.isNotEmpty) {
      await Future.wait(_inFlightRequests);
    }

    await Future.wait(_slots.map((s) => s.stop()));
    _idleSlots.clear();
    _slots.clear();
  }

  /// Enqueues one [IsolateParseRequest] and resolves when a worker completes it.
  Future<IsolateParseResponse> process(IsolateParseRequest request) async {
    if (_isDisposed) {
      throw StateError('Cannot enqueue work after IsolateWorker.dispose().');
    }

    await _ensureWorkersStarted();

    final completer = Completer<IsolateParseResponse>();
    _requestQueue.addLast(
      _QueuedRequest(request: request, completer: completer),
    );
    _drainQueue();
    return completer.future;
  }

  Future<void> _ensureWorkersStarted() async {
    if (_slots.length >= _concurrency) {
      return;
    }

    final startFuture = _startFuture;
    if (startFuture != null) {
      await startFuture;
      return;
    }

    final newStartFuture = _startWorkers();
    _startFuture = newStartFuture;

    try {
      await newStartFuture;
    } finally {
      if (identical(_startFuture, newStartFuture)) {
        _startFuture = null;
      }
    }
  }

  Future<void> _startWorkers() async {
    for (var i = _slots.length; i < _concurrency; i++) {
      final slot = _WorkerSlot();
      await slot.start();
      _slots.add(slot);
      _idleSlots.addLast(slot);
    }
  }

  void _drainQueue() {
    if (_isDisposed) {
      return;
    }

    while (_requestQueue.isNotEmpty && _idleSlots.isNotEmpty) {
      final queuedRequest = _requestQueue.removeFirst();
      final slot = _idleSlots.removeFirst();
      final future = _runQueuedRequest(slot, queuedRequest);
      _inFlightRequests.add(future);
      future.whenComplete(() => _inFlightRequests.remove(future));
    }
  }

  Future<void> _runQueuedRequest(
    _WorkerSlot slot,
    _QueuedRequest queuedRequest,
  ) async {
    try {
      final response = await slot.process(queuedRequest.request);
      if (!queuedRequest.completer.isCompleted) {
        queuedRequest.completer.complete(response);
      }
    } catch (error, stackTrace) {
      if (!queuedRequest.completer.isCompleted) {
        queuedRequest.completer.completeError(error, stackTrace);
      }
    } finally {
      if (!_isDisposed) {
        _idleSlots.addLast(slot);
        _drainQueue();
      }
    }
  }
}

class _QueuedRequest {
  const _QueuedRequest({required this.request, required this.completer});

  final IsolateParseRequest request;
  final Completer<IsolateParseResponse> completer;
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

// Runs inside the worker isolate. Must be a top-level (or static) function.
Future<IsolateParseResponse> _process(IsolateParseRequest req) async {
  try {
    return req.process();
  } catch (e, st) {
    return IsolateParseResponse(id: req.id, error: '$e\n$st');
  }
}