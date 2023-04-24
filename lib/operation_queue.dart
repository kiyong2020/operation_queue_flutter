import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:math';

import 'package:async/async.dart';
import 'package:rxdart/streams.dart';
import 'package:rxdart/subjects.dart';

/*
Example:
  var opeartionQueue = OperationQueue<int, int>(
      concurrency: 3,
      task: (data) async* {
        final startDate = DateTime.now();
        final random = Random();
        for (var i = 0; i < data; i++) {
          await Future.delayed(const Duration(microseconds: 10));
        }
        yield DateTime.now().difference(startDate).inMilliseconds;
      });

  void _heavyWork() async {

    opeartionQueue.listen((event) {
      print('result: ${(event / 1000.0)} seconds');
    });

    for (var count in [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12]) {
      opeartionQueue.sendMessage(count);
    }
  }
*/
abstract class OperationQueueInterface<I, O> extends Stream<O> {
  // Future prepare();

  add(I data);

  kill({int priority = Isolate.beforeNextEvent});
}

class OperationQueue<I, O> extends OperationQueueInterface<I, O> {
  final int concurrency;

  //final Stream<O> Function(I) task;

  final _taskWrapper = _OperationQueueTaskWrapper<I, O>();

  final _isolates = <Isolate>[];
  final _controlPorts = <StreamQueue>[];
  final _resultPorts = <ReceivePort>[];
  final _resultRelay = PublishSubject<O>();
  final _requestQueue = <I>[];

  var _creatingCount = 0;

  OperationQueue({
    required Stream<O> Function(I) task,
    this.concurrency = 1,
  }) {
    _taskWrapper.task = task;
    assert(concurrency >= 1, 'Concurrency must be 1 or more.');
  }

  final _random = Random(DateTime.now().millisecond);

  Future<int> _getNextPort() async {
    while (concurrency > _controlPorts.length) {
      final idx = await _createPort();
      if (idx != null) {
        return idx;
      }
    }

    for (var i = 0; i < _controlPorts.length; i++) {
      final port = _controlPorts[i];
      if (!(await port.hasNext)) {
        return i;
      } else {
        //print('$i is not empty');
      }
    }

    //print('no empty port found');
    return _random.nextInt(_controlPorts.length);
  }

  Future<int?> _createPort() async {
    if (_creatingCount + _isolates.length >= concurrency) {
      await Future.delayed(Duration(milliseconds: _random.nextInt(10)));
      return null;
    }

    _creatingCount += 1;

    final receivePort = ReceivePort();

    final isolate = await Isolate.spawn<SendPort>(
        _taskWrapper.entryPoint, receivePort.sendPort);
    _isolates.add(isolate);
    _controlPorts.add(StreamQueue(receivePort));
    final resultPort = ReceivePort();
    _resultPorts.add(resultPort);

    resultPort.listen((message) {
      _resultRelay.add(message);
    });

    _creatingCount -= 1;

    return _isolates.length - 1;
  }

  /// Sends a message with data to isolate.
  ///
  @override
  add(I data) async {
    _requestQueue.add(data);
    final index = await _getNextPort();
    final nextData = _requestQueue.removeAt(0);
    final resultSendPort = _resultPorts[index].sendPort;
    _controlPorts[index].next.then((sendPort) {
      sendPort?.send(_OperationQueueMessage<I, O>(nextData, resultSendPort));
    });
  }

  /// Requests all isolates to shut down.
  @override
  kill({int priority = Isolate.beforeNextEvent}) {
    for (var e in _isolates) {
      e.kill(priority: priority);
    }
  }

  @override
  StreamSubscription<O> listen(void Function(O event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _resultRelay.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

class _OperationQueueMessage<I, O> {
  _OperationQueueMessage(this.data, this.resultPort);
  I data;
  SendPort resultPort;
}

class _OperationQueueTaskWrapper<I, O> {
  late Stream<O> Function(I) task;

  void entryPoint(SendPort controlPort) {
    final receivePort = ReceivePort();
    controlPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is _OperationQueueMessage<I, O>) {
        await for (final x in this.task(message.data)) {
          message.resultPort.send(x);
        }
        // print('thread:${controlPort.hashCode} task:${message.data}');
      }

      controlPort.send(receivePort.sendPort);
    });
  }
}
