@echo off
setlocal
title Validating QR Code Generator MSIX...
call "%~dp0msix\VALIDATE_MSIX.bat" %*
exit /b %ERRORLEVEL%
