import 'dart:async';

import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:denden/media/cloudflare_media.dart';
import 'package:denden/rooms/worker_api.dart';
import 'package:denden/ui/capture_control.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class FakeStream extends Fake implements MediaStream {
  @override
  List<MediaStreamTrack> getTracks() => const [];
}

class FakeBroadcast implements BroadcastHandle {
  FakeBroadcast(this.roomCode);
  @override
  final String roomCode;
  final statesCtl = StreamController<LinkState>.broadcast(sync: true);
  final repliesCtl = StreamController<ReportReply>.broadcast(sync: true);
  bool stopped = false;
  @override
  LinkState state = LinkState.live;
  @override
  Stream<LinkState> get states => statesCtl.stream;
  @override
  Stream<ReportReply> get replies => repliesCtl.stream;
  @override
  Future<void> stop() async => stopped = true;
}

class FakeViewing implements ViewingHandle {
  final statesCtl = StreamController<LinkState>.broadcast(sync: true);
  @override
  LinkState state = LinkState.live;
  @override
  Stream<LinkState> get states => statesCtl.stream;
  @override
  Future<void> leave() async {}
}

class FakeMedia implements MediaPort {
  Object? publishError;
  Object? watchError;
  final broadcast = FakeBroadcast('K7P92Q');
  final viewing = FakeViewing();
  QualityProfile? publishedProfile;

  @override
  Future<BroadcastHandle> publish(
    MediaStream stream,
    QualityProfile profile, {
    int? sourceWidth,
    int? sourceHeight,
  }) async {
    if (publishError != null) throw publishError!;
    publishedProfile = profile;
    return broadcast;
  }

  @override
  Future<ViewingHandle> watch(String code, RTCVideoRenderer renderer) async {
    if (watchError != null) throw watchError!;
    return viewing;
  }
}

class FakeCapture implements CaptureControl {
  final errorsCtl = StreamController<CaptureError>.broadcast(sync: true);
  AudioChoice? lastAudio;
  bool stopped = false;

  @override
  Future<List<CaptureSource>> listSources() async => const [
    CaptureSource(id: '0', name: 'Tela 1', isWindow: false),
    CaptureSource(id: '7', name: 'DenDen', isWindow: true),
    CaptureSource(id: '42', name: 'Jogo', isWindow: true),
  ];

  @override
  Future<MediaStream> start(
    CaptureSource screen,
    AudioChoice audio,
    QualityProfile p,
  ) async {
    lastAudio = audio;
    return FakeStream();
  }

  @override
  Future<void> stop() async => stopped = true;

  @override
  Stream<CaptureError> get errors => errorsCtl.stream;
}
