# syntax=docker/dockerfile:1
#
# Flutter SDK images — https://github.com/RicardoSMatos/flutter-docker-images
#
# Two build targets:
#   base    → Flutter SDK + web/linux artifacts precached   (linux/amd64, linux/arm64)
#   android → base + JDK 17 + Android SDK, licenses accepted (linux/amd64 only)
#
# Why Debian and not Alpine: the Dart SDK shipped by Google is built against
# glibc and there is no official musl build, so Flutter cannot run on Alpine
# without a glibc shim that breaks in subtle ways. `debian:bookworm-slim` is
# the smallest base that stays officially supported.

# =============================================================================
# base — Flutter SDK, ready for `flutter analyze` / `test` / `build web`
# =============================================================================
FROM debian:bookworm-slim AS base

# Exact Flutter tag to check out, e.g. "3.44.8". Required.
ARG FLUTTER_VERSION

ENV FLUTTER_HOME=/opt/flutter \
    FLUTTER_ROOT=/opt/flutter \
    PUB_CACHE=/opt/pub-cache \
    DEBIAN_FRONTEND=noninteractive
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PUB_CACHE}/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        file \
        git \
        libglu1-mesa \
        unzip \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/*

# CI runners check out the repo as a different uid than the image user, and the
# `flutter` tool shells out to git inside its own SDK clone — both need this.
RUN git config --global --add safe.directory '*'

# Shallow clone of the exact tag: this is the expensive step that CI jobs
# would otherwise repeat on every run. `.git` is kept because the flutter tool
# reads its own version from it.
RUN test -n "${FLUTTER_VERSION}" \
    && git clone --depth 1 --branch "${FLUTTER_VERSION}" \
        https://github.com/flutter/flutter.git "${FLUTTER_HOME}"

# Materialize the Dart SDK, dart2js/dart2wasm and CanvasKit into the layer so
# no artifact download happens at job time.
RUN flutter --disable-analytics \
    && dart --disable-analytics \
    && flutter precache --universal --web \
    && flutter doctor -v

WORKDIR /workspace
CMD ["flutter", "doctor", "-v"]

# =============================================================================
# android — base + Android toolchain (amd64 only: the Android SDK does not
# publish linux-arm64 platform-tools)
# =============================================================================
FROM base AS android

# https://developer.android.com/studio#command-line-tools-only
ARG ANDROID_CMDLINE_TOOLS_VERSION=13114758
ARG ANDROID_PLATFORM_VERSION=35
ARG ANDROID_BUILD_TOOLS_VERSION=35.0.0

ENV ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_HOME=/opt/android-sdk \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${JAVA_HOME}/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends openjdk-17-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools" \
    && curl -fsSL -o /tmp/cmdline-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
    && unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_SDK_ROOT}/cmdline-tools" \
    && mv "${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools" "${ANDROID_SDK_ROOT}/cmdline-tools/latest" \
    && rm /tmp/cmdline-tools.zip

RUN yes | sdkmanager --licenses > /dev/null \
    && sdkmanager --install \
        "platform-tools" \
        "platforms;android-${ANDROID_PLATFORM_VERSION}" \
        "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
    && yes | flutter doctor --android-licenses > /dev/null \
    && flutter precache --android \
    && flutter doctor -v
