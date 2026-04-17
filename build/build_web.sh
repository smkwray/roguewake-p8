#!/usr/bin/env bash
set -euo pipefail

# Build FAKE-08 for web (emscripten / WASM).
# Output goes into docs/web/ so GitHub Pages can serve it.

BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$BUILD_DIR/.." && pwd)"
FAKE08="$PROJ/build/fake-08"
OUT="$PROJ/docs/web"
CART_SRC="$PROJ/cart/rogue_wake.p8"

# Activate emsdk
source "$PROJ/build/emsdk/emsdk_env.sh" >/dev/null 2>&1

mkdir -p "$OUT"

# Keep a fresh copy of the cart staged inside fake-08 for --preload-file.
mkdir -p "$FAKE08/carts"
cp "$CART_SRC" "$FAKE08/carts/rogue_wake.p8"

cd "$FAKE08"

# Source file lists
CPP_SOURCES=(
  source/Audio.cpp
  source/cart.cpp
  source/emojiconversion.cpp
  source/filehelpers.cpp
  source/filter.cpp
  source/fontdata.cpp
  source/graphics.cpp
  source/hostCommonFunctions.cpp
  source/Input.cpp
  source/logger.cpp
  source/main.cpp
  source/mathhelpers.cpp
  source/nibblehelpers.cpp
  source/picoluaapi.cpp
  source/printHelper.cpp
  source/stringToDataHelpers.cpp
  source/synth.cpp
  source/vm.cpp
  platform/SDL2Common/source/sdl2basehost.cpp
  platform/SDL2Desktop/source/SDL2Host.cpp
  libs/lodepng/lodepng.cpp
)

C_SOURCES=(
  libs/miniz/miniz.c
  libs/simpleini/ConvertUTF.c
)

# All z8lua .c files
for f in libs/z8lua/*.c; do
  C_SOURCES+=("$f")
done

em++ \
  -O3 \
  -std=c++17 \
  -fno-rtti \
  -Isource \
  -Ilibs/z8lua \
  -Ilibs/lodepng \
  -Ilibs/miniz \
  -Ilibs/simpleini \
  -sUSE_SDL=2 \
  -sALLOW_MEMORY_GROWTH=1 \
  -sINITIAL_MEMORY=67108864 \
  -sSTACK_SIZE=16777216 \
  -sEXIT_RUNTIME=0 \
  -sNO_DISABLE_EXCEPTION_CATCHING \
  --preload-file carts/rogue_wake.p8@/rogue_wake.p8 \
  --shell-file "$PROJ/build/web_shell.html" \
  "${CPP_SOURCES[@]}" \
  "${C_SOURCES[@]}" \
  -o "$OUT/index.html"

echo ""
# Normalize the baked package path so it matches the runtime fetch URL.
perl -i -pe 's{/[^"]*/(index\.data)}{$1}g' "$OUT/index.js"

echo "Built: $OUT/index.html (+ .js, .wasm, .data)"
ls -la "$OUT/"
