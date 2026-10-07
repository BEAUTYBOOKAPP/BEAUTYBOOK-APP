# BEAUTYBOOK — Stage 1
Flutter MVP for Togo: beauty bookings + fashion marketplace, CFA/XOF, English/French localization foundation.

## Included
- Supabase email/password authentication
- Beauty professional catalog and service booking
- Fashion catalog, favorites, WhatsApp ordering and seller product uploads
- Self-service business creation
- Availability schema and active-slot collision protection
- In-app notification schema/triggers
- Payment abstraction (`payments`) prepared for future Mobile Money server integration
- English/French string catalog
- GitHub Actions Android debug APK build

## Important security rule
Use only the Supabase **Project URL** and **Publishable key** in the mobile build. Never place a Supabase secret/service-role key in Flutter.

## Database upgrade
The user already ran the earlier Stage 1 SQL. For that existing project, run `supabase/stage1_upgrade.sql` once. For a new database, run `supabase/schema.sql`.

## Build with GitHub Actions
Create a repository, upload this project, then add repository Actions secrets:
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Run **Build Android test APK** from Actions. The workflow creates missing Android/iOS native scaffolding, gets packages, analyzes/tests, and builds a debug APK artifact.

## Local build
`flutter create --platforms=android,ios --org com.beautybook .`
`flutter pub get`
`flutter run --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY`

## iPhone
The source targets iOS, but a distributable IPA/TestFlight build requires macOS/Xcode and Apple signing credentials.

## Mobile Money
No live provider is hard-coded. Payment secrets must stay on a trusted server/Edge Function, not in the mobile app. Provider integration is a later stage.
