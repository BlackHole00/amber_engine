#!/bin/sh
odin test tests/utils -vet -warnings-as-errors -strict-style -debug -collection:shared=shared -collection:engine=engine -out:build/tests_utils.out

echo '\n'
odin test tests/utils/testing -vet -warnings-as-errors -strict-style -debug -collection:shared=shared -collection:engine=engine -out:build/tests_utils_testing.out

echo '\n'
odin test tests/utils/procedures -vet -warnings-as-errors -strict-style -debug -collection:shared=shared -collection:engine=engine -out:build/tests_utils_procedures.out

