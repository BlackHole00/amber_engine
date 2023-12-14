#!/bin/sh
odin build test_mod -vet -warnings-as-errors -strict-style -collection:shared=shared -build-mode:shared -debug -out:build/test_mod.dylib

mv build/test_mod.dylib mods

