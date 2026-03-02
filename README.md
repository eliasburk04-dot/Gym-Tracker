# TapLift — Back-Tap Gym Tracker

The fastest possible gym reps/sets tracker. Double-tap the back of your iPhone → a **Live Activity** appears on the Lock Screen with interactive controls — log sets **without ever opening the app**.

## Architecture

| Layer | Tech |
|-------|------|
| **Mobile** | Flutter (iOS), Riverpod 2, Drift (SQLite), GoRouter |
| **Live Activity** | ActivityKit + WidgetKit, LiveActivityIntent buttons |
| **Back Tap** | AppIntents → Shortcuts → iOS Back Tap accessibility setting |
| **Auth** | Firebase Auth (Apple / Google / Email+Password) |
| **Backend** | Fastify, Prisma, PostgreSQL (runs on Raspberry Pi) |
| **Deploy** | Docker Compose, `scripts/deploy_pi.sh` |

## Quick Start

### Prerequisites

- Flutter SDK ≥ 3.10
- Xcode 16+ (macOS only)
- Node.js 20+
- Docker & Docker Compose (for backend)
- A Firebase project

### 1. Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com).
2. Enable **Authentication** → Sign-in methods: Apple, Google, Email/Password.
3. Add an **iOS app** with bundle ID `com.taplift.taplift`.
4. Download `GoogleService-Info.plist` and place it in `ios/Runner/`.
5. For the backend: download a **Service Account JSON** and place it at `server/firebase-service-account.json`.

### 2. Flutter App

```bash
# Install dependencies
flutter pub get

# Generate Drift code
dart run build_runner build --delete-conflicting-outputs

# Run on iOS simulator or device
flutter run
```

### 3. Xcode Configuration (required for Live Activity)

Open `ios/Runner.xcworkspace` in Xcode and perform these steps:

#### a) Add Widget Extension Target

1. File → New → Target → **Widget Extension**.
2. Product Name: `TapLiftWidgets`.
3. Uncheck "Include Configuration Intent".
4. Check "Include Live Activity".
5. Delete the auto-generated Swift files and add the files from `ios/TapLiftWidgets/`.

#### b) Add App Intents Extension

1. Create a new Swift file group or framework target, **or** simply include the intent files in the main app target and widget extension target:
   - `ios/TapLiftIntents/LiveActivityIntents.swift`
   - `ios/TapLiftIntents/ShortcutIntents.swift`
   - `ios/TapLiftIntents/TapLiftShortcutsProvider.swift`
2. Add these files to **both** the `Runner` and `TapLiftWidgets` targets.

#### c) Shared Code

1. Add `ios/Shared/SharedState.swift` and `ios/Shared/GymActivityAttributes.swift` to **both** the `Runner` and `TapLiftWidgets` targets.

#### d) App Groups

1. Select the **Runner** target → Signing & Capabilities → + Capability → **App Groups** → add `group.com.taplift.shared`.
2. Select the **TapLiftWidgets** target → same steps → same group name.

#### e) Entitlements

The entitlement files are already created at:
- `ios/Runner/Runner.entitlements`
- `ios/TapLiftWidgets/TapLiftWidgets.entitlements`

Make sure each target's Build Settings → Code Signing Entitlements points to the correct file.

### 4. Enable Back Tap

On your iPhone:
1. **Settings → Accessibility → Touch → Back Tap**.
2. Choose **Double Tap** (or Triple Tap).
3. Scroll to **Shortcuts** → select **"Start Workout"** (the TapLift shortcut).

Now double-tap the back of your phone to start a Live Activity workout session.

### 5. Backend (Local Development)

```bash
cd server

# Install dependencies
npm install

# Copy env file
cp .env.example .env
# Edit .env with your DATABASE_URL and FIREBASE_SERVICE_ACCOUNT_PATH

# Start PostgreSQL
docker compose up postgres -d

# Run Prisma migrations
npx prisma migrate dev --name init

# Start dev server
npx tsx src/index.ts
```

The server will be available at `http://localhost:3000`. Test with:

```bash
curl http://localhost:3000/health
```

### 6. Deploy to Raspberry Pi

```bash
# Make the deploy script executable
chmod +x scripts/deploy_pi.sh

# Deploy (defaults to raspberrypi.local / pi user)
./scripts/deploy_pi.sh

# Or specify host and user
./scripts/deploy_pi.sh 192.168.1.100 myuser
```

The script will:
1. Rsync server files to the Pi.
2. Copy `.env` and Firebase service account.
3. Build & start Docker containers.
4. Run Prisma migrations.
5. Health-check the server.

### 7. Connect App to Backend

In the app's **Settings** screen, the sync service URL defaults to `http://raspberrypi.local:3000`. Update `lib/data/services/sync_service.dart` `_baseUrl` to match your Pi's address if different.

## Project Structure

```
├── lib/
│   ├── main.dart                   # Entry point
│   ├── app.dart                    # CupertinoApp.router
│   ├── models/
│   │   └── enums.dart              # SetSource, WeightUnit
│   ├── data/
│   │   ├── database/
│   │   │   ├── tables/             # 5 Drift table definitions
│   │   │   └── app_database.dart   # @DriftDatabase
│   │   ├── repositories/           # workout, exercise, set repos
│   │   └── services/               # auth, live_activity, sync
│   ├── providers/                  # Riverpod providers
│   ├── routing/
│   │   └── app_router.dart         # GoRouter config
│   └── views/
│       ├── onboarding/             # sign_in, setup
│       ├── today/                  # main workout screen
│       ├── settings/               # settings, editors
│       └── widgets/                # reusable components
├── ios/
│   ├── Runner/                     # Main app + AppDelegate
│   ├── Shared/                     # SharedState, GymActivityAttributes
│   ├── TapLiftWidgets/             # Live Activity UI
│   └── TapLiftIntents/             # LiveActivityIntents, ShortcutIntents
├── server/
│   ├── prisma/schema.prisma        # Database schema
│   ├── src/
│   │   ├── index.ts                # Fastify entry point
│   │   ├── lib/                    # Firebase admin
│   │   ├── plugins/                # Auth, CORS
│   │   └── routes/                 # API routes
│   ├── Dockerfile
│   └── docker-compose.yml
├── scripts/
│   └── deploy_pi.sh               # Pi deployment script
└── test/                           # Flutter unit tests
```

## How It Works

1. **Back Tap** triggers `StartWorkoutIntent` (an AppIntent exposed to Shortcuts).
2. The intent reads today's weekday, resolves the workout plan from `UserDefaults` (App Group), and starts a **Live Activity** via ActivityKit.
3. The Live Activity renders interactive buttons using `Button(intent:)` — these execute `LiveActivityIntent` subclasses **in the widget extension process** without foregrounding the app.
4. When the user taps **DONE SET**, `CompleteSetIntent` appends the set to a pending queue in `UserDefaults`.
5. When the Flutter app is next opened (or resumed), it reads the pending queue, persists sets to the local Drift database, and syncs to the backend.

## Tests

```bash
flutter test
```

## License

Private — all rights reserved.
