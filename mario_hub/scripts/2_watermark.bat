@echo off
for %%f in (input\*.mp4) do (
    ffmpeg -i "%%f" -i watermark.png -filter_complex "[1]scale=iw*0.2:ih*0.2[wm];[0][wm]overlay=10:10" -c:v h264_qsv -c:a copy "output\preview_meta_%%~nf.mp4"
)
