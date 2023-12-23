@echo off

odin build test_mod -vet -warnings-as-errors -strict-style -collection:shared=shared -build-mode:shared -debug -out:build/test_mod.dll

move build\test_mod.dll mods

