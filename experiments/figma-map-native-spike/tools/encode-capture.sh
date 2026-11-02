#!/bin/sh
set -eu
DIR=$1
# Encode only actual recorded screenshots, no interpolation/synthetic frames.
ffmpeg -hide_banner -loglevel error -framerate 10 -i "$DIR/frames/%04d.png" -vf 'scale=1280:-2:flags=lanczos' -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart "$DIR/host-sample.mp4"
ffmpeg -hide_banner -loglevel error -framerate 10 -i "$DIR/frames/%04d.png" -filter_complex 'scale=960:-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=bayer:bayer_scale=4' -loop 0 "$DIR/host-sample.gif"
printf '%s\n' 'Actual Simulator software Host screenshots after explicit 0.1-second steps; event frames may share simulation timestamps. Encoded at 10 frames/s without interpolation. NOT official-device FPS or visual parity approval.' > "$DIR/video-scope.txt"
