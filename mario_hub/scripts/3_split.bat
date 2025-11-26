@echo off
setlocal enabledelayedexpansion

rem 设置 4GB 的文件大小限制 (4 * 1024 * 1024 * 1024)
set max_size=4294967296

rem 遍历 output 目录下的所有 .mp4 文件
for %%f in (output\*.mp4) do (
    rem 获取文件的大小
    for %%A in (%%f) do set size=%%~zA

    rem 打印文件的大小
    echo "File %%f has size: !size! bytes"

    rem 判断文件是否超过 4GB
    if !size! geq %max_size% (
        rem 文件超过 4GB，进行分割
        echo "File %%f is larger than 4GB, splitting into smaller parts..."
        ffmpeg -i "%%f" -c copy -map 0 -segment_time 3600 -f segment "output\%%~nf_part%%03d.mp4"
    ) else (
        rem 文件小于 4GB，不需要分割
        echo "File %%f is under 4GB, no splitting needed."
    )
)