#!/bin/bash

# Fetch all submodules if the a-plus directory is empty
if [ -z "$(ls -A a-plus)" ]; then
    git submodule update --init --recursive
fi

if ! [ -d ".venv" ]; then
    # Create and activate virtual environment if it doesn't exist yet
    python3 -m venv .venv
    source .venv/bin/activate
    python3 -m pip install setuptools -r a-plus/requirements.txt -r a-plus/requirements_testing.txt
    playwright install
else
    # Activate virtual environment if it exists already
    source .venv/bin/activate
fi

# Move to aplus-manual directory and build the course if it hasn't been built yet
if ! [ -d aplus-manual/_build ]; then
    cd aplus-manual
    ./docker-compile.sh
    cd ..
fi

# Create a-plus/aplus/local_settings.py if it doesn't exist yet
if [ -z "$APLUS_LOCAL_SETTINGS" ] && ! [ -f "a-plus/aplus/local_settings.py" ]; then
    echo "Creating 'a-plus/aplus/local_settings.py' from 'a-plus/aplus/local_settings.example.py' since it does not exist yet..."
    cp a-plus/aplus/local_settings.example.py a-plus/aplus/local_settings.py
fi

# Create docker-compose.yml if it doesn't exist yet
if [ -z "$COMPOSE_FILE" ] && ! [ -f "docker-compose.yml" ]; then
    OS=$(uname -s)
    if [ "$OS" = 'Darwin' ]; then
        echo "Creating 'docker-compose.yml' from 'docker-compose.macOS.example.yml' since it does not exist yet..."
        cp docker-compose.macOS.example.yml docker-compose.yml
    else
        echo "Creating 'docker-compose.yml' from 'docker-compose.example.yml' since it does not exist yet..."
        cp docker-compose.example.yml docker-compose.yml
    fi
fi

# Compile all translations (a-plus, mooc-grader, gitmanager, mooc-jutut)
APLUS_SECRET_KEY_FILE=a-plus/aplus/secret_key.py python3 a-plus/manage.py compilemessages --ignore=.venv

echo "Done!"
