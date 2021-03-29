@title "Restart docker compose"
@echo off
Pushd "%~dp0"

docker-compose down && docker-compose pull && docker-compose up -d