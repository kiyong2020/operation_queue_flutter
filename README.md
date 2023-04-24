<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->


## Features

An easy multi task utility that can control the number of concurrency.

## Getting started

Add the dependency in `pubspec.yaml`:

```yaml
dependencies:
  ...
  operation_queue: ^0.5.1
```


## Usage


```dart
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
```

