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
  });
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
  EncryptionData({required this.keyId, required this.status});
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
  final EntitiesData entities;

  AiData({
    required this.transcript,
    required this.summary,
    required this.entities,
  });
}

class EntitiesData {
  final List<String> persons;
  final List<String> dates;
  final List<String> locations;

  EntitiesData({
    required this.persons,
    required this.dates,
    required this.locations,
  });
}
