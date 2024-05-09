@echo off
odin test tests/utils -vet -warnings-as-errors -strict-style -debug -collection:shared=shared -collection:engine=engine -out:build/tests_utils.exe
odin test tests/utils/testing -vet -warnings-as-errors -strict-style -debug -collection:shared=shared -collection:engine=engine -out:build/tests_utils_testing.exe
odin test tests/utils/procedures -vet -warnings-as-errors -strict-style -debug -collection:shared=shared -collection:engine=engine -out:build/tests_utils_procedures.exe

