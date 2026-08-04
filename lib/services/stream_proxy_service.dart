class StreamProxyService {
  static final StreamProxyService instance = StreamProxyService._internal();
  StreamProxyService._internal();

  int? get port => null;

  Future<void> start() async {}
  Future<void> stop() async {}
}
