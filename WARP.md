# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Multicrop is a Flutter mobile application for precision palm tree data collection. It enables field workers to record measurements (bunch weight, bunch count) for individual palm trees across different trials and plots, with offline-first functionality and API synchronization.

## Common Commands

### Development
```powershell
# Install dependencies
flutter pub get

# Run app on connected device/emulator
flutter run

# Run in debug mode with hot reload
flutter run --debug

# Run in release mode
flutter run --release

# Build APK for Android
flutter build apk

# Build app bundle for Android
flutter build appbundle

# Run on specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

### Testing
```powershell
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

### Code Quality
```powershell
# Run static analysis (linting)
flutter analyze

# Format all Dart files
dart format .

# Format specific file
dart format lib/main.dart
```

### Dependencies
```powershell
# Update dependencies to latest compatible versions
flutter pub upgrade

# Check for outdated packages
flutter pub outdated

# Clean build artifacts
flutter clean
```

## Architecture

### Application Flow
1. **SplashScreen** → animated intro with app logo and typing animation
2. **LoginScreen** → authentication via staff number and password
3. **BottomNavBar** → main navigation hub with three sections:
   - **ProfilePage** (Dashboard): displays user info, trials, and statistics
   - **NewDataEntryPage** (Trial Entry): record measurements for trees
   - **RecentEntriesPage** (View Entries): view and sync recorded data

### Key Architectural Patterns

#### Offline-First Design
The app is designed to work offline with local data persistence:
- **Local Storage**: `SharedPreferences` stores user authentication, app settings, and cached trial/plot data
- **StorageHelper**: manages local entry persistence with JSON serialization
- **Connectivity Detection**: `connectivity_plus` monitors network status
- **Manual Offline Mode**: users can force offline mode even when connected
- **Sync Flow**: entries are stored locally, then synced to API when online

#### State Management
- Uses Flutter's built-in `StatefulWidget` with `setState()`
- No external state management library (Provider, Bloc, Riverpod, etc.)
- State is component-local and passed via constructors/callbacks

#### Data Flow
1. **Authentication**: `ApiAuthService` handles login and stores JWT token + user data in SharedPreferences
2. **Trial Selection**: User selects trial from `ProfilePage` → navigates to `NewDataEntryPage` with trial context
3. **Data Entry**: User records tree measurements (plot, tree number, weight, bunches)
4. **Local Save**: Entries saved via `StorageHelper.saveEntries()`
5. **Sync**: When online, entries sent to API via `ApiRecordService.submitRecord()` or batch sync

### Directory Structure

```
lib/
├── main.dart                    # App entry point
├── splash.dart                  # Splash screen with animations
├── bottomnav.dart              # Main navigation with CurvedNavigationBar
├── auth/                       # Authentication screens
│   ├── login_auth.dart         # Login screen
│   └── forget_auth.dart        # Password recovery
├── screen/                     # Main application screens
│   ├── dashboard_screen.dart   # ProfilePage - user dashboard and trial selection
│   ├── trial_entry_screen.dart # NewDataEntryPage - data recording interface
│   ├── view_entry_screen.dart  # RecentEntriesPage - view and sync entries
│   ├── sync_page_screen.dart   # Sync status and management
│   └── trial2_entry_screen.dart # Alternative entry screen (if applicable)
└── service/                    # API and storage services
    ├── api_auth_service.dart   # Authentication API calls + token management
    ├── api_trial_service.dart  # Trial data fetching (GET /api/fetch-trial)
    ├── api_record_service.dart # Record submission and sync endpoints
    └── storage_service.dart    # Local persistence with SharedPreferences
```

### Service Layer Details

#### ApiAuthService
- **Token Storage**: Manages JWT token and user profile in SharedPreferences
- **Login**: POST `/api/login` with staff_no and password
- **Logout**: POST `/api/logout` + clears local auth data
- **Helper Methods**: `getAccessToken()`, `getUserName()`, `getStaffNo()`, `getUserPosition()`, etc.

#### ApiTrialService
- **Get Trials**: GET `/api/fetch-trial` - fetches available trials
- **Trial Details**: GET `/api/trials/{id}` - specific trial data
- **Create/Update**: POST/PUT for trial management (permissions-based)

#### ApiRecordService
- **Submit Record**: POST `/api/store-data-recording` - single entry submission
- **Sync Records**: POST `/api/sync-records` - batch sync multiple entries
- **Data Format**: Entries include trial_id, plot_id, tree_number, measurement_date/time, and parameters array (weight, bunches)
- **Error Handling**: Parses Laravel-style validation errors from 422 responses

#### StorageHelper
- **Save Entries**: Serializes entry list (including DateTime objects) to JSON in SharedPreferences
- **Load Entries**: Deserializes entries with DateTime parsing
- **Key**: Uses `'entries'` as the SharedPreferences key

### API Integration Notes

- **Base URL**: Configured in each service file as `baseUrl = 'https://example.com'` - **must be updated** with actual API endpoint
- **Authentication**: Bearer token authorization for all API calls except login
- **Timeouts**: Most API calls have 15-second timeout, sync has 30-second timeout
- **Error Types**: Handles 200/201 (success), 401 (unauthorized), 422 (validation), network timeouts, SocketException

### Data Models

Entries are stored as `Map<String, dynamic>` with keys:
- `trial_id`, `plot_id`, `tree_number`
- `measurement_date`, `measurement_time` (DateTime objects, serialized as ISO8601)
- `weight` (double), `bunches` (int)
- `syncStatus` - tracks whether entry has been synced to API
- `remark` - additional notes

### UI Components

- **CurvedNavigationBar**: Custom bottom navigation from `curved_navigation_bar` package
- **Theme**: Green color scheme (`Color(0xFF4CAF50)` primary green)
- **Animations**: Splash screen uses multiple AnimationControllers for entrance, pulse, and rotation effects
- **Custom Fonts**: Uses "Satisfy" font family for branding

### Important Dependencies

- `http: ^1.2.0` - API communication
- `shared_preferences: ^2.5.3` - local data persistence
- `sqflite: ^2.3.0` - SQLite database (if used beyond SharedPreferences)
- `connectivity_plus: ^7.0.0` - network status detection
- `intl: ^0.20.2` - date/time formatting
- `uuid: ^4.4.0` - unique ID generation
- `image_picker: ^1.1.1` - photo capture capability
- `pdf: ^3.10.0` + `printing: ^5.12.0` - PDF generation and printing

### Development Notes

- **Platform Support**: Configured for Android, iOS, Linux, macOS, Web, and Windows (see platform folders)
- **Flutter Version**: SDK ^3.9.2
- **Lints**: Uses `flutter_lints: ^5.0.0` with standard Flutter lint rules
- **Assets**: Palm tree images and SVG located in `lib/assets/` and referenced in pubspec.yaml

### Testing

- Basic widget test included in `test/widget_test.dart`
- No comprehensive test suite currently implemented
- Run tests with `flutter test`

### Build Configuration

- **App Name**: "Multicrop"
- **Version**: 1.0.0+1
- **Bundle ID**: Configured per platform in respective folders (android/, ios/, etc.)
- **Icons**: Custom launcher icons via `flutter_launcher_icons: ^0.13.1`

## Workflow Tips

When modifying screens or adding features:
1. Check if the screen needs offline support - most features should work offline
2. Update both the service layer and local storage logic if changing data structure
3. Test connectivity transitions (online → offline → online) to ensure data integrity
4. Follow the existing pattern: load cached data first, then fetch from API if online
5. Use `setState()` to trigger UI updates after async operations
