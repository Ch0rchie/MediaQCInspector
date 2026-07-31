#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Media QC Inspector - FFmpeg release build script
#
# Builds standalone ffmpeg + ffprobe for macOS and stages only the final
# binaries into ThirdParty/FFmpeg/.
#
# Temporary build artifacts live outside ThirdParty so Xcode will never try
# to package them.
# -----------------------------------------------------------------------------

FFMPEG_VERSION="${FFMPEG_VERSION:-8.1.2}"
MIN_MACOS="${MIN_MACOS:-14.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}"

if [[ ! -f "${ROOT_DIR}/ProResQCInspector.xcodeproj/project.pbxproj" ]]; then
    echo "error: Run this script from the project root."
    exit 1
fi

OUTPUT_DIR="${ROOT_DIR}/ThirdParty/FFmpeg"
WORK_ROOT="${ROOT_DIR}/Build/FFmpeg"
BUILD_DIR="${WORK_ROOT}/ffmpeg-${FFMPEG_VERSION}"
ARCHIVE_DIR="${BUILD_DIR}/archives"
SRC_DIR="${BUILD_DIR}/src"
PREFIX_DIR="${BUILD_DIR}/prefix"

TARBALL="ffmpeg-${FFMPEG_VERSION}.tar.xz"
SIGFILE="${TARBALL}.asc"
SOURCE_URL="https://ffmpeg.org/releases/${TARBALL}"

mkdir -p "${ARCHIVE_DIR}" "${SRC_DIR}" "${PREFIX_DIR}" "${OUTPUT_DIR}"

echo "==> Cleaning previous staged binaries"
rm -f "${OUTPUT_DIR}/ffmpeg" "${OUTPUT_DIR}/ffprobe" "${OUTPUT_DIR}/VERSION"

echo "==> Cleaning previous build workspace"
rm -rf "${BUILD_DIR}"
mkdir -p "${ARCHIVE_DIR}" "${SRC_DIR}" "${PREFIX_DIR}"

echo "==> Downloading FFmpeg ${FFMPEG_VERSION}"
cd "${ARCHIVE_DIR}"
curl -fL --retry 3 -o "${TARBALL}" "${SOURCE_URL}"
curl -fL --retry 3 -o "${SIGFILE}" "${SOURCE_URL}.asc"

echo "==> Verifying release signature (optional)"
if command -v gpg >/dev/null 2>&1; then
    if ! gpg --list-keys "FFmpeg release signing key" >/dev/null 2>&1; then
        echo "warning: FFmpeg release signing key not found locally; skipping import"
        echo "warning: you can import it manually if you want signature verification"
    fi
    if gpg --verify "${SIGFILE}" "${TARBALL}" >/dev/null 2>&1; then
        echo "==> Signature verified"
    else
        echo "warning: signature verification skipped or failed; continuing"
    fi
else
    echo "warning: gpg not found; skipping signature verification"
fi

echo "==> Extracting source"
tar -xJf "${TARBALL}" -C "${SRC_DIR}" --strip-components=1

echo "==> Preparing build environment"
unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LIBRARY_PATH CPATH SDKROOT PKG_CONFIG_PATH PKG_CONFIG_LIBDIR
export MACOSX_DEPLOYMENT_TARGET="${MIN_MACOS}"

SDKROOT_PATH="$(xcrun --sdk macosx --show-sdk-path)"
EXTRA_CFLAGS="-O2 -pipe -mmacosx-version-min=${MIN_MACOS} -isysroot ${SDKROOT_PATH}"
EXTRA_LDFLAGS="-mmacosx-version-min=${MIN_MACOS} -isysroot ${SDKROOT_PATH}"

echo "==> Configuring"
cd "${SRC_DIR}"
./configure \
    --prefix="${PREFIX_DIR}" \
    --disable-debug \
    --disable-doc \
    --disable-ffplay \
    --disable-shared \
    --enable-static \
    --enable-pic \
    --enable-ffmpeg \
    --enable-ffprobe \
    --extra-cflags="${EXTRA_CFLAGS}" \
    --extra-ldflags="${EXTRA_LDFLAGS}"

echo "==> Building"
make -j"$(sysctl -n hw.ncpu)"

echo "==> Installing"
make install

echo "==> Staging final binaries"
install -m 755 "${PREFIX_DIR}/bin/ffmpeg" "${OUTPUT_DIR}/ffmpeg"
install -m 755 "${PREFIX_DIR}/bin/ffprobe" "${OUTPUT_DIR}/ffprobe"

echo "==> Removing metadata"
xattr -cr "${OUTPUT_DIR}/ffmpeg" "${OUTPUT_DIR}/ffprobe" || true

echo "==> Writing version file"
{
    echo "ffmpeg: $("${OUTPUT_DIR}/ffmpeg" -version | head -n 1)"
    echo "ffprobe: $("${OUTPUT_DIR}/ffprobe" -version | head -n 1)"
} > "${OUTPUT_DIR}/VERSION"

echo "==> Stripping binaries"
xcrun strip -x "${OUTPUT_DIR}/ffmpeg" "${OUTPUT_DIR}/ffprobe" || true

echo "==> Verifying Homebrew dependency paths are absent"
if otool -L "${OUTPUT_DIR}/ffmpeg" | grep -E '/opt/homebrew|/usr/local/Cellar|/usr/local/opt' >/dev/null; then
    echo "error: ffmpeg still links against Homebrew paths"
    exit 1
fi

if otool -L "${OUTPUT_DIR}/ffprobe" | grep -E '/opt/homebrew|/usr/local/Cellar|/usr/local/opt' >/dev/null; then
    echo "error: ffprobe still links against Homebrew paths"
    exit 1
fi

echo "==> Final check"
file "${OUTPUT_DIR}/ffmpeg"
file "${OUTPUT_DIR}/ffprobe"
cat "${OUTPUT_DIR}/VERSION"

echo "Done. Release binaries are staged in ThirdParty/FFmpeg/"