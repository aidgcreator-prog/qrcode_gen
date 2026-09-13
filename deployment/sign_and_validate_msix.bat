@echo off
setlocal EnableDelayedExpansion
title QR Code Generator -- MSIX Sign and Validate

call "%~dp0msix\sign_and_validate.bat" %*
exit /b %ERRORLEVEL%
