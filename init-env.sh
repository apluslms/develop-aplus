#!/bin/bash

APLUS_MANUAL_DIR="aplus-manual"

# Fetch newest versions of all submodules if the a-plus directory is empty
if [ -z "$(ls -A a-plus)" ]; then
    git submodule update --init --remote --recursive
fi

if ! [ -d ".venv" ]; then
    # Create and activate virtual environment if it doesn't exist yet
    python3 -m venv .venv
    source .venv/bin/activate
    python3 -m pip install "setuptools<81" pyyaml -r a-plus/requirements.txt -r a-plus/requirements_testing.txt
    playwright install
else
    # Activate virtual environment if it exists already
    source ".venv/bin/activate"
fi

# Move to aplus-manual directory and build the course if it hasn't been built yet
if ! [ -d "$APLUS_MANUAL_DIR/_build" ]; then
    ( cd "$APLUS_MANUAL_DIR" && ./docker-compile.sh && cd .. ) || { echo "Failed to build course!"; return 1 2>/dev/null || exit 1; }
fi

# If aplus-manual is a git submodule (i.e. .git is a file, not a directory),
# promote it to a standalone repo so gitmanager can use it inside the container.
if [ -f "$APLUS_MANUAL_DIR/.git" ]; then
    echo "Promoting aplus-manual submodule to a standalone git repo..."
    git_modules_dir=".git/modules/aplus-manual"
    if [ -d "$git_modules_dir" ]; then
        rm "$APLUS_MANUAL_DIR/.git"
        cp -r "$git_modules_dir" "$APLUS_MANUAL_DIR/.git"
        git config --file "$APLUS_MANUAL_DIR/.git/config" --unset core.worktree
    else
        echo "WARNING: $git_modules_dir not found, skipping aplus-manual git setup." >&2
    fi
fi

# Create a-plus/aplus/local_settings.py if it doesn't exist yet
if [ -z "$APLUS_LOCAL_SETTINGS" ] && ! [ -f "a-plus/aplus/local_settings.py" ]; then
    echo "Creating 'a-plus/aplus/local_settings.py' from 'a-plus/aplus/local_settings.example.py' since it does not exist yet..."
    cp a-plus/aplus/local_settings.example.py a-plus/aplus/local_settings.py
fi

# Create docker-compose.yml if it doesn't exist yet
if [ -z "$COMPOSE_FILE" ] && ! [ -f "docker-compose.yml" ]; then
    echo "Creating 'docker-compose.yml' from 'docker-compose.example.yml' since it does not exist yet..."
    cp docker-compose.example.yml docker-compose.yml
fi

# Pull the latest images
docker compose pull

# Compile all translations (a-plus, mooc-grader, gitmanager, mooc-jutut)
APLUS_SECRET_KEY_FILE=a-plus/aplus/secret_key.py python3 a-plus/manage.py compilemessages --ignore=.venv

echo "Done!"
