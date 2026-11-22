# MyDay – Life & Money Manager

Monorepo: `backend/` (Node + Express + MongoDB) and `frontend/mobile/` (Flutter: Android + Web).

## 1. Backend
```bash
cd backend
cp .env.example .env     # set MONGODB_URI and a 32+ char JWT_SECRET (never commit .env)
npm install
npm test
npm run dev              # http://localhost:4000
```
API reference: `docs/BACKEND.md`. Deploy it somewhere with HTTPS (Render, Railway, Fly…) and set
`CORS_ORIGINS` to your web app origin. Release APKs cannot call plain `http://` servers.

## 2. Flutter app
Requires Flutter 3.24.x.
```bash
cd frontend/mobile
bash scripts/bootstrap.sh          # generates android/ + web/ and applies required settings
flutter pub get
flutter analyze && flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-API/api
# -> build/app/outputs/flutter-apk/app-release.apk
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-API/api
```
No Flutter on your PC? Push to GitHub, add repository variable `API_BASE_URL`
(Settings → Secrets and variables → Actions → Variables), and download the `myday-apk`
artifact from the **build** workflow.

## How offline sync works
- Every transaction/routine gets a UUID on the device and is saved locally first
  (SQLite on Android, IndexedDB on web), one database per user.
- When online (and every 2 minutes / on reconnect) the app pushes changed records to
  `POST /api/sync/push`, then pulls `GET /api/sync/pull?since=`.
- The server upserts by `(userId, clientId)`, so retries never create duplicates.
- Conflicts: newest `updatedAt` wins; a stale write is rejected and the server copy is
  returned. Routine completions are merged (union) so a completed task is never lost.
- Balance: Closing = Opening + Income − Expense. The opening balance is stored once and
  each month's opening is derived from all earlier transactions, so it is carried
  forward and never double counted.

## Known limits
- Register/login and report downloads need internet.
- Web cannot schedule background notifications (reminders are in-app only on web).
- Firebase Cloud Messaging is not wired yet (needs your Firebase project's config).
