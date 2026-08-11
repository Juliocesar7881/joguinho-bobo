import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 44100;
const _durationSeconds = 0.52;
const _channelCount = 1;
const _bitsPerSample = 16;

void main(List<String> arguments) {
  final projectRoot = File.fromUri(Platform.script).parent.parent.path;
  final outputPath = arguments.isEmpty
      ? '$projectRoot${Platform.pathSeparator}android${Platform.pathSeparator}'
            'app${Platform.pathSeparator}src${Platform.pathSeparator}main'
            '${Platform.pathSeparator}res${Platform.pathSeparator}raw'
            '${Platform.pathSeparator}lexinexo_success.wav'
      : arguments.single;
  final output = File(outputPath);
  output.parent.createSync(recursive: true);

  final wavBytes = _createSuccessWav();
  output.writeAsBytesSync(wavBytes, flush: true);
  stdout.writeln('Generated ${wavBytes.length} bytes at ${output.path}');
}

Uint8List _createSuccessWav() {
  final sampleCount = (_sampleRate * _durationSeconds).round();
  final pcmByteCount = sampleCount * (_bitsPerSample ~/ 8);
  final wav = ByteData(44 + pcmByteCount);

  _writeAscii(wav, 0, 'RIFF');
  wav.setUint32(4, 36 + pcmByteCount, Endian.little);
  _writeAscii(wav, 8, 'WAVE');
  _writeAscii(wav, 12, 'fmt ');
  wav.setUint32(16, 16, Endian.little);
  wav.setUint16(20, 1, Endian.little);
  wav.setUint16(22, _channelCount, Endian.little);
  wav.setUint32(24, _sampleRate, Endian.little);
  wav.setUint32(
    28,
    _sampleRate * _channelCount * (_bitsPerSample ~/ 8),
    Endian.little,
  );
  wav.setUint16(32, _channelCount * (_bitsPerSample ~/ 8), Endian.little);
  wav.setUint16(34, _bitsPerSample, Endian.little);
  _writeAscii(wav, 36, 'data');
  wav.setUint32(40, pcmByteCount, Endian.little);

  for (var index = 0; index < sampleCount; index++) {
    final time = index / _sampleRate;
    final mixed =
        _tone(time, start: 0, duration: 0.30, frequency: 523.251, gain: 0.17) +
        _tone(
          time,
          start: 0.115,
          duration: 0.405,
          frequency: 659.255,
          gain: 0.20,
        ) +
        _tone(
          time,
          start: 0.235,
          duration: 0.285,
          frequency: 783.991,
          gain: 0.11,
        );
    final limited = mixed.clamp(-0.42, 0.42);
    wav.setInt16(44 + index * 2, (limited * 32767).round(), Endian.little);
  }

  return wav.buffer.asUint8List();
}

double _tone(
  double time, {
  required double start,
  required double duration,
  required double frequency,
  required double gain,
}) {
  final localTime = time - start;
  if (localTime < 0 || localTime >= duration) {
    return 0;
  }

  const attackSeconds = 0.018;
  const releaseSeconds = 0.13;
  final attackProgress = (localTime / attackSeconds).clamp(0.0, 1.0);
  final releaseProgress = ((duration - localTime) / releaseSeconds).clamp(
    0.0,
    1.0,
  );
  final attack = (1 - math.cos(math.pi * attackProgress)) / 2;
  final release = (1 - math.cos(math.pi * releaseProgress)) / 2;
  final envelope = attack * release;
  final phase = 2 * math.pi * frequency * localTime;
  final wave = math.sin(phase) + 0.08 * math.sin(phase * 2 + 0.35);
  return wave * envelope * gain;
}

void _writeAscii(ByteData target, int offset, String value) {
  for (var index = 0; index < value.length; index++) {
    target.setUint8(offset + index, value.codeUnitAt(index));
  }
}
