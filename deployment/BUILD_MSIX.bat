@echo off
setlocal
title Building QR Code Generator MSIX...
call "%~dp0msix\BUILD_MSIX.bat" %*
exit /b %ERRORLEVEL%
