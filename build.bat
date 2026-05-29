@echo off
if not exist build mkdir build
odin build source -out:dodge_game.exe -debug
