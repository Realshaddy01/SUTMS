# Smart Urban Traffic Management System (SUTMS)

An AI-enhanced violation tracking system capable of detecting violations, verifying vehicles instantly, and issuing alerts to both traffic authorities and vehicle owners.

## Project Structure

The project consists of two main components:
- Django Backend: Handles API requests, database operations, and AI processing
- Flutter Frontend: Mobile application for users and traffic officers

## Features

- **AI-Powered Detection**: Automatically detect traffic violations using computer vision
- **Real-time Notifications**: Instant alerts to both traffic authorities and vehicle owners
- **QR-based Verification**: Quick vehicle verification through QR codes
- **OCR Technology**: Automatic license plate recognition
- **Payment Integration**: Seamless violation fee payment system
- **Analytics Dashboard**: Comprehensive traffic violation analytics
- **User Management**: Different access levels for vehicle owners and traffic officers

## Technologies Used

### Backend
- Django REST Framework
- PostgreSQL
- Channels for WebSockets
- TensorFlow/PyTorch for AI models
- Redis for caching
- Celery for background tasks

### Frontend
- Flutter for cross-platform mobile development
- Provider for state management
- Firebase for push notifications
- Camera integration for violation detection
- QR code scanning capabilities

## Backend Setup

1. Navigate to the backend directory:
\`\`\`bash
cd backend
\`\`\`

2. Create a virtual environment:
\`\`\`bash
python -m venv venv
\`\`\`

3. Activate the virtual environment:
\`\`\`bash
# On Windows
venv\Scripts\activate
# On macOS/Linux
source venv/bin/activate
\`\`\`

4. Install dependencies:
\`\`\`bash
pip install -r requirements.txt
\`\`\`

5. Create a `.env` file based on `.env.example`:
\`\`\`bash
cp .env.example .env
\`\`\`

6. Apply migrations:
\`\`\`bash
python manage.py migrate
\`\`\`

7. Create a superuser:
\`\`\`bash
python manage.py createsuperuser
\`\`\`

8. Run the development server:
\`\`\`bash
python manage.py runserver
\`\`\`

## Frontend Setup

1. Navigate to the frontend directory:
\`\`\`bash
cd frontend
\`\`\`

2. Create a `.env` file based on `.env.example`:
\`\`\`bash
cp .env.example .env
\`\`\`

3. Install Flutter dependencies:
\`\`\`bash
flutter pub get
\`\`\`

4. Set up Firebase (optional for push notifications):
   - Create a Firebase project
   - Download `google-services.json` for Android and place it in `android/app/`
   - Download `GoogleService-Info.plist` for iOS and place it in `ios/Runner/`

5. Run the app:
\`\`\`bash
flutter run
\`\`\`

## Docker Deployment

The project includes Docker configuration for easy deployment:

1. Make sure Docker and Docker Compose are installed on your system

2. Create environment files based on examples:
\`\`\`bash
cp .env.example .env
\`\`\`

3. Build and start the containers:
\`\`\`bash
docker-compose up -d
\`\`\`

4. The application will be available at:
   - Backend API: http://localhost:8000/api/
   - Admin panel: http://localhost:8000/admin/

## System Architecture

\`\`\`
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Mobile Client  │◄────┤  Django API     │◄────┤  AI Processing  │
│  (Flutter)      │     │  (REST/WebSock) │     │  (Detection)    │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │
                               │
                        ┌──────▼──────┐
                        │             │
                        │  Database   │
                        │ (PostgreSQL)│
                        │             │
                        └─────────────┘
\`\`\`

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit your changes: `git commit -m 'Add some feature'`
4. Push to the branch: `git push origin feature-name`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

