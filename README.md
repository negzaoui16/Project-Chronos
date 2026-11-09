# Chronos — Mobile Client (Flutter)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/Architecture-BLoC%20Pattern-blueviolet)](#architecture)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-green)](#features)

Cross-platform mobile application for the **Chronos Smart Campus Equipment Sharing Platform**, engineered during an **AIESEC Global Talent Internship** at **Maharishi Markandeshwar University (MMDU)**.

---

## 📱 Features

- **Authentication & Security:** Secure JWT-based authentication with role-based routing (Student / Admin).
- **Interactive Equipment Marketplace:** Real-time catalog of university lab equipment, VR headsets, laptops, and robotics kits.
- **Slot Reservation Engine:** Calendar-based booking system with conflict detection and automated booking validation.
- **Visual Equipment Return & QR Verification:** Camera capture interface for equipment state verification upon checkout and return.
- **Multimodal AI Troubleshooting Assistant:** 24/7 conversational interface supporting text queries, error photo uploads, and step-by-step repair guides.
- **Web3 Wallet Balance View:** Seamless tracking of Chronos escrow deposits and student token balances.

---

## 🏛️ Architecture

The application strictly implements the **BLoC (Business Logic Component)** pattern to ensure clean separation of concerns, testability, and deterministic state management:

```
lib/
├── core/
│   ├── constants/       # API endpoints, assets, routes
│   ├── network/         # HTTP client & interceptors
│   └── theme/           # Design system & color palette
├── module1/             # Blockchain wallet & escrow integration
├── module2/             # Visual inspection & damage detection views
└── module3/             # Core interactive client
    ├── auth/            # Login, register, auth BLoC
    ├── marketplace/     # Catalog browsing, item details BLoC
    ├── bookings/        # Calendar reservation, QR return BLoC
    └── chat/            # Multimodal RAG chatbot BLoC
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.19.0)
- Android Studio / VS Code with Flutter extension
- An active Android emulator or physical device

### Installation & Run

1. Clone the repository and switch to the `frontend` branch:
   ```bash
   git clone -b frontend https://github.com/negzaoui16/Project-Chronos.git
   cd Project-Chronos
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure API endpoints in `lib/core/constants/api_endpoints.dart` or pass `--dart-define`:
   ```bash
   flutter run --dart-define=API_URL=http://your-backend-ip:3000
   ```
