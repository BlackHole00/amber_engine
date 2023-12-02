#!/bin/sh
odin build test_mod -vet -warnings-as-errors -strict-style -collection:shared=shared -build-mode:shared -out:build/test_mod.dylib

