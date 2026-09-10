import 'dart:convert';

enum ConnectionType {
  gdrive,
  dropbox,
  onedrive,
  mega,
  box,
  pcloud,
  koofr,
  azureblob,
  mediafire,
  putio,
  s3,
  ftp,
  sftp,
  webdav,
  b2;

  String get displayName => switch (this) {
        gdrive => 'Google Drive',
        dropbox => 'Dropbox',
        onedrive => 'OneDrive',
        mega => 'Mega',
        box => 'Box',
        pcloud => 'pCloud',
        koofr => 'Koofr',
        azureblob => 'Azure Blob',
        mediafire => 'MediaFire',
        putio => 'Put.io',
        s3 => 'Amazon S3',
        ftp => 'FTP',
        sftp => 'SFTP',
        webdav => 'WebDAV',
        b2 => 'Backblaze B2',
      };

  String get rcloneType => switch (this) {
        gdrive => 'drive',
        dropbox => 'dropbox',
        onedrive => 'onedrive',
        mega => 'mega',
        box => 'box',
        pcloud => 'pcloud',
        koofr => 'koofr',
        azureblob => 'azureblob',
        mediafire => 'mediafire',
        putio => 'putio',
        s3 => 's3',
        ftp => 'ftp',
        sftp => 'sftp',
        webdav => 'webdav',
        b2 => 'b2',
      };

  bool get isOAuth => [gdrive, dropbox, onedrive, box].contains(this);
}

class ConnectionModel {
  final String id;
  final String name;
  final ConnectionType type;
  final Map<String, dynamic> config;
  final bool autoMount;
  final bool isEncrypted;
  final String? mountPoint;
  final DateTime createdAt;
  final DateTime? lastMounted;
  bool isMounted;
  bool isMounting;
  String? mountError;

  ConnectionModel({
    required this.id,
    required this.name,
    required this.type,
    required this.config,
    this.autoMount = false,
    this.isEncrypted = false,
    this.mountPoint,
    required this.createdAt,
    this.lastMounted,
    this.isMounted = false,
    this.isMounting = false,
    this.mountError,
  });

  factory ConnectionModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> decodedConfig;
    try {
      final decoded = jsonDecode(map['config_json'] as String? ?? '{}');
      if (decoded is Map<String, dynamic>) {
        decodedConfig = decoded;
      } else {
        decodedConfig = <String, dynamic>{};
      }
    } catch (_) {
      decodedConfig = <String, dynamic>{};
    }

    return ConnectionModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: ConnectionType.values.firstWhere(
        (e) => e.name == map['conn_type'],
        orElse: () => ConnectionType.ftp,
      ),
      config: decodedConfig,
      autoMount: (map['auto_mount'] as int? ?? 0) == 1,
      isEncrypted: (map['is_encrypted'] as int? ?? 0) == 1,
      mountPoint: map['mount_point'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastMounted: map['last_mounted'] != null
          ? DateTime.parse(map['last_mounted'] as String)
          : null,
      isMounted: map['mount_point'] != null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'conn_type': type.name,
      'config_json': jsonEncode(config),
      'auto_mount': autoMount ? 1 : 0,
      'is_encrypted': isEncrypted ? 1 : 0,
      'mount_point': mountPoint,
      'created_at': createdAt.toIso8601String(),
      'last_mounted': lastMounted?.toIso8601String(),
    };
  }

  ConnectionModel copyWith({
    String? name,
    Map<String, dynamic>? config,
    bool? autoMount,
    bool? isEncrypted,
    String? mountPoint,
    DateTime? lastMounted,
    bool? isMounted,
    bool? isMounting,
    String? mountError,
    bool clearMountError = false,
    bool clearMountPoint = false,
  }) {
    return ConnectionModel(
      id: id,
      name: name ?? this.name,
      type: type,
      config: config ?? this.config,
      autoMount: autoMount ?? this.autoMount,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      mountPoint: clearMountPoint ? null : mountPoint ?? this.mountPoint,
      createdAt: createdAt,
      lastMounted: lastMounted ?? this.lastMounted,
      isMounted: isMounted ?? this.isMounted,
      isMounting: isMounting ?? this.isMounting,
      mountError: clearMountError ? null : mountError ?? this.mountError,
    );
  }
}
