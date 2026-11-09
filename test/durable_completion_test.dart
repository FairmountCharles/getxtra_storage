import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getxtra/utils.dart' show GetQueue;
import 'package:getxtra_storage/getxtra_storage.dart';

class _HeldQueue extends GetQueue {
  final firstStarted = Completer<void>();
  final secondQueued = Completer<void>();
  final release = Completer<void>();
  int queued = 0;
  int started = 0;

  @override
  Future<T> add<T>(Function job) {
    queued++;
    if (queued == 2) secondQueued.complete();
    return super.add<T>(() async {
      started++;
      if (started == 1) {
        firstStarted.complete();
        await release.future;
      }
      return await job() as T;
    });
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  var sequence = 0;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('storage-completion-');
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
  });
  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });
  Future<GetStorage> createBox() async {
    final box = GetStorage('completion-${sequence++}', directory.path);
    await box.initStorage;
    return box;
  }

  File primary(GetStorage box) =>
      File('${directory.path}/completion-${sequence - 1}.gs');
  File backup(GetStorage box) =>
      File('${directory.path}/completion-${sequence - 1}.bak');

  test(
      'coalesced and later writes complete after serialized primary and backup persistence',
      () async {
    final box = await createBox();
    final queue = _HeldQueue();
    box.queue = queue;
    var completed = false;
    final first = box.write('first', 'one');
    unawaited(first.then((_) {
      completed = true;
    }));
    final coalesced = box.write('second', 'two');
    await queue.firstStarted.future;
    expect(completed, isFalse);
    expect(queue.queued, 1);
    final later = box.write('third', 'three');
    await queue.secondQueued.future;
    expect(queue.started, 1);
    expect(completed, isFalse);
    queue.release.complete();
    await Future.wait([first, coalesced, later]);
    expect(queue.queued, 2);
    expect(queue.started, 2);
    expect(jsonDecode(primary(box).readAsStringSync()),
        {'first': 'one', 'second': 'two', 'third': 'three'});
    expect(backup(box).readAsBytesSync(), primary(box).readAsBytesSync());
  });

  test(
      'queued serialization Error reaches write and leaves later valid writes drainable',
      () async {
    final box = await createBox();
    final before = primary(box).readAsBytesSync();
    await expectLater(
        box.write('value', Object()).timeout(const Duration(seconds: 3)),
        throwsA(isA<JsonUnsupportedObjectError>()));
    expect(primary(box).readAsBytesSync(), before);
    expect(backup(box).readAsBytesSync(), before);
    await box.write('value', 'recovered').timeout(const Duration(seconds: 5));
    expect(jsonDecode(primary(box).readAsStringSync()), {'value': 'recovered'});
    expect(backup(box).readAsBytesSync(), primary(box).readAsBytesSync());
  });
}
