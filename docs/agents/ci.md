<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## CI

`.github/workflows/android.yml` runs on push to `main` (and on demand from the
Actions tab): tests, then the APK, then Firebase App Distribution. The suite
gates it -- the job stops on a non-zero failure count before anything reaches
a phone. Each run stamps `version/code` with the run number so two builds are
never the same version.

Two repo secrets feed it, and the build says so when one is missing:

- `ANDROID_DEBUG_KEYSTORE` -- base64 of `~/.android/debug.keystore`. It must
  be *that* key: Android will not install a build over one signed differently.
- `ANALYTICS_API_SECRET` -- the GA4 Measurement Protocol secret. Absent, the
  build warns and reports nothing.

App Distribution itself needs no secret. The organisation the Firebase project
sits in forbids service-account keys, so the run signs in to Google keylessly
(Workload Identity Federation): the job's `id-token` is exchanged for the
`app-distribution` service account through the `github` identity pool, and
only runs from this repository are allowed to. `tools/ci_identity.sh` is the
one-time setup on the Google side; a failed sign-in fails the job rather than
warning, because there is no longer a missing secret to excuse it.

CI gets its Android SDK path into Godot by appending to the editor settings
file that `--import` generates, rather than writing one by hand; the appended
keys win over the defaults above them.
