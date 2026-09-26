import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const MethodChannel _platformChannel = MethodChannel('com.velix.local/platform');

  /// Dispara notificação de arquivo recebido com som e vibração
  Future<void> notifyFileReceived({
    required String fileName,
    required String senderDevice,
    String? filePath,
  }) async {
    final title = 'Arquivo Recebido! 🎉';
    final message = '$fileName recebido de $senderDevice';

    try {
      // 1. Feedback tátil
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}

      // 2. Notificação e som no Android
      if (!kIsWeb && Platform.isAndroid) {
        await _platformChannel.invokeMethod('showTransferNotification', {
          'title': title,
          'message': message,
          'filePath': filePath,
        });
        return;
      }

      // 3. Notificação e som no Linux
      if (!kIsWeb && Platform.isLinux) {
        // Notificação de desktop nativa via notify-send
        try {
          await Process.run('notify-send', [
            '-a',
            'Velix Local',
            '-i',
            'document-save',
            title,
            message,
          ]);
        } catch (_) {}

        // Som de sistema no Linux (Fedora/Ubuntu/GNOME)
        try {
          await Process.run('paplay', ['/usr/share/sounds/freedesktop/stereo/complete.oga']);
        } catch (_) {
          try {
            await Process.run('canberra-gtk-play', ['-i', 'complete']);
          } catch (_) {
            SystemSound.play(SystemSoundType.click);
          }
        }
        return;
      }

      // 4. Notificação e som no Windows
      if (!kIsWeb && Platform.isWindows) {
        try {
          await Process.run('powershell', [
            '-c',
            '[System.Media.SystemSounds]::Asterisk.Play()',
          ]);
        } catch (_) {
          SystemSound.play(SystemSoundType.click);
        }
        return;
      }

      // Fallback padrão do Flutter
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('[NotificationService] Erro ao emitir notificação/som: $e');
    }
  }

  /// Toca apenas o som/chime de alerta
  Future<void> playChime() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _platformChannel.invokeMethod('playNotificationSound');
      } else if (!kIsWeb && Platform.isLinux) {
        try {
          await Process.run('paplay', ['/usr/share/sounds/freedesktop/stereo/complete.oga']);
        } catch (_) {
          await SystemSound.play(SystemSoundType.click);
        }
      } else {
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {}
  }
}
