const tx1 = "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8S9t0UVW";
const tx2 = "Z9y8X7w6V5u4T3s2R1q0P9o8N7m6L5k4J3h2G1f0ECD";
const tx3 = "pQ1rS2tU3vW4xY5zA6bC7dE8fG9hI0jK1lM2nO3pQ4r";
const tx4 = "7a8B9c0D1e2F3g4H5i6J7k8L9m0N1o2P3q4R5s6T7u8";

const poly1 =
  "0x3f2a9b1c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f0";
const poly2 =
  "0x11aa22bb33cc44dd55ee66ff77889900aabbccddeeff00112233445566778899";
const poly3 =
  "0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";
const poly4 =
  "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

export const testimonies = [
  {
    id: "t-1",
    title: "I learned to breathe again",
    date: "2026-03-15T10:15:00.000Z",
    duration: "3:24",
    status: "Recorded",
    gps: { lat: 40.7128, lng: -74.006 },
    aiSummary:
      "They describe how isolation escalated day by day, and how a small support network helped them regain safety. The testimony emphasizes choices made toward healing, even when fear felt unavoidable.",
    arweaveTxId: tx1,
    polygonHash: poly1,
  },
  {
    id: "t-2",
    title: "A plan for the next morning",
    date: "2026-03-12T18:45:00.000Z",
    duration: "4:02",
    status: "Uploading",
    gps: null,
    aiSummary:
      "They recount planning quietly, waiting for the safest window to move, and documenting the truth for future support. The summary highlights persistence, grounding, and the moment they chose themselves.",
    arweaveTxId: tx2,
    polygonHash: poly2,
  },
  {
    id: "t-3",
    title: "Finding my voice in small steps",
    date: "2026-03-20T07:30:00.000Z",
    duration: "2:57",
    status: "Certified",
    gps: { lat: 34.0522, lng: -118.2437 },
    aiSummary:
      "The testimony focuses on the long aftermath and the work of rebuilding trust with daily routines. It also reflects on how recording their story created a sense of continuity and control.",
    arweaveTxId: tx3,
    polygonHash: poly3,
  },
  {
    id: "t-4",
    title: "Evidence, then freedom",
    date: "2026-03-24T21:05:00.000Z",
    duration: "5:11",
    status: "Recorded",
    gps: { lat: 51.5074, lng: -0.1278 },
    aiSummary:
      "They explain how fear shaped their choices, but how documenting details helped them act with clarity later. The summary ends with gratitude for survivors who keep doors open for others.",
    arweaveTxId: tx4,
    polygonHash: poly4,
  },
];
