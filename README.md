# ViRest

Aplikasi iOS SwiftUI untuk personalisasi rekomendasi olahraga berdasarkan onboarding, HealthKit, dan rule-based engine.

## Quick Start

1. Buka project `ViRest.xcodeproj` di Xcode.
2. Pastikan konfigurasi Firebase sudah valid untuk app ini.
3. Jalankan target `ViRest` di iOS Simulator.

Build via terminal:

```bash
xcodebuild -project "ViRest.xcodeproj" -scheme "ViRest" -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## App Flow Singkat

- Belum login -> halaman Auth
- Sudah login + belum onboarding lengkap (`sportPlan` belum ada) -> Onboarding
- Sudah login + onboarding lengkap -> Main tabs (Home, Profile)

## Dokumentasi Lengkap

Lihat: [`docs/TECHNICAL_DOCUMENTATION.md`](docs/TECHNICAL_DOCUMENTATION.md)

