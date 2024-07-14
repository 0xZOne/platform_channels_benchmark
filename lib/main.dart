import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'common.dart';

String _getRandomAsciiCharacter() {
  final random = Random();
  int codeUnit = random.nextInt(95) + 32; // ASCII码 32-126 是可打印字符
  return String.fromCharCode(codeUnit);
}

String _getRandomString(int length) {
  StringBuffer buffer = StringBuffer();
  while (length > 0) {
    buffer.write(_getRandomAsciiCharacter());
    length -= 1;
  }
  return buffer.toString();
}

List<Object?> _makeTestBuffer(int itemCount, int stringLength) {
  final List<Object?> answer = <Object?>[];
  for (int i = 0; i < itemCount; ++i) {
    final List<Object?> item = <Object?>[];
    item.add(1);
    item.add(math.pow(2, 65));
    item.add(1234.0);
    item.add(null);
    item.add(<int>[1234]);
    item.add(<String, int>{'hello': 1234});
    if (stringLength > 0) {
      item.add(_getRandomString(stringLength));
    }
    item.add(true);
    item.add(Uint8List(64));
    answer.add(item);
  }
  return answer;
}

Future<double> _runBasicStandardSmall(
  BasicMessageChannel<Object?> basicStandard,
  int count,
) async {
  final Stopwatch watch = Stopwatch();
  watch.start();
  for (int i = 0; i < count; ++i) {
    await basicStandard.send(1234);
  }
  watch.stop();
  return watch.elapsedMicroseconds / count;
}

class _Counter {
  int count = 0;
}

void _runBasicStandardParallelRecurse(
  BasicMessageChannel<Object?> basicStandard,
  _Counter counter,
  int count,
  Completer<int> completer,
  Object? payload,
) {
  counter.count += 1;
  if (counter.count == count) {
    completer.complete(counter.count);
  } else if (counter.count < count) {
    basicStandard.send(payload).then((Object? result) {
      _runBasicStandardParallelRecurse(
          basicStandard, counter, count, completer, payload);
    });
  }
}

Future<double> _runBasicStandardParallel(
  BasicMessageChannel<Object?> basicStandard,
  int count,
  Object? payload,
  int parallel,
) async {
  final Stopwatch watch = Stopwatch();
  final Completer<int> completer = Completer<int>();
  final _Counter counter = _Counter();
  watch.start();
  for (int i = 0; i < parallel; ++i) {
    basicStandard.send(payload).then((Object? result) {
      _runBasicStandardParallelRecurse(
          basicStandard, counter, count, completer, payload);
    });
  }
  await completer.future;
  watch.stop();
  return watch.elapsedMicroseconds / count;
}

Future<double> _runBasicStandardLarge(
  BasicMessageChannel<Object?> basicStandard,
  List<Object?> largeBuffer,
  int count,
) async {
  int size = 0;
  final Stopwatch watch = Stopwatch();
  watch.start();
  for (int i = 0; i < count; ++i) {
    final List<Object?>? result =
        await basicStandard.send(largeBuffer) as List<Object?>?;
    // This check should be tiny compared to the actual channel send/receive.
    size += (result == null) ? 0 : result.length;
  }
  watch.stop();

  if (size != largeBuffer.length * count) {
    throw Exception(
      "There is an error with the echo channel, the results don't add up: $size",
    );
  }

  return watch.elapsedMicroseconds / count;
}

Future<double> _runBasicBinary(
  BasicMessageChannel<ByteData> basicBinary,
  ByteData buffer,
  int count,
) async {
  int size = 0;
  final Stopwatch watch = Stopwatch();
  watch.start();
  for (int i = 0; i < count; ++i) {
    final ByteData? result = await basicBinary.send(buffer);
    // This check should be tiny compared to the actual channel send/receive.
    size += (result == null) ? 0 : result.lengthInBytes;
  }
  watch.stop();
  if (size != buffer.lengthInBytes * count) {
    throw Exception(
      "There is an error with the echo channel, the results don't add up: $size",
    );
  }

  return watch.elapsedMicroseconds / count;
}

Future<void> _runTest({
  required Future<double> Function(int) test,
  required BasicMessageChannel<Object?> resetChannel,
  required BenchmarkResultPrinter printer,
  required String description,
  required String name,
  required int numMessages,
}) async {
  print('running $name');
  resetChannel.send(true);
  // Prime test.
  await test(1);
  printer.addResult(
    description: description,
    value: await test(numMessages),
    unit: 'µs',
    name: name,
  );
}

