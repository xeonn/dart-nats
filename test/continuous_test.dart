@Timeout(Duration(seconds: 300))
import 'package:test/test.dart';
import 'package:dart_nats/dart_nats.dart';
import 'dart:isolate';

const iteration = 1000;
void run(SendPort sendPort) async {
  var client = Client();
  await client.connect(Uri.parse('ws://localhost:80'));
  for (var i = 0; i < iteration; i++) {
    client.pubString('iso', i.toString());
    //commend out for reproduce issue#4
    await Future.delayed(Duration(milliseconds: 1));
  }
  await client.ping();
  await client.close();
  sendPort.send('finish');
}

void main() {
  group('all', () {
    test('continuous', () async {
      var client = Client();
      await client.connect(Uri.parse('ws://localhost:80'));
      var sub = client.sub('iso');
      var r = 0;

      sub.stream!.listen((msg) {
        if (r % 1000 == 0) {
          // print(msg.string);
        }
        r++;
      });

      var receivePort = ReceivePort();
      var iso = await Isolate.spawn(run, receivePort.sendPort);
      var out = await receivePort.first;
      // print(out);
      expect(out, equals('finish'));
      iso.kill();
      //wait for last message send round trip to server
      await Future.delayed(Duration(seconds: 3));

      sub.close();
      await client.close();

      expect(r, equals(iteration));
    });
  });
}
