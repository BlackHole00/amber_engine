@echo off

odin build engine -vet -warnings-as-errors -strict-style -debug -collection:shared=shared -collection:engine=engine -out:build/amber_engine.exe