Future<String> _runTests(
    int itemCount, int stringLength, int numMessages) async {
  // if (kDebugMode) {
  //   return "Must be run in profile mode! Use 'flutter run --profile'.";
  // }

  const BasicMessageChannel<Object?> resetChannel =
      BasicMessageChannel<Object?>(
    'dev.flutter.echo.reset',
    StandardMessageCodec(),
  );
  const BasicMessageChannel<Object?> basicStandard =
      BasicMessageChannel<Object?>(
    'dev.flutter.echo.basic.standard',
    StandardMessageCodec(),
  );
  // Background platform channels aren't yet implemented for iOS.
  const BasicMessageChannel<Object?> backgroundStandard =
      BasicMessageChannel<Object?>(
    'dev.flutter.echo.background.standard',
    StandardMessageCodec(),
  );
  const BasicMessageChannel<ByteData> basicBinary =
      BasicMessageChannel<ByteData>(
    'dev.flutter.echo.basic.binary',
    BinaryCodec(),
  );

  final List<Object?> largeBuffer = _makeTestBuffer(itemCount, stringLength);
  final ByteData largeBufferBytes =
      const StandardMessageCodec().encodeMessage(largeBuffer)!;
  final ByteData oneMB = ByteData(1024 * 1024);
  print('xlog, itemCount=$itemCount, stringLength=$stringLength, numMessages=$numMessages, largeBuffer.size=${largeBuffer.length}');
  // const int numMessages = 2500;

  final BenchmarkResultPrinter printer = BenchmarkResultPrinter();
  await _runTest(
    test: (int x) => _runBasicStandardSmall(basicStandard, x),
    resetChannel: resetChannel,
    printer: printer,
    description: 'StandardMessageCodec/Small',
    name: 'platform_channel_basic_standard_2host_small',
    numMessages: numMessages,
  );
  await _runTest(
    test: (int x) => _runBasicStandardLarge(basicStandard, largeBuffer, x),
    resetChannel: resetChannel,
    printer: printer,
    description: 'StandardMessageCodec/Large(${largeBufferBytes.lengthInBytes/1024}KB)',
    name: 'platform_channel_basic_standard_2host_large',
    numMessages: numMessages,
  );
  await _runTest(
    test: (int x) => _runBasicStandardSmall(backgroundStandard, x),
    resetChannel: resetChannel,
    printer: printer,
    description: 'StandardMessageCodec/(background)/Small',
    name: 'platform_channel_basic_standard_2hostbackground_small',
    numMessages: numMessages,
  );
  await _runTest(
    test: (int x) => _runBasicStandardLarge(backgroundStandard, largeBuffer, x),
    resetChannel: resetChannel,
    printer: printer,
    description: 'StandardMessageCodec/(background)/Large',
    name: 'platform_channel_basic_standard_2hostbackground_large',
    numMessages: numMessages,
  );
  await _runTest(
    test: (int x) => _runBasicBinary(basicBinary, largeBufferBytes, x),
    resetChannel: resetChannel,
    printer: printer,
    description: 'BinaryCodec/Large',
    name: 'platform_channel_basic_binary_2host_large',
    numMessages: numMessages,
  );
  await _runTest(
    test: (int x) => _runBasicBinary(basicBinary, oneMB, x),
    resetChannel: resetChannel,
    printer: printer,
    description: 'BinaryCodec/1MB',
    name: 'platform_channel_basic_binary_2host_1MB',
    numMessages: numMessages,
  );
  await _runTest(
    test: (int x) => _runBasicStandardParallel(basicStandard, x, 1234, 3),
    resetChannel: resetChannel,
    printer: printer,
    description: 'StandardMessageCodec/SmallParallel3',
    name: 'platform_channel_basic_standard_2host_small_parallel_3',
    numMessages: numMessages,
  );
  await _runTest(
    test: (int x) =>
        _runBasicStandardParallel(basicStandard, x, largeBuffer, 3),
    resetChannel: resetChannel,
    printer: printer,
    description: 'StandardMessageCodec/LargeParallel3',
    name: 'platform_channel_basic_standard_2host_large_parallel_3',
    numMessages: numMessages,
  );
  await _runTest(
    test: (int x) => _runBasicStandardParallel(backgroundStandard, x, 1234, 3),
    resetChannel: resetChannel,
    printer: printer,
    description: 'StandardMessageCodec/background/SmallParallel3',
    name: 'platform_channel_basic_standard_2host_background_small_parallel_3',
    numMessages: numMessages,
  );
  await _runTest(
    test: (int x) =>
        _runBasicStandardParallel(backgroundStandard, x, largeBuffer, 3),
    resetChannel: resetChannel,
    printer: printer,
    description: 'StandardMessageCodec/background/LargeParallel3',
    name: 'platform_channel_basic_standard_2host_background_large_parallel_3',
    numMessages: numMessages,
  );
  printer.printToStdout();
  return printer.getStringBuffer().toString();
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String result = "Result will be shown here";

  int _stringLength = 512; // list中字符串的长度
  int _itemCounts = 100; // list对象的长度
  int _runCounts = 10; // 测试用例运行次数

  final List<int> _dropdownForStringLength = [0, 50, 100, 512, 1024, 2048, 4096, 8192, 9216, 10240];
  final List<int> _dropdownForItemCount = [1, 5, 10, 100, 500, 1500, 2000, 2500];
  final List<int> _dropdownForRunCount = [1, 10, 100, 1000, 2000];

  void _handleButtonClick() async {
    setState(() {
      result = "Benchmark运行中，请稍候～";
    });
    String newResult =
        await _runTests(_itemCounts, _stringLength, _runCounts);
    setState(() {
      result = newResult;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Platform Channel Benchmark'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                result,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              Row(
                children: [
                  const Text('运行次数'),
                  DropdownButton<int>(
                    hint: const Text('运行次数'),
                    value: _runCounts,
                    onChanged: (int? newValue) {
                      setState(() {
                        _runCounts = newValue!;
                      });
                    },
                    items: _dropdownForRunCount
                        .map<DropdownMenuItem<int>>((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                  )
                ],
              ),
              Row(
                children: [
                  const Text('Item个数：'),
                  DropdownButton<int>(
                    hint: const Text('Item个数'),
                    value: _itemCounts,
                    onChanged: (int? newValue) {
                      setState(() {
                        _itemCounts = newValue!;
                      });
                    },
                    items: _dropdownForItemCount
                        .map<DropdownMenuItem<int>>((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                  )
                ],
              ),
              Row(
                children: [
                  const Text('每个item中字符串的长度：'),
                  DropdownButton<int>(
                    hint: const Text('字符串长度'),
                    value: _stringLength,
                    onChanged: (int? newValue) {
                      setState(() {
                        _stringLength = newValue!;
                      });
                    },
                    items: _dropdownForStringLength
                        .map<DropdownMenuItem<int>>((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                  ),
                  const Text('bytes')
                ],
              ),
              ElevatedButton(
                onPressed: _handleButtonClick,
                child: const Text('Run benchmark!'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
