#!/bin/bash

git submodule update --init --recursive

git clone git@github.com:apluslms/aplus-manual.git mooc-grader/courses/default

cd mooc-grader/courses/default
git submodule update --init --recursive
cd -

cd mooc-grader/courses/default

./docker-compile.sh