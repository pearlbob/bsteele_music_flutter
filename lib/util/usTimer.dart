class UsTimer {
  int get us => DateTime.now().microsecondsSinceEpoch - _initialEpochUs;

  int get delta {
    int lastUs = _lastEpochUs ?? _initialEpochUs;
    int us = DateTime.now().microsecondsSinceEpoch;
    _lastEpochUs = us;
    return us - lastUs;
  }

  String deltaToString() {
    //return Duration(microseconds: us).toString();
    return '${(delta.toDouble() / Duration.microsecondsPerMillisecond).toStringAsFixed(3)} ms';
  }

  @override
  String toString() {
    //return Duration(microseconds: us).toString();
    return '${(us.toDouble() / Duration.microsecondsPerMillisecond).toStringAsFixed(3)} ms';
  }

  final int _initialEpochUs = DateTime.now().microsecondsSinceEpoch;
  int? _lastEpochUs;
}