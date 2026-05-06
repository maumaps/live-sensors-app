enum SnapshotErrorType { network, backend, data, unknown }

class SnapshotError {
  final String message;
  late SnapshotErrorType type;
  late bool temporary;

  SnapshotError(this.type, this.message, this.temporary);

  SnapshotError.network(this.message, this.temporary) {
    type = SnapshotErrorType.network;
    temporary = true;
  }

  SnapshotError.backend(this.message, this.temporary) {
    type = SnapshotErrorType.backend;
  }

  SnapshotError.data(this.message) {
    type = SnapshotErrorType.data;
    temporary = false;
  }

  SnapshotError.unknown(this.message) {
    type = SnapshotErrorType.unknown;
    temporary = false;
  }

  factory SnapshotError.fromMap(Map<String, dynamic> json) {
    return SnapshotError(
      _typeFromJson(json['type']),
      json['message'] as String,
      json['temporary'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'message': message,
        'temporary': temporary,
      };
}

SnapshotErrorType _typeFromJson(dynamic value) {
  if (value is SnapshotErrorType) {
    return value;
  }
  return SnapshotErrorType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => SnapshotErrorType.unknown,
  );
}
