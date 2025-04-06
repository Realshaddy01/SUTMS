# SUTMS Flutter Mobile Application

This is the mobile application component of the Smart Urban Traffic Management System (SUTMS) for Nepal. The application is built using Flutter and integrates with the SUTMS backend API.

## Features

- License plate detection using OCR
- Traffic violation reporting and management
- QR code scanning for vehicle verification
- Violation payment processing via Stripe
- Push notifications for violation updates
- User authentication and profile management
- Dark mode support

## Setup

### Prerequisites

- Flutter SDK (version 2.17.0 or higher)
- Android Studio / VS Code with Flutter extensions
- iOS development setup (if targeting iOS)

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/your-org/sutms-flutter.git
   cd sutms-flutter
   ```

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Configure Firebase:
   - Create a Firebase project
   - Download the `google-services.json` file and place it in `android/app/`
   - Download the `GoogleService-Info.plist` file and place it in `ios/Runner/`

4. Update the API base URL in `lib/services/api_service.dart`

5. Run the application:
   ```
   flutter run
   ```

## Architecture

The application follows a Provider-based architecture:

- **Models**: Data structures for objects like users, vehicles, violations
- **Services**: API communication, authentication, storage
- **Providers**: State management for different features
- **Screens**: UI components for different app sections
- **Widgets**: Reusable UI components
- **Utils**: Helper classes and utilities

## Testing

Run tests with:
```
flutter test
```

## Build for Production

```
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## License

This project is proprietary and confidential.

## Contact

For inquiries, contact the SUTMS development team at [contact@sutms.gov.np](mailto:contact@sutms.gov.np)
