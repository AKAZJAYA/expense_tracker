# Expense Tracker - Flutter iOS App

A beautiful, offline-first expense tracking application for iOS devices.

## Features

- ✅ Add and categorize expenses and income transactions
- ✅ Photo attachment support for receipts
- ✅ Recurring bills tracking
- ✅ Budget creation and monitoring
- ✅ Search and filter transactions
- ✅ Visual charts and spending statistics
- ✅ CSV export functionality
- ✅ Local SQLite database (fully offline)
- ✅ Material 3 UI with iOS-friendly design

## Prerequisites

To build and run this app on your iOS device, you need:

1. **macOS** (required for iOS development)
2. **Xcode** (latest version from the Mac App Store)
3. **Flutter SDK** (3.0.0 or higher)
4. **CocoaPods** (for iOS dependencies)

## Installation

### 1. Install Flutter

```bash
# Download Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

### 2. Install Xcode Command Line Tools

```bash
xcode-select --install
```

### 3. Install CocoaPods

```bash
sudo gem install cocoapods
```

## Building for iOS

### 1. Get Dependencies

```bash
cd expense_tracker
flutter pub get
```

### 2. Open iOS Project in Xcode

```bash
open ios/Runner.xcworkspace
```

### 3. Configure Signing

1. In Xcode, select the **Runner** project
2. Select the **Runner** target
3. Go to **Signing & Capabilities**
4. Select your **Team** (you may need to add your Apple ID in Xcode preferences)
5. Xcode will automatically generate a bundle identifier

### 4. Run on Simulator

```bash
# List available simulators
flutter emulators

# Run on iOS simulator
flutter run
```

### 5. Run on Physical Device

1. Connect your iPhone via USB
2. Trust the computer on your iPhone
3. In Xcode, select your device from the device menu
4. Run:

```bash
flutter run
```

### 6. Build for Release

```bash
# Build IPA for App Store
flutter build ios --release

# Or build for ad-hoc distribution
flutter build ipa
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── transaction.dart
│   ├── category.dart
│   ├── budget.dart
│   └── recurring_bill.dart
├── services/                 # Business logic
│   ├── database_service.dart
│   └── export_service.dart
└── screens/                  # UI screens
    ├── home_screen.dart
    ├── transactions_screen.dart
    ├── add_transaction_screen.dart
    ├── budgets_screen.dart
    ├── recurring_bills_screen.dart
    └── statistics_screen.dart
```

## Database Schema

The app uses SQLite with the following tables:

- **categories** - Expense/income categories
- **transactions** - All financial transactions
- **budgets** - Budget limits by category
- **recurring_bills** - Recurring payment tracking

## Troubleshooting

### Pod Install Issues

```bash
cd ios
pod install --repo-update
cd ..
```

### Build Errors

```bash
# Clean build
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios
```

### Simulator Issues

```bash
# Reset simulator
xcrun simctl erase all
```

## Privacy

All data is stored locally on your device. No data is sent to external servers. The app works completely offline.

## Permissions

The app requests the following permissions:

- **Camera** - To take photos of receipts
- **Photo Library** - To select receipt photos from gallery

## License

This project is created for personal use.
