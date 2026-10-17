@echo off
rem 需要先进入 VS 开发者命令行（cl.exe 在 PATH 里）
setlocal
cd /d "%~dp0"
if not exist bin mkdir bin

cl /nologo /utf-8 /std:c++17 /O1 /MT /W3 /EHsc main.cpp /Fobin\themed.obj /Febin\win32.exe /link /SUBSYSTEM:WINDOWS /MANIFEST:EMBED || exit /b 1
cl /nologo /utf-8 /std:c++17 /O1 /MT /W3 /EHsc /DNOVA_CLASSIC main.cpp /Fobin\classic.obj /Febin\win32_classic.exe /link /SUBSYSTEM:WINDOWS /MANIFEST:EMBED || exit /b 1

del /q bin\*.obj 2>nul
dir bin
