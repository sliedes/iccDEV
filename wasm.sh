#!/bin/bash
#################################################################################
# iccDEV WASMBuild Script | iccDEV Project
# Copyright (C) 2025 - 2026 The International Color Consortium.
#                                        All rights reserved.
#
#  Last Updated: 2026-01-31 18:44:44 UTC by David Hoyt
#  INTENT: Update Build at Commit 6a37766
#
#  Testing: Verified Working on Ubuntu24 + WSL-2, XNU TODO
#
#  TODO:    Align Delta with main branch config | CMakeLists.txt Configs
#
#  Issues:  The WASM Build exposed LIB Linking issues TODO via PR on master
#           Missing Graphics Link directives need to be pusg to master branch
#
#  WASM BUILD STUB for CI-CD 
#
#
#################################################################################
set -e

# === Default Configuration ===
BUILD_TYPE="${1:-release}"
WORKSPACE_DIR="./wasm"
CLEAN_BUILD=false
ICCDEV_COMMIT="9206e0b8684e4cf4186d9ae768f16760bc1af9ff"

# === Parse Arguments ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      WORKSPACE_DIR="$2"
      shift 2
      ;;
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    --help|-h)
      head -n 40 "$0" | grep "^#" | sed 's/^# \?//'
      exit 0
      ;;
    release|debug|sanitizer|all)
      BUILD_TYPE="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Convert to absolute path
WORKSPACE_DIR=$(cd "$(dirname "$WORKSPACE_DIR")" 2>/dev/null && pwd)/$(basename "$WORKSPACE_DIR") || WORKSPACE_DIR="$(pwd)/wasm-build"

# === Validate Build Type ===
case "$BUILD_TYPE" in
  release|debug|sanitizer|all)
    ;;
  *)
    echo "ERROR: Invalid build type '$BUILD_TYPE'"
    echo "Valid options: release, debug, sanitizer, all"
    echo "Use --help for more information"
    exit 1
    ;;
esac

# === Helper Functions ===
print_section() {
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  $1"
  echo "═══════════════════════════════════════════════════════════════"
}

get_build_flags() {
  local build_type=$1
  local component=$2

  case "$build_type" in
    release)
      if [ "$component" = "compile" ]; then
        echo "-O3 -sUSE_ZLIB=1 -sUSE_LIBJPEG=1 -sUSE_LIBPNG=1"
      else
        echo "-O3 -sUSE_ZLIB=1 -sUSE_LIBJPEG=1 -sUSE_LIBPNG=1 -s INITIAL_MEMORY=128MB -s ALLOW_MEMORY_GROWTH=1 -s FORCE_FILESYSTEM=1 -s MODULARIZE=1 -s EXPORT_NAME=createModule -s EXPORTED_RUNTIME_METHODS=['FS','callMain']"
      fi
      ;;
    debug)
      if [ "$component" = "compile" ]; then
        echo "-g -O0 -sUSE_ZLIB=1 -sUSE_LIBJPEG=1 -sUSE_LIBPNG=1 -sASSERTIONS=2 -sSAFE_HEAP=1"
      else
        echo "-g -O0 -sUSE_ZLIB=1 -sUSE_LIBJPEG=1 -sUSE_LIBPNG=1 -sASSERTIONS=2 -sSAFE_HEAP=1 -s INITIAL_MEMORY=256MB -s ALLOW_MEMORY_GROWTH=1 -s FORCE_FILESYSTEM=1 -s MODULARIZE=1 -s EXPORT_NAME=createModule -s EXPORTED_RUNTIME_METHODS=['FS','callMain'] --source-map-base=./"
      fi
      ;;
    sanitizer)
      if [ "$component" = "compile" ]; then
        echo "-O1 -g -sUSE_ZLIB=1 -sUSE_LIBJPEG=1 -sUSE_LIBPNG=1 -sASSERTIONS=2 -sSAFE_HEAP=1 -sSTACK_OVERFLOW_CHECK=2"
      else
        echo "-O1 -g -sUSE_ZLIB=1 -sUSE_LIBJPEG=1 -sUSE_LIBPNG=1 -sASSERTIONS=2 -sSAFE_HEAP=1 -sSTACK_OVERFLOW_CHECK=2 -s INITIAL_MEMORY=256MB -s ALLOW_MEMORY_GROWTH=1 -s FORCE_FILESYSTEM=1 -s MODULARIZE=1 -s EXPORT_NAME=createModule -s EXPORTED_RUNTIME_METHODS=['FS','callMain']"
      fi
      ;;
  esac
}

