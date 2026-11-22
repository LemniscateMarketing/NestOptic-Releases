#!/usr/bin/env bash
set -euo pipefail

# Build FFmpeg and ffprobe as separate, standalone tools for Apple silicon.
here=$(cd "$(dirname "$0")" && pwd)
build_root=${1:?Supply a new directory for the build}
mkdir -p "$build_root"
build_root=$(cd "$build_root" && pwd)
[[ $(uname -sm) == 'Darwin arm64' && ! -e "$build_root/build" ]]
export MACOSX_DEPLOYMENT_TARGET=13.0
export SDKROOT
SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export GIT_CEILING_DIRECTORIES="$build_root"
export ZERO_AR_DATE=1
jobs=$(sysctl -n hw.logicalcpu)
archive_dir="$build_root/sources/archives"
work="$build_root/build"
prefix="$work/prefix"
product="$build_root/media"
licenses="$product/licenses"
mkdir -p "$work/ffmpeg" "$work/x264" "$prefix" "$archive_dir" "$product/bin" "$licenses" "$build_root/artifacts"

fetch_source() {
  local name=$1 url=$2 expected=$3
  if [[ -f "$here/archives/$name" ]]; then
    cp "$here/archives/$name" "$archive_dir/$name"
  else
    curl -fsSL --retry 3 "$url" -o "$archive_dir/$name"
  fi
  local actual
  actual=$(shasum -a 256 "$archive_dir/$name" | awk '{print $1}')
  [[ "$actual" == "$expected" ]] || { echo "Checksum mismatch: $name" >&2; exit 1; }
}

fetch_source ffmpeg-n8.1.2.tar.gz \
  https://codeload.github.com/FFmpeg/FFmpeg/tar.gz/refs/tags/n8.1.2 \
  9fd092511605bbebafe095ea6d38d9e40f34d12f7386e1258372df8be0576eb7
fetch_source x264-b35605ac.tar.gz \
  https://code.videolan.org/videolan/x264/-/archive/b35605ace3ddf7c1a5d67a2eb553f034aef41d55/x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.gz \
  cd71a7515b0e9a012e1ac9b1f8415bebcaf6fc97d4db32286642ac4c0fbe24f9
tar -xzf "$archive_dir/ffmpeg-n8.1.2.tar.gz" -C "$work/ffmpeg" --strip-components=1
tar -xzf "$archive_dir/x264-b35605ac.tar.gz" -C "$work/x264" --strip-components=1

(
  cd "$work/x264"
  ./configure --prefix="$prefix" --enable-static --enable-pic --disable-cli \
    --disable-opencl --disable-avs --disable-swscale --disable-lavf --disable-ffms \
    --disable-gpac --disable-lsmash --bit-depth=8 --chroma-format=420
  make -j"$jobs"
  make install
)
(
  cd "$work/ffmpeg"
  # Restrict external libraries to the locally built static x264 and Apple's zlib.
  export PKG_CONFIG_PATH=
  export PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig"
  ./configure --prefix="$prefix" --disable-everything --disable-autodetect \
    --disable-network --disable-debug --disable-doc --disable-avdevice --disable-ffplay \
    --enable-static --disable-shared --enable-gpl --enable-libx264 --enable-zlib \
    --enable-ffmpeg --enable-ffprobe --enable-protocol=file,pipe \
    --enable-demuxer=mov,image2,image2pipe --enable-muxer=mp4,null,image2 \
    --enable-parser=h264,png,mjpeg --enable-decoder=h264,png,mjpeg \
    --enable-encoder=libx264,mjpeg,png,wrapped_avframe \
    --enable-filter=scale,format,select,tile,null
  make -j"$jobs" ffmpeg ffprobe
  install -m 755 ffmpeg ffprobe "$product/bin/"
  cp COPYING.GPLv2 LICENSE.md "$licenses/"
)
cp "$work/x264/COPYING" "$licenses/x264-COPYING"
cp "$here/README.md" "$licenses/THIRD-PARTY-MEDIA.md"
cp "$here/build.sh" "$here/verify.py" "$here/README.md" "$build_root/sources/"
cp -R "$licenses" "$build_root/sources/licenses"
for tool in "$product/bin/ffmpeg" "$product/bin/ffprobe"; do
  [[ $(lipo -archs "$tool") == 'arm64' ]]
  otool -L "$tool"
  if otool -L "$tool" | tail -n +2 | awk '{print $1}' | grep -Ev '^(/usr/lib/|/System/Library/)'; then
    echo 'Unexpected non-system dynamic dependency.' >&2
    exit 1
  fi
done
python3 "$here/verify.py" "$product/bin" "$work/smoke"
tar -czf "$build_root/artifacts/Media-tools-macOS-arm64.tar.gz" -C "$product" bin licenses
tar -czf "$build_root/artifacts/NestOptic-Companion-0.1.1-media-corresponding-source.tar.gz" -C "$build_root/sources" .
(cd "$build_root/artifacts" && shasum -a 256 *.tar.gz > SHA256SUMS.txt)
