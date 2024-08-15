#!/bin/bash

echo "Updating submodules..."

for dir in a-plus mooc-grader gitmanager mooc-jutut aplus-manual; do
    cd "$dir"
    git switch master > /dev/null 2>&1
    cd ..
done

git submodule update --init --remote

echo "Done!"
