Smart-Traffic-Management-System/
├── backend/                 # Django backend
│   ├── sutms/               # Main Django project
│   ├── authentication/      # User authentication app
│   ├── vehicles/            # Vehicle management app
│   ├── violations/          # Violation detection app
│   ├── dashboard/           # Admin dashboard app
│   ├── api/                 # API endpoints
│   ├── ocr/                 # OCR utilities
│   ├── notifications/       # Notification services
│   ├── payments/            # Payment processing
│   ├── detection/           # ML detection algorithms
│   ├── manage.py            # Django management script
│   ├── requirements.txt     # Python dependencies
│   ├── Dockerfile           # Backend Docker configuration
│   └── .env.example         # Environment variables example
│
└── frontend/                # Flutter frontend
    ├── lib/                 # Flutter source code
    │   ├── main.dart        # Entry point
    │   ├── models/          # Data models
    │   │   ├── user.dart
    │   │   ├── vehicle_model.dart
    │   │   ├── violation_model.dart
    │   │   └── detection_result.dart
    │   ├── screens/         # UI screens
    │   │   ├── splash_screen.dart
    │   │   ├── home_screen.dart
    │   │   ├── auth/
    │   │   ├── profile/
    │   │   ├── vehicles/
    │   │   ├── violations/
    │   │   ├── camera_screen.dart
    │   │   ├── detection_result_screen.dart
    │   │   ├── payment_screen.dart
    │   │   └── video_processing_screen.dart
    │   ├── widgets/         # Reusable widgets
    │   │   ├── custom_button.dart
    │   │   ├── custom_text_field.dart
    │   │   ├── dashboard_card.dart
    │   │   ├── main_drawer.dart
    │   │   └── loading_overlay.dart
    │   ├── services/        # API services
    │   │   ├── api_service.dart
    │   │   └── notification_service.dart
    │   ├── providers/       # State management
    │   │   ├── auth_provider.dart
    │   │   ├── theme_provider.dart
    │   │   ├── vehicle_provider.dart
    │   │   ├── violation_provider.dart
    │   │   ├── payment_provider.dart
    │   │   └── detection_provider.dart
    │   ├── utils/           # Utility functions
    │   │   ├── api_constants.dart
    │   │   └── app_theme.dart
    │   └── algorithms/      # ML algorithms for mobile
    │       ├── number_plate_detector.dart
    │       └── violation_detector.dart
    ├── assets/              # Images, fonts, models
    ├── android/             # Android platform code
    ├── ios/                 # iOS platform code
    ├── pubspec.yaml         # Flutter dependencies
    ├── flutter_launcher_icons.yaml # App icon configuration
    ├── flutter_native_splash.yaml  # Splash screen configuration
    └── .env.example         # Environment variables example

