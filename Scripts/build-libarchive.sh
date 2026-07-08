#!/bin/bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
LIBARCHIVE_SOURCE_DIR="${PROJECT_DIR}/Vendor/libarchive"

if [ ! -f "${LIBARCHIVE_SOURCE_DIR}/CMakeLists.txt" ]; then
  echo "error: libarchive submodule is missing. Run: git submodule update --init --recursive" >&2
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "error: cmake is required to build embedded libarchive." >&2
  exit 1
fi

CONFIGURATION="${CONFIGURATION:-Debug}"
ARCHS="${ARCHS:-$(uname -m)}"
SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"

ARCHS_KEY="${ARCHS// /_}"
BUILD_ROOT="${TARGET_TEMP_DIR:-${PROJECT_DIR}/.build/libarchive}/libarchive"
BUILD_DIR="${BUILD_ROOT}/${CONFIGURATION}-${ARCHS_KEY}"
INSTALL_DIR="${BUILD_DIR}/install"

FRAMEWORKS_FOLDER_PATH="${FRAMEWORKS_FOLDER_PATH:-${FULL_PRODUCT_NAME:-AnademToys.app}/Contents/Frameworks}"
DESTINATION_DIR="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
DESTINATION_DYLIB="${DESTINATION_DIR}/libarchive.dylib"

cmake -S "${LIBARCHIVE_SOURCE_DIR}" -B "${BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE="${CONFIGURATION}" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_OSX_SYSROOT="${SDKROOT}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" \
  -DCMAKE_OSX_ARCHITECTURES="${ARCHS}" \
  -DCMAKE_INSTALL_NAME_DIR="@rpath" \
  -DBUILD_SHARED_LIBS=ON \
  -DENABLE_INSTALL=ON \
  -DENABLE_TEST=OFF \
  -DENABLE_CPIO=OFF \
  -DENABLE_TAR=OFF \
  -DENABLE_CAT=OFF \
  -DENABLE_OPENSSL=OFF \
  -DENABLE_MBEDTLS=OFF \
  -DENABLE_NETTLE=OFF \
  -DENABLE_ZLIB=ON \
  -DENABLE_BZip2=ON \
  -DENABLE_LZMA=ON \
  -DENABLE_ZSTD=ON \
  -DENABLE_LZ4=ON \
  -DENABLE_LIBXML2=ON \
  -DENABLE_EXPAT=ON

cmake --build "${BUILD_DIR}" --config "${CONFIGURATION}" --target install

mkdir -p "${DESTINATION_DIR}"
install -m 755 "${INSTALL_DIR}/lib/libarchive.dylib" "${DESTINATION_DYLIB}"
install_name_tool -id "@rpath/libarchive.dylib" "${DESTINATION_DYLIB}"

embed_non_system_dependencies() {
  local binary="$1"

  otool -L "${binary}" | awk 'NR > 1 { print $1 }' | while read -r dependency; do
    case "${dependency}" in
      ""|@rpath/*|@loader_path/*|@executable_path/*|/usr/lib/*|/System/*)
        continue
        ;;
    esac

    if [ ! -f "${dependency}" ]; then
      echo "error: dependency not found: ${dependency}" >&2
      exit 1
    fi

    local dependency_name
    dependency_name="$(basename "${dependency}")"
    local embedded_dependency="${DESTINATION_DIR}/${dependency_name}"

    if [ ! -f "${embedded_dependency}" ]; then
      install -m 755 "${dependency}" "${embedded_dependency}"
      install_name_tool -id "@rpath/${dependency_name}" "${embedded_dependency}"
      embed_non_system_dependencies "${embedded_dependency}"
    fi

    install_name_tool -change "${dependency}" "@rpath/${dependency_name}" "${binary}"
  done
}

embed_non_system_dependencies "${DESTINATION_DYLIB}"

echo "Embedded libarchive: ${DESTINATION_DYLIB}"
