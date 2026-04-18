# Distribution

How to build and ship a KeyWidget .dmg to friends and family for UAT.

## Building the DMG

```
./scripts/build-dmg.sh
```

Output lands in `dist/KeyWidget-<version>-build<n>.dmg`. Version and build
number are read from `project.yml` — bump both targets' `CFBundleVersion`
in lockstep before a new round of testing so recipients can tell what
they're running.

The script will:

1. Regenerate the Xcode project via `./bin/gen`.
2. Build `Release` unsigned (so Xcode doesn't demand a provisioning
   profile for the sandbox / app-group entitlements).
3. Sign the widget extension and app with the best identity available
   (Developer ID if installed, ad-hoc otherwise), embedding entitlements
   from `KeyWidgetApp/KeyWidget.entitlements` and
   `KeyWidgetWidget/KeyWidgetWidget.entitlements`.
4. Stage `KeyWidget.app` + an `Applications` symlink and package as
   compressed `UDZO` .dmg.
5. (Developer ID only) Submit to Apple's notary service, wait for
   approval, and staple the ticket so Gatekeeper accepts the DMG offline.

## Signing modes

The script picks the best available identity:

- **Developer ID Application + notarization** (current setup) → recipients
  can double-click and run, no warnings.
- **Ad-hoc** (fallback if no Developer ID cert is in the keychain) → app
  runs but Gatekeeper treats it as an unidentified developer; recipients
  need a one-time right-click → Open.

To skip notarization on a quick local rebuild:

```
NOTARIZE=0 ./scripts/build-dmg.sh
```

## Notarization setup (already done)

For reference if the keychain profile is ever lost:

1. Generate an app-specific password at appleid.apple.com → Sign-In and
   Security → App-Specific Passwords.
2. Store it in keychain:
   ```
   xcrun notarytool store-credentials "KeyWidget-notary" \
     --apple-id cypherz@mac.com \
     --team-id YQ3SK8SPJU \
     --password <app-specific-pw>
   ```
3. The script reads the profile name from `$NOTARY_PROFILE` (default
   `KeyWidget-notary`).

The app-specific password is stored only in the macOS keychain. Never
commit it; the file `notarytoolKeyWidget` and any `*notary*` file is
gitignored.

## Instructions for recipients (notarized DMG)

> 1. Download the `.dmg`, double-click to open it.
> 2. Drag **KeyWidget** to the **Applications** folder.
> 3. Launch from Applications. Done.

If macOS still complains (e.g. an old ad-hoc copy was previously
installed and quarantined): `xattr -dr com.apple.quarantine
/Applications/KeyWidget.app`.

## Feedback

Ask testers to note the **build number** shown in About → KeyWidget (or
in the DMG filename) when reporting issues, so we know which version
they're on.
