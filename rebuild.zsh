#!/bin/zsh

adb down
docker container prune -f
docker build --no-cache -t aspendiscovery/aspen:latest .
adb up -g -d
