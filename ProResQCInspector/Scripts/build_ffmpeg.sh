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
KEEP_BUILD="${KEEP_BUILD:-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
[[ -f "${ROOT_DIR}/ProResQCInspector.xcodeproj/project.pbxproj" ]] || { echo "Run from Scripts/"; exit 1; }
OUTPUT_DIR="${ROOT_DIR}/ThirdParty/FFmpeg"
WORK_ROOT="${ROOT_DIR}/Build/FFmpeg"
BUILD_DIR="${WORK_ROOT}/ffmpeg-${FFMPEG_VERSION}"
ARCHIVE_DIR="${BUILD_DIR}/archives"
SRC_DIR="${BUILD_DIR}/src"
PREFIX_DIR="${BUILD_DIR}/prefix"
rm -rf "$BUILD_DIR"
mkdir -p "$ARCHIVE_DIR" "$SRC_DIR" "$PREFIX_DIR" "$OUTPUT_DIR"
URL="https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
cd "$ARCHIVE_DIR"
curl -L --fail --retry 3 -o ffmpeg.tar.xz "$URL"
tar -xf ffmpeg.tar.xz -C "$SRC_DIR" --strip-components=1
unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LIBRARY_PATH CPATH SDKROOT PKG_CONFIG_PATH PKG_CONFIG_LIBDIR
export MACOSX_DEPLOYMENT_TARGET="$MIN_MACOS"
SDKROOT_PATH="$(xcrun --sdk macosx --show-sdk-path)"
cd "$SRC_DIR"
./configure --prefix="$PREFIX_DIR" --disable-debug --disable-doc --disable-ffplay --disable-shared --enable-static --enable-pic --enable-ffmpeg --enable-ffprobe --extra-cflags="-O2 -mmacosx-version-min=${MIN_MACOS} -isysroot ${SDKROOT_PATH}" --extra-ldflags="-mmacosx-version-min=${MIN_MACOS} -isysroot ${SDKROOT_PATH}"
make -j"$(sysctl -n hw.ncpu)"
make install
install -m 755 "$PREFIX_DIR/bin/ffmpeg" "$OUTPUT_DIR/ffmpeg"
install -m 755 "$PREFIX_DIR/bin/ffprobe" "$OUTPUT_DIR/ffprobe"
xattr -cr "$OUTPUT_DIR/ffmpeg" "$OUTPUT_DIR/ffprobe" || true
xcrun strip -x "$OUTPUT_DIR/ffmpeg" "$OUTPUT_DIR/ffprobe" || true
{
echo "ffmpeg: $("$OUTPUT_DIR/ffmpeg" -version | head -1)"
echo "ffprobe: $("$OUTPUT_DIR/ffprobe" -version | head -1)"
} > "$OUTPUT_DIR/VERSION"
for BIN in ffmpeg ffprobe; do
otool -L "$OUTPUT_DIR/$BIN" | grep -E '/opt/homebrew|/usr/local/Cellar|/usr/local/opt' && { echo "Homebrew dependency detected"; exit 1; } || true
done
if [[ "$KEEP_BUILD" != "1" ]]; then
rm -rf "$WORK_ROOT"
fi
echo "Done."