get_cmake_build_type() {
  case "$1" in
    release) echo "Release" ;;
    debug) echo "Debug" ;;
    sanitizer) echo "RelWithDebInfo" ;;
  esac
}

build_single_config() {
  local config=$1

  print_section "Building iccDEV - $config configuration"

  EMSDK_DIR="${WORKSPACE_DIR}/emsdk"
  ICCDEV_DIR="${WORKSPACE_DIR}/iccDEV"
  BUILD_DIR="${ICCDEV_DIR}/Build-${config}"
  THIRD_PARTY_DIR="${ICCDEV_DIR}/Build/third_party"

  # === System Dependencies Check ===
  print_section "Checking System Dependencies"

  MISSING_DEPS=""
  for cmd in cmake make git curl autoconf automake pkg-config; do
    if ! command -v $cmd &> /dev/null; then
      MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
  done

  # Check for libtoolize (libtool package provides this)
  if ! command -v libtoolize &> /dev/null; then
    MISSING_DEPS="$MISSING_DEPS libtool"
  fi

  if [ -n "$MISSING_DEPS" ]; then
    echo "ERROR: Missing required tools:$MISSING_DEPS"
    echo ""
    echo "Install with:"
    echo "  sudo apt-get install -y cmake make git curl autoconf automake libtool pkg-config build-essential"
    exit 1
  fi

  echo "✓ All required tools found"

  # === Workspace Setup ===
  print_section "Setting up Portable Workspace"

  if [ "$CLEAN_BUILD" = true ] && [ -d "$WORKSPACE_DIR" ]; then
    echo "Cleaning workspace: $WORKSPACE_DIR"
    rm -rf "$WORKSPACE_DIR"
  fi

  mkdir -p "$WORKSPACE_DIR"
  echo "Workspace: $WORKSPACE_DIR"

  # === Emscripten SDK ===
  print_section "Setting up Emscripten SDK"

  if [ ! -d "$EMSDK_DIR" ]; then
    echo "Installing Emscripten SDK to workspace..."
    cd "$WORKSPACE_DIR"
    git clone --depth 1 https://github.com/emscripten-core/emsdk.git
    cd emsdk
    ./emsdk install latest
    ./emsdk activate latest
  else
    echo "Using existing Emscripten SDK in workspace"
  fi

  source "${EMSDK_DIR}/emsdk_env.sh"
  echo "✓ Emscripten $(emcc --version | head -n1)"

  # === Clone iccDEV ===
  print_section "Setting up iccDEV Source"

  if [ ! -d "$ICCDEV_DIR" ]; then
    echo "Cloning iccDEV to workspace..."
    cd "$WORKSPACE_DIR"
    git clone https://github.com/InternationalColorConsortium/iccDEV.git
    cd iccDEV
    echo "Checking out wasm-latest-6a37766 branch..."
    git checkout wasm-latest-6a37766
  else
    echo "Using existing iccDEV in workspace"
    cd "$ICCDEV_DIR"
  fi

  # === Third-Party Dependencies ===
  print_section "Checking Third-Party Dependencies"

  # Check which dependencies need building
  NEED_LIBTIFF=false
  NEED_LIBXML2=false
  NEED_JSON=false

  [ ! -f "${THIRD_PARTY_DIR}/libtiff/out/lib/libtiff.a" ] && NEED_LIBTIFF=true
  [ ! -f "${THIRD_PARTY_DIR}/libxml2/out/lib/libxml2.a" ] && NEED_LIBXML2=true
  [ ! -f "${THIRD_PARTY_DIR}/nlohmann_json/out/share/cmake/nlohmann_json/nlohmann_jsonConfig.cmake" ] && NEED_JSON=true

  if [ "$NEED_LIBTIFF" = false ] && [ "$NEED_LIBXML2" = false ] && [ "$NEED_JSON" = false ]; then
    echo "✓ All dependencies already built"
  else
    echo "Building missing dependencies..."
    [ "$NEED_LIBTIFF" = true ] && echo "  - libtiff"
    [ "$NEED_LIBXML2" = true ] && echo "  - libxml2"
    [ "$NEED_JSON" = true ] && echo "  - nlohmann_json"

    mkdir -p "$THIRD_PARTY_DIR"
    cd "$THIRD_PARTY_DIR"

    # Source emsdk environment
    source "${EMSDK_DIR}/emsdk_env.sh"

    # --- libtiff ---
    if [ "$NEED_LIBTIFF" = true ]; then
      echo "Building libtiff..."
      if [ ! -d "libtiff" ]; then
        git clone --depth 1 https://gitlab.com/libtiff/libtiff.git
      fi
      cd libtiff
      rm -rf wasm out
      mkdir wasm && cd wasm
      emcmake cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=../out \
        -DCMAKE_C_FLAGS="-O3 -sUSE_ZLIB=1 -sUSE_LIBJPEG=1 -DNDEBUG" \
        -DCMAKE_CXX_FLAGS="-O3 -sUSE_ZLIB=1 -sUSE_LIBJPEG=1 -DNDEBUG" \
        -DCMAKE_MODULE_PATH="${PWD}/../cmake" \
        -DBUILD_SHARED_LIBS=OFF \
        -Dtiff-tools=OFF \
        -Dtiff-tests=OFF \
        -Dtiff-contrib=OFF \
        -Dtiff-docs=OFF
      emmake make -j$(nproc)
      emmake make install
      cd ../..
      echo "✓ libtiff built"
    fi

    # --- libxml2 ---
    if [ "$NEED_LIBXML2" = true ]; then
      echo "Building libxml2..."
      if [ ! -d "libxml2" ]; then
        git clone --depth 1 https://gitlab.gnome.org/GNOME/libxml2.git
      fi
      cd libxml2
      rm -rf out
      CFLAGS="-O3" emconfigure ./autogen.sh \
        --without-python --disable-shared --enable-static --prefix=$(pwd)/out
      emmake make -j$(nproc)
      emmake make install
      cd ..
      echo "✓ libxml2 built"
    fi

    # --- nlohmann/json ---
    if [ "$NEED_JSON" = true ]; then
      echo "Building nlohmann_json..."
      if [ ! -d "nlohmann_json" ]; then
        git clone --depth 1 https://github.com/nlohmann/json.git nlohmann_json
      fi
      cd nlohmann_json
      rm -rf build out
      mkdir build && cd build
      emcmake cmake .. \
        -DCMAKE_INSTALL_PREFIX=$(pwd)/../out \
        -DJSON_BuildTests=OFF
      emmake make install
      cd ../..
      echo "✓ nlohmann_json built"
    fi
  fi

  # === Build iccDEV ===
  print_section "Configuring iccDEV - $config"

  cd "$ICCDEV_DIR"
  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"

  # Source emsdk environment
  source "${EMSDK_DIR}/emsdk_env.sh"

  # === Ensure Emscripten ports are installed ===
  echo "Installing Emscripten ports (zlib, libjpeg, libpng)..."
  embuilder build zlib libjpeg libpng --pic

  COMPILE_FLAGS=$(get_build_flags "$config" "compile")
  LINK_FLAGS=$(get_build_flags "$config" "link")
  CMAKE_BUILD_TYPE=$(get_cmake_build_type "$config")

  emcmake cmake ../Build/Cmake \
    -DCMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE \
    -DENABLE_TOOLS=ON \
    -DENABLE_STATIC_LIBS=ON \
    -DCMAKE_C_FLAGS="$COMPILE_FLAGS" \
    -DCMAKE_CXX_FLAGS="$COMPILE_FLAGS" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -Dnlohmann_json_DIR="${THIRD_PARTY_DIR}/nlohmann_json/out/share/cmake/nlohmann_json" \
    -DLIBXML2_INCLUDE_DIR="${THIRD_PARTY_DIR}/libxml2/out/include/libxml2" \
    -DLIBXML2_LIBRARY="${THIRD_PARTY_DIR}/libxml2/out/lib/libxml2.a" \
    -DTIFF_INCLUDE_DIR="${THIRD_PARTY_DIR}/libtiff/out/include" \
    -DTIFF_LIBRARY="${THIRD_PARTY_DIR}/libtiff/out/lib/libtiff.a" \
    -DJPEG_INCLUDE_DIR="${WORKSPACE_DIR}/emsdk/upstream/emscripten/cache/sysroot/include" \
    -DJPEG_LIBRARY="${WORKSPACE_DIR}/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/pic/libjpeg.a" \
    -DPNG_LIBRARY="${WORKSPACE_DIR}/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/pic/libpng.a" \
    -DPNG_PNG_INCLUDE_DIR="${WORKSPACE_DIR}/emsdk/upstream/emscripten/cache/sysroot/include" \
    -DZLIB_INCLUDE_DIR="${WORKSPACE_DIR}/emsdk/upstream/emscripten/cache/sysroot/include" \
    -DZLIB_LIBRARY="${WORKSPACE_DIR}/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/pic/libz.a" \
    -DCMAKE_EXE_LINKER_FLAGS="$LINK_FLAGS" \
    -Wno-dev

  print_section "Building iccDEV - $config"
  emmake make -j$(nproc)

  # === Build Summary ===
  print_section "Build Complete - $config"
  echo "Configuration: $config"
  echo "Build directory: $BUILD_DIR"
  echo ""
  echo "WASM Artifacts:"
  find ./Tools -type f \( -name '*.js' -o -name '*.wasm' \) 2>/dev/null | while read file; do
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    size_kb=$((size / 1024))
    printf "  %-50s %8d KB\n" "$(basename $file)" "$size_kb"
  done | sort -k2 -n

  # Save artifact list
  find ./Tools -type f \( -name '*.js' -o -name '*.wasm' \) -ls > "${BUILD_DIR}/artifacts.txt"
}

