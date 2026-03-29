import '../models/testimony_model.dart';

// mirrors users/{uid}
const mockUserUid = 'HTmXDXskK9ujFOkE5Bp7';
const mockCaseId = 'fLMuIh9ijCmHpsn9jB2g';

final mockUser = {
  'uid': mockUserUid,
  'phone': '+919900000999',
  'role': 'survivor',
  'profile': {
    'name': 'Priya Sharma',
    'location': {
      'district': 'Bengaluru Urban',
      'state': 'Karnataka',
    },
  },
  'settings': {
    'anonymityMode': false,
    'biometricEnabled': false,
    'locationConsent': true,
  },
  'createdAt': '2026-03-26T12:16:49Z',
};

// mirrors cases/{caseId}
final mockCase = {
  'caseId': mockCaseId,
  'assignedOfficerId': mockUserUid,
  'description': 'User reported repeated harassment while commuting home.',
  'location': {
    'district': 'Bengaluru Urban',
    'state': 'Karnataka',
  },
  'priority': 'high',
  'status': 'open',
  'timestamps': {
    'closedAt': null,
    'createdAt': '2026-03-26T12:16:49Z',
    'updatedAt': '2026-03-26T12:16:49Z',
  },
  'title': 'Harassment incident near transit hub',
  'userId': mockUserUid,
};

