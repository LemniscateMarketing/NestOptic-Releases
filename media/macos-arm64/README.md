# NestOptic Companion 0.1.1 media tools for Apple silicon

The separate FFmpeg and ffprobe command-line programs use FFmpeg 8.1.2 and the x264 H.264 encoder at commit `b35605ace3ddf7c1a5d67a2eb553f034aef41d55`. This build statically links x264 and enables FFmpeg's GPL components. FFmpeg and x264 are distributed under the GNU General Public License, version 2 or later. Apple's system libraries, including zlib, are resolved on the recipient's Mac. The enclosed upstream license files contain the copyright and license texts. The upstream source archives are unmodified. The build recipe selects the codecs, protocols and filters.

Download `NestOptic-Companion-0.1.1-media-corresponding-source.tar.gz` from the same release as the installer at [NestOptic Releases](https://github.com/LemniscateMarketing/NestOptic-Releases/releases). It contains both original source archives, their verification hashes in the build script, the exact configuration, license documents and the build verification script. These are the preferred source forms for the distributed media tools.

To reproduce the tools, unpack the source archive on an Apple silicon Mac with the Xcode Command Line Tools, Python 3, pkg-config and Bash available. Run `bash build.sh "$PWD/../media-build"` from the unpacked directory, using a new output directory. The build uses the supplied archives and the macOS system SDK, checks the Mach-O dependencies, and exercises encoding, decoding, probing, preview generation and a contact sheet. The outputs under `media-build/media` precede the distributor's separate Apple signing step.

- [FFmpeg source at n8.1.2](https://github.com/FFmpeg/FFmpeg/tree/n8.1.2)
- [x264 source at b35605ac](https://code.videolan.org/videolan/x264/-/tree/b35605ace3ddf7c1a5d67a2eb553f034aef41d55)
- [FFmpeg licensing](https://ffmpeg.org/legal.html)
- [x264 project and licensing](https://www.videolan.org/developers/x264.html)