# === Main Execution ===
print_section "iccDEV WASM Portable Build"
echo "Build type: $BUILD_TYPE"
echo "Workspace:  $WORKSPACE_DIR"
echo ""

if [ "$BUILD_TYPE" = "all" ]; then
  for config in release debug sanitizer; do
    build_single_config "$config"
  done

  print_section "All Builds Complete"
  echo "Workspace: $WORKSPACE_DIR"
  echo ""
  echo "Build directories:"
  echo "  Release:    ${WORKSPACE_DIR}/iccDEV/Build-release"
  echo "  Debug:      ${WORKSPACE_DIR}/iccDEV/Build-debug"
  echo "  Sanitizer:  ${WORKSPACE_DIR}/iccDEV/Build-sanitizer"
else
  build_single_config "$BUILD_TYPE"
fi

print_section "SUCCESS"
echo "Build completed successfully!"
echo ""
echo "Workspace location: $WORKSPACE_DIR"
echo ""
echo "To use the built tools:"
if [ "$BUILD_TYPE" = "all" ]; then
  echo "  Release:    $WORKSPACE_DIR/iccDEV/Build-release/Tools/"
  echo "  Debug:      $WORKSPACE_DIR/iccDEV/Build-debug/Tools/"
  echo "  Sanitizer:  $WORKSPACE_DIR/iccDEV/Build-sanitizer/Tools/"
else
  echo "  $WORKSPACE_DIR/iccDEV/Build-${BUILD_TYPE}/Tools/"
fi
echo ""
echo "To clean up:"
echo "  rm -rf $WORKSPACE_DIR"
echo ""
find -type f \( -name '*.js' -o -name '*.wasm' \) -ls
