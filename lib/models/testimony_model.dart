class TestimonyModel {
  final String evidenceId;
  final String caseId;
  final String userId;
  final String type;
  final String title;
  final ArweaveData arweave;
  final BlockchainData blockchain;
  final EncryptionData encryption;
  final MetadataModel metadata;
  final AiData ai;
  final String status;
  final String createdAt;

  /// Device-only field. Only populated for locally recorded entries
  /// (evidenceId starts with 'local_'). Never sent to Firestore.
  final String? localFilePath;

  TestimonyModel({
    required this.evidenceId,
    required this.caseId,
    required this.userId,
    required this.type,
    required this.title,
    required this.arweave,
    required this.blockchain,
    required this.encryption,
    required this.metadata,
    required this.ai,
    required this.status,
    required this.createdAt,
    this.localFilePath,
  });

  TestimonyModel copyWith({
    String? evidenceId,
    String? caseId,
    String? userId,
    String? type,
    String? title,
    ArweaveData? arweave,
    BlockchainData? blockchain,
    EncryptionData? encryption,
    MetadataModel? metadata,
    AiData? ai,
    String? status,
    String? createdAt,
    String? localFilePath,
  }) {
    return TestimonyModel(
      evidenceId: evidenceId ?? this.evidenceId,
      caseId: caseId ?? this.caseId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      arweave: arweave ?? this.arweave,
      blockchain: blockchain ?? this.blockchain,
      encryption: encryption ?? this.encryption,
      metadata: metadata ?? this.metadata,
      ai: ai ?? this.ai,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }
}

class ArweaveData {
  final String txId;
  final String url;
  ArweaveData({required this.txId, required this.url});
}

class BlockchainData {
  final String fileHash;
  final String polygonTxHash;
  BlockchainData({required this.fileHash, required this.polygonTxHash});
}

class EncryptionData {
  final String keyId;
  final String status;
  final String keyHex;
  final String ivHex;

  EncryptionData({
    required this.keyId,
    required this.status,
    this.keyHex = '',
    this.ivHex = '',
  });
}

class MetadataModel {
  final String timestamp;
  final LocationData? location;
  final int? duration;
  final int size;

  MetadataModel({
    required this.timestamp,
    this.location,
    this.duration,
    required this.size,
  });
}

class LocationData {
  final double lat;
  final double lng;
  LocationData({required this.lat, required this.lng});
}

class AiData {
  final String transcript;
  final String summary;
  final String sentiment;
  final String riskLevel;
  final List<String> keywords;
  final EntitiesData entities;

  AiData({
    required this.transcript,
    required this.summary,
    required this.sentiment,
    required this.riskLevel,
    required this.keywords,
    required this.entities,
  });
}

class EntitiesData {
  final List<String> persons;
  final List<String> dates;
  final List<String> locations;
  final String? title;
  final String? description;

  EntitiesData({
    required this.persons,
    required this.dates,
    required this.locations,
    this.title,
    this.description,
  });
}
