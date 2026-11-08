import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A wrapper that implements [Socket] on top of a raw [SecureSocket],
/// handling WebSocket framing and parsing manually.
class WebSocketSocket extends Stream<Uint8List> implements Socket {
  final Socket _rawSocket;
  final StreamController<Uint8List> _controller = StreamController<Uint8List>();
  final _parser = WebSocketFrameParser();

  WebSocketSocket(this._rawSocket, {List<int>? trailingBytes}) {
    if (trailingBytes != null && trailingBytes.isNotEmpty) {
      _parser.addBytes(trailingBytes, (payload) {
        _controller.add(payload);
      });
    }

    _rawSocket.listen(
      (data) {
        _parser.addBytes(data, (payload) {
          _controller.add(payload);
        });
      },
      onDone: () => _controller.close(),
      onError: (err) => _controller.addError(err),
      cancelOnError: true,
    );
  }

  @override
  InternetAddress get address => _rawSocket.address;

  @override
  int get port => _rawSocket.port;

  @override
  InternetAddress get remoteAddress => _rawSocket.remoteAddress;

  @override
  int get remotePort => _rawSocket.remotePort;

  @override
  void add(List<int> data) {
    final List<int> frame = [];
    frame.add(0x82); // FIN + Binary frame
    final len = data.length;
    if (len < 126) {
      frame.add(0x80 | len);
    } else if (len <= 65535) {
      frame.add(0x80 | 126);
      frame.add((len >> 8) & 0xFF);
      frame.add(len & 0xFF);
    } else {
      frame.add(0x80 | 127);
      for (int i = 7; i >= 0; i--) {
        frame.add((len >> (i * 8)) & 0xFF);
      }
    }
    final mask = [0x12, 0x34, 0x56, 0x78]; // simple constant mask
    frame.addAll(mask);
    for (int i = 0; i < len; i++) {
      frame.add(data[i] ^ mask[i % 4]);
    }
    try {
      _rawSocket.add(frame);
    } catch (_) {}
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _controller.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> close() async {
    await _rawSocket.close();
    await _controller.close();
  }

  @override
  void destroy() {
    _rawSocket.destroy();
    _controller.close();
  }

  @override
  Future<void> get done => _rawSocket.done;

  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding enc) {}

  @override
  void write(Object? obj) {
    if (obj != null) {
      add(obj.toString().codeUnits);
    }
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    for (final obj in objects) {
      write(obj);
      if (separator.isNotEmpty) write(separator);
    }
  }

  @override
  void writeCharCode(int charCode) {
    add([charCode]);
  }

  @override
  void writeln([Object? obj = ""]) {
    write(obj);
    write("\n");
  }

  @override
  Future<void> flush() => _rawSocket.flush();

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  bool setOption(SocketOption option, bool enabled) => _rawSocket.setOption(option, enabled);

  @override
  Uint8List getRawOption(RawSocketOption option) => _rawSocket.getRawOption(option);

  @override
  void setRawOption(RawSocketOption option) => _rawSocket.setRawOption(option);
}

class WebSocketFrameParser {
  final List<int> _buffer = [];

  void addBytes(List<int> bytes, void Function(Uint8List payload) onPayload) {
    _buffer.addAll(bytes);

    while (true) {
      if (_buffer.length < 2) return;
      final firstByte = _buffer[0];
      final secondByte = _buffer[1];

      final opcode = firstByte & 0x0F;
      final hasMask = (secondByte & 0x80) != 0;
      int payloadLen = secondByte & 0x7F;

      int headerSize = 2;
      if (payloadLen == 126) {
        if (_buffer.length < 4) return;
        payloadLen = ByteData.sublistView(Uint8List.fromList(_buffer), 2, 4).getUint16(0);
        headerSize = 4;
      } else if (payloadLen == 127) {
        if (_buffer.length < 10) return;
        payloadLen = ByteData.sublistView(Uint8List.fromList(_buffer), 2, 10).getUint64(0);
        headerSize = 10;
      }

      List<int> maskKey = [];
      if (hasMask) {
        if (_buffer.length < headerSize + 4) return;
        maskKey = _buffer.sublist(headerSize, headerSize + 4);
        headerSize += 4;
      }

      if (_buffer.length < headerSize + payloadLen) return;

      final rawPayload = _buffer.sublist(headerSize, headerSize + payloadLen);
      _buffer.removeRange(0, headerSize + payloadLen);

      Uint8List finalPayload;
      if (hasMask) {
        finalPayload = Uint8List(payloadLen);
        for (int i = 0; i < payloadLen; i++) {
          finalPayload[i] = rawPayload[i] ^ maskKey[i % 4];
        }
      } else {
        finalPayload = Uint8List.fromList(rawPayload);
      }

      if (opcode == 0x01 || opcode == 0x02) {
        onPayload(finalPayload);
      } else if (opcode == 0x08) {
        break; // Close frame
      }
    }
  }
}
