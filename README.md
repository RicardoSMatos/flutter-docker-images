# flutter-docker-images

Ready-to-use Docker images with the [Flutter](https://flutter.dev) SDK preinstalled and
its artifacts precached, published to GitHub Container Registry.

Built after [`cirruslabs/docker-images-flutter`](https://github.com/cirruslabs/docker-images-flutter)
stopped publishing new images. Nothing here is project-specific — pull it and use it.

```dockerfile
FROM ghcr.io/ricardosmatos/flutter:3.44.8 AS build
WORKDIR /app
COPY . .
RUN flutter pub get && flutter build web --release
```

```yaml
# GitLab CI / GitHub Actions container
image: ghcr.io/ricardosmatos/flutter:3.44.8
script:
  - flutter pub get
  - flutter analyze
```

The packages are public — no `docker login` needed to pull.

## Tags

| Tag | Contents | Platforms |
| --- | --- | --- |
| `ghcr.io/ricardosmatos/flutter:<x.y.z>` | Flutter SDK, web + Linux desktop artifacts precached | `linux/amd64`, `linux/arm64` |
| `…:<x.y>` | alias for the newest patch of that minor | `linux/amd64`, `linux/arm64` |
| `…:stable`, `…:latest` | newest stable tracked here | `linux/amd64`, `linux/arm64` |
| `…:<x.y.z>-android`, `…:<x.y>-android`, `…:stable-android`, `…:latest-android` | the above **+ JDK 17 + Android SDK** (platform 35, build-tools 35.0.0, licenses accepted) | `linux/amd64` |

`arm64` images are built on native ARM runners, not emulated.

The Android SDK does not ship `platform-tools` for `linux/arm64`, so the
`-android` variant is `amd64` only.

## What's inside

Base image is `debian:bookworm-slim`.

| Path / var | Value |
| --- | --- |
| `FLUTTER_ROOT`, `FLUTTER_HOME` | `/opt/flutter` |
| `PUB_CACHE` | `/opt/pub-cache` |
| `ANDROID_SDK_ROOT`, `ANDROID_HOME` (`-android`) | `/opt/android-sdk` |
| `JAVA_HOME` (`-android`) | `/usr/lib/jvm/java-17-openjdk-amd64` |

`flutter precache --universal --web` has already run, so `flutter build web`
downloads nothing at job time. Analytics are disabled and
`git config --global --add safe.directory '*'` is set, so CI checkouts owned by
a different uid don't trip git's ownership check.

### Why not Alpine

The Dart SDK distributed by Google is linked against glibc and there is no
official musl build, so Flutter cannot run on Alpine without a glibc shim that
fails in subtle ways. `debian:bookworm-slim` is the smallest base that stays on
a supported path.

## Adding a version

Add an entry to [`versions.json`](versions.json) and merge to `main`:

```json
{ "version": "3.45.0", "aliases": ["3.45", "stable", "latest"] }
```

Move `stable`/`latest` off the previous entry — every alias must appear exactly
once. The `watch-stable` workflow does this automatically once a week by
opening a PR when a new Flutter stable is released.

To build a one-off version without touching `versions.json`, run the `build`
workflow manually with a `flutter_version` input; it publishes only that exact
version tag.

## Building locally

```bash
docker buildx build --target base --build-arg FLUTTER_VERSION=3.44.8 -t flutter:local .
docker run --rm flutter:local flutter --version
```

## License

MIT — see [LICENSE](LICENSE). Flutter, Dart and the Android SDK are distributed
under their own licenses.