// mirrors evidence/{evidenceId} — 4 entries
final List<TestimonyModel> mockTestimonies = [
  TestimonyModel(
    evidenceId: 'evidence_001',
    caseId: mockCaseId,
    userId: mockUserUid,
    type: 'video',
    title: 'First account — March incident',
    arweave: ArweaveData(
      txId: 'Xk9mP2nQ7rL4wA8vB3cD6eF1gH5iJ0kM2nP9qR7sT',
      url: 'https://arweave.net/Xk9mP2nQ7rL4wA8vB3cD6eF1gH5iJ0kM2nP9qR7sT',
    ),
    blockchain: BlockchainData(
      fileHash:
          'sha256_a3f8c2d1e4b7690f2a1c8e5d3b6f9a2c4e7d1b8f3a6c9e2d5b8f1a4c7e0d3b6',
      polygonTxHash:
          '0x4a8f2c1d9e3b7a6f5c2d8e1b4a7f3c9e6d2b5a8f1c4e7d0b3a6f9c2e5d8b1a4',
    ),
    encryption: EncryptionData(keyId: 'key_001', status: 'active'),
    metadata: MetadataModel(
      timestamp: '2026-03-15T14:32:00Z',
      location: LocationData(lat: 12.9716, lng: 77.5946),
      duration: 185,
      size: 104857600,
    ),
    ai: AiData(
      transcript: '',
      summary:
          'The survivor described repeated harassment incidents while commuting home from work near the transit hub in Bengaluru Urban. She mentioned specific threats made on March 15th and referenced two prior incidents in February. The account was given calmly and with precise detail.',
      entities: EntitiesData(
        persons: ['unknown male', 'autorickshaw driver'],
        dates: ['March 15', 'February 2026'],
        locations: ['transit hub', 'commute route'],
      ),
    ),
    status: 'certified',
    createdAt: '2026-03-15T14:45:00Z',
  ),
  TestimonyModel(
    evidenceId: 'evidence_002',
    caseId: mockCaseId,
    userId: mockUserUid,
    type: 'video',
    title: 'Second account — follow up',
    arweave: ArweaveData(
      txId: 'Lm3nO5pQ8rS1tU4vW7xY0zA2bC6dE9fG3hI7jK1lM',
      url: 'https://arweave.net/Lm3nO5pQ8rS1tU4vW7xY0zA2bC6dE9fG3hI7jK1lM',
    ),
    blockchain: BlockchainData(
      fileHash:
          'sha256_b4g9d3e2f5c8a1b7e4d0c6f3a9b2e5d8c1f4a7b0e3d6c9f2a5b8e1d4c7f0a3b6',
      polygonTxHash:
          '0x5b9g3d2e8c4f1a7b5e2d9c6f3a0b7e4d1c8f5a2b9e6d3c0f7a4b1e8d5c2f9a6b3',
    ),
    encryption: EncryptionData(keyId: 'key_001', status: 'active'),
    metadata: MetadataModel(
      timestamp: '2026-03-18T09:15:00Z',
      location: LocationData(lat: 12.9716, lng: 77.5946),
      duration: 312,
      size: 157286400,
    ),
    ai: AiData(
      transcript: '',
      summary:
          'Survivor provided a follow-up account describing two additional incidents that occurred after the first testimony. She described being followed from the transit hub to her street on the evening of March 17th and mentioned a witness who was present.',
      entities: EntitiesData(
        persons: ['unknown male', 'neighbour Mrs. Rao'],
        dates: ['March 17', 'March 18'],
        locations: ['transit hub', 'residential street'],
      ),
    ),
    status: 'anchored',
    createdAt: '2026-03-18T09:30:00Z',
  ),
  TestimonyModel(
    evidenceId: 'evidence_003',
    caseId: mockCaseId,
    userId: mockUserUid,
    type: 'image',
    title: 'Medical certificate — City Hospital',
    arweave: ArweaveData(
      txId: 'Rp4qS6tU9vW2xY5zA8bC1dE4fG7hI0jK3lM6nO9pQ',
      url: 'https://arweave.net/Rp4qS6tU9vW2xY5zA8bC1dE4fG7hI0jK3lM6nO9pQ',
    ),
    blockchain: BlockchainData(
      fileHash:
          'sha256_c5h0e4f3g6d9b2c8f5e1d7c4g1b8e5d2c9f6a3b0e7d4c1g8b5e2d9c6f3a0b7e4',
      polygonTxHash:
          '0x6c0h4e3f9d5g2b8c6f3e0d7c4g1b8e5d2c9f6a3b0e7d4c1g8b5e2d9c6f3a0b7e4',
    ),
    encryption: EncryptionData(keyId: 'key_001', status: 'active'),
    metadata: MetadataModel(
      timestamp: '2026-03-19T11:00:00Z',
      location: null,
      duration: null,
      size: 2048000,
    ),
    ai: AiData(
      transcript: '',
      summary:
          'Uploaded medical document from City Hospital Bengaluru dated March 19th noting anxiety and stress-related symptoms consistent with repeated harassment exposure. Doctor recommended follow-up counselling.',
      entities: EntitiesData(
        persons: ['Dr. Suresh'],
        dates: ['March 19'],
        locations: ['City Hospital Bengaluru'],
      ),
    ),
    status: 'anchored',
    createdAt: '2026-03-19T11:10:00Z',
  ),
  TestimonyModel(
    evidenceId: 'evidence_004',
    caseId: mockCaseId,
    userId: mockUserUid,
    type: 'video',
    title: 'Third account — threat messages shown',
    arweave: ArweaveData(
      txId: 'Vt7uW9xY2zA5bC8dE1fG4hI7jK0lM3nO6pQ9rS2tU',
      url: 'https://arweave.net/Vt7uW9xY2zA5bC8dE1fG4hI7jK0lM3nO6pQ9rS2tU',
    ),
    blockchain: BlockchainData(
      fileHash:
          'sha256_d6i1f5g4h7e0c3d9g6f2e8d5h2c9f6e3d0g7b4e1d8c5h2f9e6d3c0g7b4e1d8c5',
      polygonTxHash:
          '0x7d1i5f4g0e6h3c9d7g4f1e8d5h2c9f6e3d0g7b4e1d8c5h2f9e6d3c0g7b4e1d8c5',
    ),
    encryption: EncryptionData(keyId: 'key_001', status: 'active'),
    metadata: MetadataModel(
      timestamp: '2026-03-25T16:45:00Z',
      location: LocationData(lat: 12.9716, lng: 77.5946),
      duration: 428,
      size: 209715200,
    ),
    ai: AiData(
      transcript: '',
      summary:
          'Survivor recorded a third testimony showing screenshots of threatening messages received via phone between March 20th and March 24th 2026. She described escalating intimidation and an incident on March 23rd where she was followed to her workplace.',
      entities: EntitiesData(
        persons: ['unknown male'],
        dates: ['March 20', 'March 23', 'March 24'],
        locations: ['workplace', 'transit hub'],
      ),
    ),
    status: 'uploading',
    createdAt: '2026-03-25T17:00:00Z',
  ),
];
