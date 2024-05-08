#!/bin/sh
odin test tests/utils -vet -warnings-as-errors -strict-style -debug -collection:shared=shared -collection:engine=engine -out:build/tests_utils.out

