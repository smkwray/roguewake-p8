#!/usr/bin/env bash
# One-time setup: install emsdk and clone/patch FAKE-08 for the web build.
# Idempotent — safe to re-run.
set -euo pipefail

BUILD="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$BUILD/.." && pwd)"

# 1. emsdk
if [ ! -d "$BUILD/emsdk" ]; then
  echo "[bootstrap] installing emsdk..."
  git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$BUILD/emsdk"
  ( cd "$BUILD/emsdk" && ./emsdk install latest && ./emsdk activate latest )
else
  echo "[bootstrap] emsdk already installed"
fi

# 2. FAKE-08 + submodules
if [ ! -d "$BUILD/fake-08" ]; then
  echo "[bootstrap] cloning fake-08..."
  git clone --depth 1 https://github.com/jtothebell/fake-08.git "$BUILD/fake-08"
  ( cd "$BUILD/fake-08" && git submodule update --init --recursive )
else
  echo "[bootstrap] fake-08 already present"
fi

# 3. Apply patches (only if not already applied — detect via marker string)
cd "$BUILD/fake-08"
if ! grep -q "emscripten_step" source/main.cpp; then
  echo "[bootstrap] applying main.cpp patch..."
  git apply "$BUILD/patches/main.cpp.patch"
else
  echo "[bootstrap] main.cpp patch already applied"
fi
if ! grep -q "SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_EVENTS" platform/SDL2Common/source/sdl2basehost.cpp; then
  echo "[bootstrap] applying sdl2basehost.cpp patch..."
  git apply "$BUILD/patches/sdl2basehost.cpp.patch"
else
  echo "[bootstrap] sdl2basehost patch already applied"
fi

echo "[bootstrap] done. Run ./build/build_web.sh to build."
