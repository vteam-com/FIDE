import 'dart:typed_data';
import 'dart:ui';

import 'package:fide/models/flutter_daemon_message.dart';
import 'package:fide/models/preview_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterDaemonMessage', () {
    test('parses an event', () {
      final message = FlutterDaemonMessage.parse(
        '[{"event":"app.start","params":{"appId":"abc"}}]',
      );
      expect(message?.event, 'app.start');
      expect(message?.params['appId'], 'abc');
    });

    test('parses an answer and tells a failed reload', () {
      final ok = FlutterDaemonMessage.parse(
        '[{"id":1,"result":{"code":0,"message":"Reloaded"}}]',
      )!;
      final failed = FlutterDaemonMessage.parse(
        '[{"id":2,"result":{"code":1,"message":"DevFS failed"}}]',
      )!;
      expect(ok.id, 1);
      expect(ok.succeeded, isTrue);
      expect(failed.succeeded, isFalse);
      expect(failed.resultMessage, 'DevFS failed');
    });

    test('takes plain output for no message', () {
      expect(
        FlutterDaemonMessage.parse("lib/a.dart:1:2: Error: Expected ';'"),
        isNull,
      );
      expect(FlutterDaemonMessage.parse('[{not json}]'), isNull);
    });

    test('reads the text of log events', () {
      expect(
        FlutterDaemonMessage.parse(
          '[{"event":"app.log","params":{"log":"boom"}}]',
        )?.logText,
        'boom',
      );
    });

    test('writes a request line', () {
      expect(
        FlutterDaemonMessage.request(3, 'app.stop', {'appId': 'a'}),
        '[{"id":3,"method":"app.stop","params":{"appId":"a"}}]',
      );
    });
  });

  test('PreviewFrame decodes the header and the PNG', () {
    final header = ByteData(PreviewFrame.headerBytes)
      ..setUint32(0, 2)
      ..setUint32(4, 1)
      ..setFloat32(8, 120)
      ..setFloat32(12, 40)
      ..setUint32(16, PreviewFrame.heightIsFallbackFlag);
    final frame = PreviewFrame.decode([...header.buffer.asUint8List(), 7, 8])!;
    expect(frame.generation, 2);
    expect(frame.index, 1);
    expect(frame.size, const Size(120, 40));
    expect(frame.png, [7, 8]);
    expect(frame.heightIsFallback, isTrue);
    expect(frame.widthFollowsPanel, isFalse);
    expect(frame.isSizeUndetermined, isTrue);
    expect(PreviewFrame.decode([1, 2]), isNull);
  });
}
