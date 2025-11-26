@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ==========================================
:: CONFIG - Feishu Webhook
:: ==========================================
set FEISHU_WEBHOOK=https://open.feishu.cn/open-apis/bot/v2/hook/00ad23c8-951b-4f52-a1dd-1efee6a130aa
:: ==========================================

:: 日志文件
set timestamp=%date:~0,4%-%date:~5,2%-%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set timestamp=%timestamp: =0%
set LOG=logs\run_%timestamp%.log
if not exist logs mkdir logs

echo ======================================
echo 🚀 Starting FFmpeg Pipeline
echo ======================================

set startTime=%time%

:: ======================================
:: 统计 input\*.mp4 文件数量和总大小
:: ======================================
set FILE_COUNT=0
set TOTAL_IN_SIZE=0

for %%f in (input\*.mp4) do (
    set /a FILE_COUNT+=1
    for %%A in (%%f) do (
        set /a TOTAL_IN_SIZE+=%%~zA
    )
)

echo Input files: %FILE_COUNT%
echo Total input size: %TOTAL_IN_SIZE% bytes >> "%LOG%"

:: ======================================
:: 执行 3 个步骤
:: ======================================
call :run_step "scripts\1_preview.bat"
call :run_step "scripts\2_watermark.bat"
call :run_step "scripts\3_split.bat"

:: ======================================
:: 统计输出目录大小
:: ======================================
set TOTAL_OUT_SIZE=0
for %%f in (output\*.mp4) do (
    for %%A in (%%f) do (
        set /a TOTAL_OUT_SIZE+=%%~zA
    )
)

:: ======================================
:: 计算总耗时
:: ======================================
set endTime=%time%

for /f "tokens=1-4 delims=:.," %%a in ("%startTime%") do (
    set /a start_s=%%a*3600 + %%b*60 + %%c
)
for /f "tokens=1-4 delims=:.," %%a in ("%endTime%") do (
    set /a end_s=%%a*3600 + %%b*60 + %%c
)
set /a elapsed=end_s-start_s

:: 转换 GB
call :toGB %TOTAL_IN_SIZE% TOTAL_IN_GB
call :toGB %TOTAL_OUT_SIZE% TOTAL_OUT_GB

:: ======================================
:: 通知飞书
:: ======================================
set MSG=OK! FFmpeg Pipeline Finished!^
Files processed: %FILE_COUNT%^
Input Size: %TOTAL_IN_GB% GB^
Output Size: %TOTAL_OUT_GB% GB^
Elapsed Time: %elapsed% seconds^
Log: %LOG%

call :push_feishu "%MSG%"

echo.
echo ✓ All tasks completed.
echo Log saved at: %LOG%
pause
exit /b


:: ======================================
:: STEP Runner
:: ======================================
:run_step
set STEP=%~1
echo ▶ Running %STEP% ...
echo [STEP] %STEP% >> "%LOG%"

call %STEP%
if errorlevel 1 (
    echo ✗ %STEP% FAILED
    echo ERROR: %STEP% >> "%LOG%"
    set MSG=❌ FFmpeg pipeline failed at step: %STEP%^
Log: %LOG%
    call :push_feishu "%MSG%"
    exit /b 1
)
echo ✓ %STEP% OK
echo OK: %STEP% >> "%LOG%"
exit /b


:: ======================================
:: 数字转 GB（保留 2 位小数）
:: ======================================
:toGB
set /a size=%1
setlocal enabledelayedexpansion
set /a gb_i=size/1073741824
set /a gb_f=(size%%1073741824)*100/1073741824
endlocal & set "%2=%gb_i%.%gb_f%"
exit /b


:: ======================================
:: 飞书推送函数（PowerShell实现，支持中文/emoji/换行）
:: ======================================
:push_feishu
powershell -Command ^
  "$webhook='%FEISHU_WEBHOOK%';" ^
  "$msg='%~1';" ^
  "Invoke-RestMethod -Uri $webhook -Method POST -ContentType 'application/json' -Body (@{msg_type='text'; content=@{text=$msg}} | ConvertTo-Json -Compress)"
echo [Notify] Feishu message sent >> "%LOG%"
exit /b
