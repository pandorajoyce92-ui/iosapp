import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局音效播放器（单例）
class SoundPlayer {
  SoundPlayer._internal();
  static final SoundPlayer instance = SoundPlayer._internal();

  AudioPlayer? _player;
  bool _soundOn = true;
  bool _inited = false;

  /// App 启动时调用一次
  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.stop);
      final sp = await SharedPreferences.getInstance();
      final v = sp.getString('lastname');
      // 与设置页一致：没设置过默认为开启
      _soundOn = (v == null) ? true : (v == '1');
      debugPrint('🔊 SoundPlayer 初始化完成，开关=$_soundOn');
      _initMsgPlayer();
    } catch (e) {
      debugPrint('❌ SoundPlayer.init: $e');
    }
  }

  bool get isOn => _soundOn;

  /// 抢包成功
  Future<void> playGrabSuccess() => _play('music/jinbi.mp3');

  /// 中雷
  Future<void> playBoom() => _play('music/zhonglei2.mp3');

  Future<void> _play(String asset) async {
    if (!_soundOn) {
      debugPrint('🔇 音效已关闭，跳过 $asset');
      return;
    }
    try {
      if (_player == null) {
        _player = AudioPlayer();
        await _player!.setReleaseMode(ReleaseMode.stop);
      }
      await _player!.stop();
      debugPrint('🔊 播放: $asset');
      await _player!.play(AssetSource(asset));
    } catch (e) {
      debugPrint('❌ 播放 $asset 失败: $e');
    }
  }

    // ================= 新消息提示音（低延迟） =================
    AudioPlayer? _msgPlayer;
    bool _msgReady = false;

    Future<void> _initMsgPlayer() async {
      try {
        _msgPlayer = AudioPlayer(playerId: 'msg_player');
        await _msgPlayer!.setPlayerMode(PlayerMode.lowLatency);
        await _msgPlayer!.setReleaseMode(ReleaseMode.stop);
        await _msgPlayer!.setSource(AssetSource('music/msg.mp3'));
        _msgReady = true;
        debugPrint('🔔 消息提示音预加载完成');
      } catch (e) {
        debugPrint('❌ 消息提示音初始化失败: $e');
      }
    }

    /// 新消息提示音
    Future<void> playMessage() async {
      if (!_soundOn) return;
      try {
        if (!_msgReady) await _initMsgPlayer();
        await _msgPlayer?.stop();
        await _msgPlayer?.resume();
      } catch (e) {
        debugPrint('❌ 播放消息提示音失败: $e');
      }
    }

    Future<void> dispose() async {
      await _player?.dispose();
      await _msgPlayer?.dispose();
      _player = null;
      _msgPlayer = null;
    }
}