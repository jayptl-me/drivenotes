# DriveNotes

A cross-platform Flutter app that stores your notes as plain text files in
your own Google Drive.

DriveNotes signs you in with Google, then reads and writes note files in a
dedicated DriveNotes folder in your Drive through the Drive API. State is
managed with Riverpod and routing with go_router, in a feature-based layout.

- **Google sign-in.** OAuth via `google_sign_in` with the `email` and
  `drive.file` scopes; credentials persist in `flutter_secure_storage`.
- **Drive-backed notes.** Create, read, update and delete notes stored as
  files in a dedicated app folder in your own Google Drive.
- **Tags and filtering.** Notes carry tags; the list filters by tag from the
  sidebar.
- **Swipe to delete.** Note rows are dismissible behind a confirmation
  dialog.
- **Material 3 UI.** Dark and light themes with a persisted preference.
- **Feature-based structure.** Shared services under `lib/core`, screens and
  widgets under `lib/features`.

## Run it

### Prerequisites

- Flutter SDK (Dart `>=3.4.3 <4.0.0`)
- A Google account
- OAuth 2.0 client IDs from
  [Google Cloud Console](https://console.cloud.google.com/apis/credentials),
  with the Google Drive API enabled for the project

### Configure

1. Install dependencies:

   ```sh
   flutter pub get
   ```

2. Create a `.env` file in the project root (already listed in `.gitignore`
   and registered as an asset in `pubspec.yaml`):

   ```dotenv
   GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   GOOGLE_ANDROID_CLIENT_ID=your-android-client-id.apps.googleusercontent.com
   ```

   `GOOGLE_WEB_CLIENT_ID` is read on web builds;
   `GOOGLE_ANDROID_CLIENT_ID` is used as the server client ID on other
   platforms.

3. For web builds, also set your client ID in the
   `google-signin-client_id` meta tag in `web/index.html`.

### Start

```sh
flutter run              # mobile or desktop target
flutter run -d chrome    # web
```

## Project structure

```
lib/
  core/         # Shared logic: auth, drive, notes, router, storage, theme
  features/
    auth/       # Sign-in screens
    notes/      # Notes list, detail and editor screens
  main.dart     # Entry point
test/           # Flutter widget tests
.env            # OAuth client IDs (not committed)
```

## Libraries

- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) - state management
- [google_sign_in](https://pub.dev/packages/google_sign_in) - Google OAuth
- [googleapis](https://pub.dev/packages/googleapis) and
  [googleapis_auth](https://pub.dev/packages/googleapis_auth) - Drive API
- [http](https://pub.dev/packages/http) - networking
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) - credential storage
- [go_router](https://pub.dev/packages/go_router) - navigation
- [shared_preferences](https://pub.dev/packages/shared_preferences) - local persistence
- [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) - env config
- [dartz](https://pub.dev/packages/dartz) - functional error handling
- [intl](https://pub.dev/packages/intl), [uuid](https://pub.dev/packages/uuid),
  [logging](https://pub.dev/packages/logging)

## Known limitations

- Offline note creation and sync is only partially implemented.
- `test/widget_test.dart` is still the default Flutter counter template
  test and does not exercise the app.
- Access tokens expire after about an hour; refresh relies on silent
  re-sign-in rather than a stored refresh token.

## Privacy

Notes are stored as plain text files in a dedicated folder in your Google
Drive. No other backend is involved.

## License

Apache-2.0 - see [LICENSE](LICENSE) and [NOTICE](NOTICE).
