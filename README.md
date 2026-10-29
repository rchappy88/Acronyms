# MOD Acronym Directory — Flutter PWA update (milestone 1)

This is an **overlay**, not a complete Flutter project. Copy these files into your existing `Acronyms` project, preserving its `android/`, `ios/`, `web/index.html`, and other generated Flutter files.

## What's included
- `lib/main.dart`: structured JSON loading, unlimited matching search results, category filter, locally stored personal additions; official entries no longer editable from the UI.
- `lib/directory_storage*.dart`: original cross-platform storage adapters.
- `assets/acronyms.json`: **21,085** unique acronym/meaning pairs extracted from the supplied Word document. These are **unverified** source-derived entries, not official endorsements.
- `assets/acronyms.audit.json`: **2,655** source paragraphs flagged for manual review due to multiple tabs or parsing ambiguity. **Do not publish the data publicly until reviewed for parsing accuracy, sensitivity, and redistribution permission.**
- `assets/acronyms_mod.docx`: original source retained for comparison; no longer bundled into the app by pubspec.
- `tools/convert_acronyms.py`: repeatable importer (requires `python-docx`).
- `web/manifest.json`, `web/icons/`: PWA metadata and placeholder install icons.

## How to apply
1. Back up your existing project or commit your current work in Git.
2. Extract the archive, then copy its `lib/`, `assets/`, `web/manifest.json`, `web/icons/`, and `pubspec.yaml` into the **same locations** in your existing Flutter project. **Do not replace the whole `web/` folder** or your existing `web/index.html`.
3. In `web/index.html`, check for `<link rel="manifest" href="manifest.json">` inside `<head>`; add it if missing. For iOS, add `<meta name="apple-mobile-web-app-capable" content="yes">` and `<meta name="apple-mobile-web-app-title" content="MOD Acronyms">` if absent.
4. In VS Code's terminal, run `flutter pub get`, `flutter analyze`, then `flutter run -d chrome`.
5. Check sample searches including repeated acronyms (e.g. `AA` and `AESP`), category filter, local personal addition, refresh persistence, and inability to edit official entries.
6. After review, build with `flutter build web --release --base-href /Acronyms/` **only if deploying to** `https://rchappy88.github.io/Acronyms/`. For a root-domain deployment, use `/` instead. The hosting URL must be HTTPS for installability.

## Important limitations
- **Not yet a shared-submission system.** Local additions remain on the user's own device; Supabase moderation is a later milestone.
- **Offline operation not yet verified.** A manifest alone does not guarantee offline caching. We must test and configure caching after choosing hosting and Flutter build version.
- **Not yet tested with Flutter SDK.** The build tools are not installed in this environment. Please run the commands above and share any diagnostics.
- **Data-quality review required.** Some original DOCX paragraphs concatenate multiple acronym entries; the importer uses the same split heuristic as the earlier app and flags ambiguous rows for human review. Do not treat the extracted count as verified or the content as cleared for public release.
- Existing locally saved edits to official entries are intentionally not loaded; personal entries from the prior custom storage key remain available.
