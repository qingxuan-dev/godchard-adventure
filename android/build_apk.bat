@echo off
cd /d "%~dp0"
if exist gradlew.bat (
  call gradlew.bat assembleRelease
) else (
  gradle assembleRelease
)
echo Signed APK ready in app\build\outputs\apk\release\
pause
