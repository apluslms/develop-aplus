# An utility repository for debugging A+ and mooc-grader in VSCode

## Setup

1. Replace the `git@github.com:apluslms/aplus-manual.git` in `setup.sh` with which ever course repo you want to use (leave it if you want to use aplus-manual)
    - You might need to change the `./docker-compile.sh` to something else if you change the repo
2. Run the setup script: `./setup.sh`
3. Switch the branches/commits in the subrepositories if you dont want to use the latest master one.

## Debugging

1. Run the containers with `docker-compose up [-d]`
    - Note: `plus` container will spew out connection refused errors until you attach to MOOC (if the `command: ...` isn't commented out for it)
2. Wait for the containers to be ready (takes a few seconds)
3. Attach to the containers with the `Attach: A+/MOOC` debug configuration

## Only debugging one project

1. Comment out (#) the `command: ...` line corresponding to the project you do not want to debug
2. Follow the debugging instructions above but attach only to the container you want to debug

## Run without debugging

1. Comment out both commands as [above](#only-debugging-one-project)
2. Run the containers with `docker-compose up [-d]`

## Notes

### SystemExit exception

Django automatic reloads cause VSCode to stop on the SystemExit exception. This behaviour can be stopped by unchecking the "Uncaught Exceptions" option breakpoints panel in the debug tab.

### Don't wait for debugger attachment

Removing the `--wait-for-client` flag from a command in the docker-compose.yml file causes the program to be run without waiting for the debugger. You can still attach the debugger later if you wish.
