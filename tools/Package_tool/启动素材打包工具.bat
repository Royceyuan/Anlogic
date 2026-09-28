@echo off
cd /d "%~dp0"
py -3 museum_media_packager.py
if errorlevel 1 pause
