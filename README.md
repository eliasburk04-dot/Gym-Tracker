# Gym Tracker Auth Shell

Dieses Repository wurde auf eine Auth-only Basis reduziert, damit der eigentliche Neuaufbau auf einem sauberen Fundament starten kann.

## Was bleibt erhalten

- Flutter iOS App mit Firebase Login per Apple, Google und Email/Passwort
- Kleiner eingeloggter Account-Screen zur Verifikation von Firebase und Backend
- Fastify Backend mit `/health` und `/auth/verify-token`
- Raspberry-Pi Deploy über Docker Compose

## Voraussetzungen

- Flutter SDK 3.10+
- Xcode 16+
- Node.js 20+
- Docker Compose
- Firebase Projekt mit aktivierten Sign-in Methoden

## Firebase Setup

1. Erstelle ein Firebase Projekt.
2. Aktiviere unter Authentication die Provider Apple, Google und Email/Password.
3. Lade `GoogleService-Info.plist` in `ios/Runner/`.
4. Lege den Firebase Service Account für das Backend als `server/firebase-service-account.json` ab.

## Flutter App starten

```bash
flutter pub get
flutter run --dart-define=SYNC_BASE_URL=http://100.69.69.19:3001
```

Wenn kein `SYNC_BASE_URL` gesetzt wird, verwendet die App standardmäßig `http://100.69.69.19:3001`.

## Backend lokal starten

```bash
cd server
npm install
docker compose up -d
npm run prisma:deploy
npm run dev
```

Danach ist das Backend unter `http://localhost:3001` erreichbar.

## Auf den Pi nach `/opt` deployen

```bash
chmod +x scripts/deploy_pi.sh
./scripts/deploy_pi.sh 100.69.69.19 milkathedog
```

Standard-Zielpfad ist `/opt/taplift-auth`.

## Struktur

```text
lib/
  app.dart
  main.dart
  data/services/
    auth_service.dart
    backend_auth_service.dart
  providers/auth_provider.dart
  routing/app_router.dart
  views/
    onboarding/sign_in_screen.dart
    account/account_screen.dart

server/
  src/
    index.ts
    lib/
    plugins/
    routes/auth.ts
  prisma/
  docker-compose.yml
  Dockerfile

scripts/
  deploy_pi.sh
```

## Hinweis

Die iOS-spezifischen Zusatztargets aus dem alten Stand liegen noch im Projekt, damit das bestehende Xcode-Projekt nicht unnötig destabilisiert wird. Die aktive App-Logik im Dart- und Server-Code ist aber jetzt auf Login reduziert.
