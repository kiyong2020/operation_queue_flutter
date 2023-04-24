import 'package:flutter_test/flutter_test.dart';

import 'package:operation_queue/operation_queue.dart';

/// 3 tasks can run concurrently.
/// Each task takes an integer as input and generates an integer as output.
var opeartionQueue = OperationQueue<int, int>(
    concurrency: 3,
    task: (data) async* {
      final startDate = DateTime.now();
      for (var i = 0; i < data; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      yield DateTime.now().difference(startDate).inMilliseconds;
    });

void _heavyWork() async {
  opeartionQueue.listen((event) {
    print('result: ${(event / 1000.0)} seconds');
  });

  for (var count in [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12]) {
    opeartionQueue.add(count);
  }
}

void main() {
  _heavyWork();
}
