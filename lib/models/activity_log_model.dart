enum LogEventType { mount, unmount, upload, download, delete, error, info }

class ActivityLogEntry {
  final int? id;
  final String connId;
  final String connName;
  final LogEventType eventType;
  final String message;
  final int bytes;
  final int speedBps;
  final DateTime timestamp;

  ActivityLogEntry({
    this.id,
    required this.connId,
    required this.connName,
    required this.eventType,
    required this.message,
    this.bytes = 0,
    this.speedBps = 0,
    required this.timestamp,
  });

  factory ActivityLogEntry.fromMap(Map<String, dynamic> map) {
    return ActivityLogEntry(
      id: map['id'] as int?,
      connId: map['conn_id'] as String,
      connName: map['conn_name'] as String? ?? '',
      eventType: LogEventType.values.firstWhere(
        (e) => e.name == map['event_type'],
        orElse: () => LogEventType.info,
      ),
      message: map['message'] as String? ?? '',
      bytes: map['bytes'] as int? ?? 0,
      speedBps: map['speed_bps'] as int? ?? 0,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conn_id': connId,
      'conn_name': connName,
      'event_type': eventType.name,
      'message': message,
      'bytes': bytes,
      'speed_bps': speedBps,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String get speedLabel {
    if (speedBps <= 0) return '';
    if (speedBps > 1024 * 1024) {
      return '${(speedBps / 1024 / 1024).toStringAsFixed(1)} MB/s';
    } else if (speedBps > 1024) {
      return '${(speedBps / 1024).toStringAsFixed(1)} KB/s';
    }
    return '$speedBps B/s';
  }

  String get bytesLabel {
    if (bytes <= 0) return '';
    if (bytes > 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    } else if (bytes > 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else if (bytes > 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}
