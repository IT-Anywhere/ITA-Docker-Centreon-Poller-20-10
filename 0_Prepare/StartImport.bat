@title "Start GPO Import"
@echo off

powershell -ExecutionPolicy bypass -Command "Start-Process -filepath "%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe" -argumentlist "`"%~dp0\Install-Docker-WSL2.ps1`"" -Verb RunAs"