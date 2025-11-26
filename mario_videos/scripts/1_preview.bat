@echo off
setlocal enabledelayedexpansion

REM 设置参数
set INPUT_DIR=input
set OUTPUT_DIR=output
set WATERMARK=prewatermark.png
set PREVIEW_DURATION=180
set CLIP_DURATION=15
set LISTFILE=list.txt
set CLIP_DIR=list

REM 创建文件夹
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if not exist "%CLIP_DIR%" mkdir "%CLIP_DIR%"

REM 遍历 input 文件夹中的所有 .mp4 文件
for %%F in (%INPUT_DIR%\*.mp4) do (

    REM 获取每个视频文件的文件名和路径
    set INPUT=%%F
    set FILE_NAME=%%~nxF
    set OUTPUT=%OUTPUT_DIR%\preview_!FILE_NAME!

    REM 获取视频总时长（秒）
    for /f "tokens=*" %%a in ('ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "!INPUT!"') do set TOTAL_TIME=%%a
    set /a TOTAL_INT=!TOTAL_TIME!
    if "!TOTAL_INT!"=="0" (
        echo 无法获取总时长: !INPUT!
        pause
        exit /b
    )

    REM 计算采样片段数
    set /a COUNT=PREVIEW_DURATION / CLIP_DURATION

    REM 计算采样间隔（秒）
    set /a INTERVAL=TOTAL_INT / COUNT

    echo 处理文件: !INPUT!
    echo 采样片段总数: !COUNT!
    echo 每片段时长: !CLIP_DURATION! 秒
    echo 总时长: !TOTAL_INT! 秒
    echo 间隔: !INTERVAL! 秒

    REM 清理旧数据
    del "%LISTFILE%" 2>nul
    del /q "%CLIP_DIR%\*.mp4" 2>nul

    REM 第一次裁剪为前30分钟的30秒
    echo 裁剪前30分钟的30秒...
    ffmpeg -y -ss 00:00:00 -i "!INPUT!" -t 00:00:30 -vf "scale=w=iw:h=ih:force_original_aspect_ratio=decrease,fps=30" -c:v h264_qsv -preset veryfast -c:a copy "%CLIP_DIR%\clip_0.mp4"
    echo file '%CLIP_DIR%\clip_0.mp4' >> "%LISTFILE%"

    REM 之后每隔30分钟裁剪15秒
    echo 每隔30分钟裁剪15秒...
    for /l %%i in (1,1,!COUNT!) do (
        set /a BASE=%%i * INTERVAL
        set /a START=BASE

        REM 不超出视频范围
        if !START! lss !TOTAL_INT! (
            set FILE=%CLIP_DIR%\clip_%%i.mp4
            echo 采样片段: !FILE! @ !START! 秒

            REM 确保 START 不超出视频时长
            if !START! lss 30 (
                ffmpeg -y -ss !START! -i "!INPUT!" -t !CLIP_DURATION! -vf "scale=w=iw:h=ih:force_original_aspect_ratio=decrease,fps=30" -c:v h264_qsv -preset veryfast -c:a copy "!FILE!"
            ) else (
                ffmpeg -y -ss !START! -i "!INPUT!" -t !CLIP_DURATION! -vf "scale=w=iw:h=ih:force_original_aspect_ratio=decrease,fps=30" -c:v h264_qsv -preset veryfast -c:a copy "!FILE!"
            )

            echo file '!FILE!' >> "%LISTFILE%"
        )
    )

    REM 生成预览合并
    echo 正在生成预览视频...

    REM 合并片段并添加水印
    ffmpeg -y -f concat -safe 0 -i "%LISTFILE%" ^
    -vf "movie=%WATERMARK%[wm]; [0:v][wm]overlay=W-w:0:format=auto, format=yuv420p" ^
    -c:v h264_qsv -preset fast -c:a copy -copyts "!OUTPUT!"

    echo.
    echo ✅ 预览生成完成：!OUTPUT!
)