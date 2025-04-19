# 📒 DriveNotes

DriveNotes is a cross-platform Flutter app that lets you securely create, view, edit, and organize notes, all stored as files in your own Google Drive. Built with a modular, feature-based architecture and modern Flutter best practices.

---

## ✨ Features

- **Google OAuth 2.0 Authentication:** Secure sign-in with Google, using Drive read/write scopes.
- **Google Drive Sync:** Notes are stored as files in a dedicated "DriveNotes" folder in your Drive.
- **Create, Edit, Delete Notes:** Full CRUD support with responsive UI.
- **Tagging & Filtering:** Organize notes with tags and filter by tag.
- **Material 3 UI:** Clean, simple, and responsive design.
- **Dark/Light Theme Switching:** Toggle between dark and light modes.
- **State Management:** Powered by Riverpod v2+ (AsyncNotifier, StateProvider, etc.).
- **Navigation:** Uses go_router for declarative routing.
- **Error Handling:** Graceful error messages and feedback in UI.
- **Modular Architecture:** Feature-based folder structure for maintainability.
- **Offline Support:** (Planned/Partial) View and edit notes offline, sync on next login.

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- A Google account

### Setup

1. **Clone the repository:**

   ```sh
   git clone https://github.com/yourusername/drivenotes.git
   cd drivenotes
   ```

2. **Install dependencies:**

   ```sh
   flutter pub get
   ```

3. **Configure Google API Credentials:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
   - Create OAuth 2.0 Client IDs for each platform (Web, Android, iOS).
   - Enable the Google Drive API for your project.
   - Download your credentials and note the client IDs.

4. **Set up environment variables:**
   - Create a `.env` file in the project root:

     ```dotenv
     GOOGLE_WEB_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
     GOOGLE_ANDROID_CLIENT_ID=your-google-android-client-id.apps.googleusercontent.com
     GOOGLE_IOS_CLIENT_ID=your-google-ios-client-id.apps.googleusercontent.com
     ```

   - **Never commit your `.env` file to version control.**

5. **Update `pubspec.yaml` assets:**

   ```yaml
   flutter:
     assets:
       - .env
   ```

6. **Run the app:**
   - For mobile:

     ```sh
     flutter run
     ```

   - For web:

     ```sh
     flutter run -d chrome
     ```

---

## 🛠️ Environment Variables

- The app uses [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) to load environment variables.
- The `.env` file should contain your Google OAuth client IDs as shown above.
- For web, you may also need to update the client ID in `web/index.html` for Google Sign-In.

---

## 📝 Usage

- **Create a Note:** Tap the "+" button and start typing.
- **Edit a Note:** Tap any note in the list to edit.
- **Delete a Note:** Swipe left/right or use the delete button.
- **Tag Notes:** Add tags to organize and filter your notes.
- **Filter by Tag:** Use the sidebar to view notes by tag.
- **Theme Switch:** Toggle between dark and light themes in the app settings.

---

## 📁 Folder Structure

```
lib/
  core/         # Shared logic (auth, drive, theme, router, etc.)
  features/
    auth/       # Authentication UI & logic
    notes/      # Notes UI, state, and logic
  main.dart     # App entry point
assets/
  images/       # App images (e.g., Google logo)
.env            # Environment variables (not committed)
```

---

## 🧩 Libraries Used

- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) (state management)
- [dio](https://pub.dev/packages/dio) (networking)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) (secure token storage)
- [googleapis](https://pub.dev/packages/googleapis), [googleapis_auth](https://pub.dev/packages/googleapis_auth)
- [json_serializable](https://pub.dev/packages/json_serializable) (data modeling)
- [go_router](https://pub.dev/packages/go_router) (navigation)
- [intl](https://pub.dev/packages/intl) (date formatting)
- [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) (env config)

---

## ⚠️ Known Limitations

- Offline note creation and sync is partially implemented.
- No unit/widget tests included (bonus point not fulfilled).
- Some advanced Drive error cases may not be fully handled.
- Only basic UI animations.

---

## 🛡️ Privacy

Your notes are stored as plain text files in a dedicated folder in your Google Drive. Only you have access to your data.

---

## 🤝 Contributing

Contributions are welcome! Please open issues or submit pull requests for improvements or bug fixes.

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

## 💡 Credits

- Built with [Flutter](https://flutter.dev/)
- Uses [Google Drive API](https://developers.google.com/drive)
