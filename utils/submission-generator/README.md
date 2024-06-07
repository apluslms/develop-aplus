# How to generate/post submissions to A+ automatically

Run `./generate-submissions.sh` in the root of this repository or run `submit.py` directly.

The file `config.yaml` can be used to supply a file containing API tokens for users (path relative to this directory).

If using `submit.py` directly, API tokens for users can be supplied as command line arguments.
Otherwise, `generate-submissions.sh` supplies the API tokens.

A username and password can be used in `config.yaml` but then only one submitter is supported.
