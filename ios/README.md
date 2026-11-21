# Math Blitz for iPhone

A native SwiftUI app for the daily Blitz. Same four steps as the web page —
Watch → Answer → Rapid Fire → Bonus — but offline-capable, with a real daily
reminder and no browser in the way.

**It has no accounts, no ads, no analytics, no tracking and no backend.**
Everything a kid does stays on their iPhone. The only network call is
downloading lesson videos from the public GitHub Pages site. That is a design
decision, not an accident: it is what keeps the app clear of COPPA's
data-collection rules and of Apple's Kids-category advertising restrictions.

## Layout

| Path | What it is |
|---|---|
| `MathBlitzCore/` | A plain Swift package: lesson models, the XP and Math Level engine, the lesson picker, the reminder schedule. No UIKit, no SwiftUI, so it unit-tests anywhere. |
| `App/` | The SwiftUI app. Views, the content store, local persistence. |
| `UITests/` | Simulator smoke tests that run in CI. |
| `project.yml` | [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec. The `.xcodeproj` is generated, never committed, so there are no merge conflicts in it. |
| `fastlane/` | TestFlight upload. |
| `../bank.json` | The lesson pack the app downloads, built by `engine/build_bank.py`. |

## Building without a Mac

The repo is public, so **GitHub's macOS runners are free and unlimited**. CI is
the Mac. `.github/workflows/ios.yml` runs on every push:

1. `core` — `swift test` on the rules package.
2. `app` — installs XcodeGen, generates the project, builds and runs the UI
   tests on a simulator, then compiles a Release build. Simulator builds need
   no signing, so **this whole stage works with no Apple Developer account.**
3. `bank` — validates `bank.json` against every question.
4. `testflight` — only on a manual run, and only with the secrets below.

If you do have a Mac: `brew install xcodegen && cd ios && xcodegen generate &&
open MathBlitz.xcodeproj`.

## Getting it onto a phone

Everything above is free. Installing on a real iPhone is where Apple's
$99/year Developer Program comes in — TestFlight needs it, and so does any
build that lasts longer than 7 days.

1. Join the [Apple Developer Program](https://developer.apple.com/programs/)
   ($99/year). Use an Apple Account that is not a child's.
2. In App Store Connect create the app record with bundle id
   `com.dellajax.mathblitz` (change it in `project.yml` and `fastlane/Appfile`
   if you prefer another).
3. Create an **App Store Connect API key** (Users and Access → Integrations →
   App Store Connect API, role: App Manager). Download the `.p8` once.
4. Create a private git repo for signing certificates, then run
   `fastlane match appstore` once from any Mac — or let the first TestFlight
   run create them if you switch `readonly` off in `fastlane/Matchfile`.
5. Add these GitHub **secrets** to this repo:
   - `ASC_KEY_ID` — the key's ID
   - `ASC_ISSUER_ID` — the issuer ID on the same page
   - `ASC_KEY_P8` — the `.p8` file, base64-encoded (`base64 -i key.p8`)
   - `MATCH_GIT_URL` — the signing repo's URL
   - `MATCH_PASSWORD` — the passphrase match encrypts with
   and the **variable** `APP_IDENTIFIER` if you changed the bundle id.
6. Actions → *iOS app* → **Run workflow**, tick *Also upload to TestFlight*.
7. Invite testers in App Store Connect. Up to 100 internal testers, and
   external testers need a one-time Apple review of the build.

TestFlight builds expire after 90 days, so plan on a rebuild each quarter even
if nothing changes.

## Adding lessons

The app never generates anything at runtime. Lessons come from the bank:

```bash
python3 engine/build_bank.py       # engine/lessons/*.json  ->  bank.json
python3 engine/validate_bank.py    # refuses bad maths, duplicate choices, missing videos
git commit -am "Bank: add day NNN" && git push
```

GitHub Pages republishes in about a minute and every phone picks it up on next
launch. No App Store review is needed to add lessons, because the lesson pack
is data, not code.

The picker (`MathBlitzCore/Sources/MathBlitzCore/LessonPicker.swift`) chooses
from the bank: next topic on a win, an easier variant of the same topic after a
miss, a Boss Battle every seventh lesson.

## One deliberate difference from the web page

The web scoreboard counts a streak in consecutive *lesson numbers*. The app
counts consecutive *calendar days*, because that is what "🔥 5 day streak"
means to a kid. XP and Math Level rules are otherwise identical, and
`ScoringTests.testJacksFirstTwoDays` pins the app's numbers to the real log.

## Before any public release

This build is aimed at TestFlight for one kid and a few friends. Going to the
public App Store adds obligations that are not handled here: an age rating and
possibly the Kids category, a published privacy policy URL, parental consent
under the amended COPPA rule, and the state app-store age-verification laws.
Get a lawyer's eyes on it first.
