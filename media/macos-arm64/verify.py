"""Exercise the built command-line tools without external media fixtures."""
import binascii
import json
import pathlib
import struct
import subprocess
import sys
import zlib

tools, scratch = map(pathlib.Path, sys.argv[1:])
scratch.mkdir(parents=True, exist_ok=True)


def chunk(kind, data):
    checksum = binascii.crc32(kind + data) & 0xFFFFFFFF
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', checksum)


def png(width, height, color):
    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    rows = (b'\x00' + bytes(color) * width) * height
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(rows, 1)) + chunk(b'IEND', b'')


def ffmpeg(*args, data=None):
    subprocess.run([tools / 'ffmpeg', '-hide_banner', '-v', 'error', '-xerror', '-y', *args],
                   input=data, check=True)


def probe(media):
    raw = subprocess.check_output([tools / 'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', media])
    return json.loads(raw)


for width, height, fps, count in [(1920, 1080, 30, 90), (3840, 2160, 60, 12)]:
    video = scratch / f'capture-{width}.mp4'
    frames = [png(width, height, (170, 45, 40)), png(width, height, (45, 78, 170))]
    ffmpeg('-f', 'image2pipe', '-framerate', str(fps), '-vcodec', 'png', '-i', 'pipe:0', '-an',
           '-c:v', 'libx264', '-preset', 'fast', '-crf', '18',
           '-vf', 'scale=out_color_matrix=bt709:out_range=tv,format=yuv420p',
           '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709', '-color_range', 'tv',
           '-r', str(fps), '-fps_mode', 'cfr', '-movflags', '+faststart', video,
           data=b''.join(frames[i % 2] for i in range(count)))
    result = probe(video)
    assert len(result['streams']) == 1
    stream = result['streams'][0]
    assert (stream['codec_name'], stream['pix_fmt'], stream['color_space']) == ('h264', 'yuv420p', 'bt709')
    assert (stream['width'], stream['height'], int(stream['nb_frames'])) == (width, height, count)
    assert stream['avg_frame_rate'] == f'{fps}/1'
    assert abs(float(result['format']['duration']) - count / fps) < 1 / fps
    ffmpeg('-i', video, '-f', 'null', '-')
    print(f'{width}x{height}: encoded, probed and decoded {count} H.264 frames at {fps} fps.')

sheet = scratch / 'contact-sheet.jpg'
select = '+'.join('eq(n\\,' + str(n) + ')' for n in (0, 2, 4, 7, 9, 11))
ffmpeg('-i', video, '-vf', f'select={select},scale=640:360,tile=3x2', '-frames:v', '1', sheet)
sheet_stream = probe(sheet)['streams'][0]
assert (sheet_stream['codec_name'], sheet_stream['width'], sheet_stream['height']) == ('mjpeg', 1920, 720)
preview = scratch / 'preview-1080p.mp4'
ffmpeg('-i', video, '-vf', "scale=w='min(1920,iw)':h=-2:flags=lanczos", '-c:v', 'libx264', '-preset', 'fast',
       '-crf', '20', '-pix_fmt', 'yuv420p', '-an', '-movflags', '+faststart', preview)
ffmpeg('-i', preview, '-f', 'null', '-')
preview_stream = probe(preview)['streams'][0]
assert (preview_stream['width'], preview_stream['height']) == (1920, 1080)
print('JPEG contact sheet and 1080p H.264 preview verified.')
