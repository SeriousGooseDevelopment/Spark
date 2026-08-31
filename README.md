# Spark

A SwiftUI implementation of the `Spark App.dc.html` Claude Design prototype
(project `iOS app UI rebuild`, `04df0b82-2269-4871-9cc0-67911409661b`).

Ad blocking + parental controls: four tabs, two pushed detail screens, a
quick-actions sheet, a value picker, a confirmation dialog and a toast.

## Build

`Spark.xcodeproj` is generated and gitignored. `xcode-select` on this machine
points at CommandLineTools, so `DEVELOPER_DIR` has to be overridden.

```sh
xcodegen generate

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Spark.xcodeproj -scheme Spark \
  -destination 'generic/platform=iOS Simulator' build
```

## Install on a device

Signed automatically against team `7HK9642A6T` (Timothy Koelsch).

```sh
DEV=$(xcrun devicectl list devices | awk '/Timothy Koelsch/ {print $3}')

xcodebuild -project Spark.xcodeproj -scheme Spark \
  -destination "id=$DEV" -allowProvisioningUpdates build

xcrun devicectl device install app --device "$DEV" \
  <derived-data>/Build/Products/Debug-iphoneos/Spark.app
xcrun devicectl device process launch --device "$DEV" com.timothykoelsch.Spark
```

## Tests

20 XCUITest flows cover the interactive behaviour transcribed from the design —
tab switching, the master toggle, per-app rules, site add/remove, the quick
actions, device drill-down and creation, the picker's clamping of
used-vs-limit, nested help articles, form validation, profile edits, both
confirmations and the toast.

```sh
xcodebuild test -project Spark.xcodeproj -scheme Spark \
  -destination 'id=<simulator-udid>'
```

## Layout

| Path | Role |
| --- | --- |
| `Spark/Theme.swift` | Colours, gradients, shadows, typography, safe-area environment |
| `Spark/Model.swift` | Devices, rule options, detail/picker/confirm specs, static content |
| `Spark/Store.swift` | `@Observable` state — mirrors the design's `DCLogic` class one-for-one |
| `Spark/RootView.swift` | The z-stack: tabs → shelf → pill → tab bar → sheets → dialog → toast |
| `Spark/Screens/` | Home, Blocking, Parental, Menu, Device detail, generic Detail |
| `Spark/Components/` | Toggle, cards, tab bar, sheets, arc dial, SVG path renderer |

## Beyond the design

Every control does something real — the design's placeholder actions were
replaced with working flows:

| Action | Behaviour |
| --- | --- |
| Quick actions ▸ Block / Allow a site | Form sheet → domain is cleaned (`https://www.X.com/y` → `x.com`) and added to a live list on Blocking Controls |
| Quick actions ▸ Add a device | Form sheet with name + type → real device with its own switch, limit, filter and bedtime |
| Blocking ▸ Browse all | Pushes the full 9-list filter catalogue |
| Menu ▸ Help & support | Topic → article list → article body (the push stack nests) |
| Menu ▸ Contact support / Send feedback | Compose sheets that validate and confirm |
| Menu ▸ Account | Name, email and password are editable; edits propagate to the Menu header |
| Privacy ▸ Delete all data | Actually resets devices and both site lists |
| Any card containing a toggle | Tapping anywhere on the card toggles it |

The one exception to tap-anywhere is the Parental device card: it already
drills into the device, so the card body navigates and the switch keeps its own
tap target. Sign-in is intentionally not built.

## Deviations from `Spark App.dc.html`

The Home screen follows a later mockup rather than the `.dc.html`. The blocked
count and its caption moved out of the dial and into the header (replacing
"Smooth sailing!"), and the small `[⏸ Stop Blocking Ads]` pill became an 86pt
frosted disc centred in the dial with its label beneath. Every other screen
still tracks the `.dc.html` exactly.

## Notes on the port

- **Icons** are the design's inline SVG `d` strings, drawn by `SVGPath.swift`
  (a real path parser incl. elliptical arcs) rather than hand-traced shapes.
- **Layout** offsets in the design are absolute from the top of a 402×874
  display. `HeaderScreen` / `PushedScreen` re-anchor them to the live safe-area
  inset so they hold on every device.
- **Typography** is Plus Jakarta Sans, which ships as one variable font; weights
  come from the `wght` axis via `UIFontDescriptor`, falling back to the system
  face if registration fails.
- **Overlays** stay mounted with `allowsHitTesting` gated on their state. Inside
  an `if`, a dismissing scrim or sheet keeps swallowing taps for the length of
  its exit animation — long enough to eat a tap on the control underneath.

## Launch arguments

The design exposes `activeTab`, `blockingOn` and `sparkConnected` as editable
props; they are mirrored as launch arguments. `openOverlay` is DEBUG-only and
exists so screens with no cold-launch entry point can be screenshotted.

```sh
xcrun simctl launch <udid> com.timothykoelsch.Spark -activeTab Blocking
xcrun simctl launch <udid> com.timothykoelsch.Spark -blockingOn NO
xcrun simctl launch <udid> com.timothykoelsch.Spark \
  -activeTab Parental -openOverlay picker -deviceID d1
```

`openOverlay` accepts `sheet`, `device`, `detail`, `picker`, `confirm`, `toast`.
