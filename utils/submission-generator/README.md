# How to generate/post submissions to A+ automatically

Run `./generate-submissions.sh` in the root of this repository or run `submit.py` directly.

If using `submit.py` directly, supply API tokens for users as command line arguments or define users via `config.yaml`.
(See section [Submitters](#submitters) for more details.)

## Editing what submissions are generated and submitted

- Most of the settings are defined in `config.yaml`
  - If `config.yaml` doesn't exist, the [`generate-submissions.sh`](/generate-submissions.sh) script will create it by copying the file [`config.example.yaml`](config.example.yaml).
    You can of course create the file manually if you wish to change the settings before generating submissions.
- If you want to set a limit for the submission counts, in the `config.yaml` file, comment out the variable `global_duration_minutes` and change the `count` variables of each batch to a desired number.
  The count indicates how many submissions are made in that batch per user.
  For each submission, the script selects a random exercise from the URI list for that batch and creates a submission (with a randomly selected file or combination of files from the directory of files for that exercise).
- If the variable `global_duration_minutes` is defined, submissions are generated until the script stops when that many minutes have passed or the script is stopped with `CTRL + C` (i.e. the `count` values are ignored).

### Submitters

- By default when running `./generate-submissions.sh`, the number of users submissions are generated for is defined in the [`generate-submissions.sh`](/generate-submissions.sh) file by defining the `MAX_USER_ID` and `MIN_USER_ID` variables.
    - Note: User id 6 is a student that has not been enrolled on the course.
      By default, the script generates submissions for 10 students (ids 7 to 16)
    - `generate-submissions.sh` supplies the API tokens, unless this is overwritten in `config.yaml`
- The file `config.yaml` can be used to supply a file containing API tokens for users (path relative to this directory).
  This overrides the users defined in `./generate-submissions.sh`.
- If using `submit.py` directly, API tokens for users can be supplied as command line arguments, e.g., `python3 submit.py <token1> <token2>`.
- A username and password can be used in `config.yaml` but then only one submitter is supported.

### Creating submissions for additional exercises

- Create a new directory in the directory [`files`](files).
  The name of the new directory should be the URI of the exercise.
    - Hint: In A+, the URI can be found through *Edit course* (in the side menu) -> *Edit assignment* (button in the list) -> *URL* (field).
- In the directory, create solution files to be submitted.
  The files' names can be anything.
  The script will randomly select one of the files to use a solution for each submission instance.
  - For **questionnaires**, the submission files should be YAML files directly in the new directory.
  - For **programming exercises** or other exercises that one would submit a file, you should create a subdirectory for each file selection field, where you place the submission files.
  (For example, if the exercise accepts just *one file*, there should be *one subdirectory* with all the alternative files. If a user would submit *two files* at once when making a submission, there would be *two subdirectories*, one for each file. See [`programming_exercises_graderutils_iotester_exercise2`](files/programming_exercises_graderutils_iotester_exercise2) for an example that requires two files to be submitted.)
    - These subdirectories' names will be provided as values in the `config.yaml` file.
- Add the URIs to the `config.yaml` file
  - Questionnaires, feedback questionnaires and enrollment exercises under the `questionnaire` group
  - Programming exercises and exercises requiring file submissions under the `submit` group
    - The exercise URI is provided as a variable name referring to a dict of the files.
      In the dict, the key is the exercise's file field key (defined in the course material in the exercise's `config.yaml` file).
      The value is the name of the subdirectory which contains the alternative submission files for the file, e.g.,
        ```yaml
        uris:
          programming_exercises_graderutils_iotester_exercise2:
            file1: wallet
            file2: wallet_program
          programming_exercises_graderutils_primes:
            file1: primes
        ```
  - You can either *create a new batch* (with its own count and interval) or *add the URIs to an existing batch*
    - If you want to ensure that (a certain number of) submissions are made to the exercise for each student, create a new batch with only that exercise URI.
    - **Note:** The interval is in between submissions in the batch, regardless of the submitter.
      For example, the interval is 2000 milliseconds (i.e. 2 seconds), it means that every 2 seconds there will be a submission from one of the students.
      If there are 10 submitters, there would be 20 seconds between the submissions of a specific student.

#### Questionnaire submission files

- Should be YAML files
- The file should contain key-value pairs for question to be answered.
  - The key is the question key (defined with the parameter `:key:` in course rst-files, or field_0, etc. by default)
  - The value should be the response value
    - For checkboxes, it should be a list of the response values
    - Examples:
      ```yaml
      field_1: b  # radio button
      field_2: b  # dropdown
      field_3:    # checkboxes
        - b
        - c
        - f
      ```
      ```yaml
      field_1: test   # freetext with string response
      ...
      field_4: 11     # freetext with integer response
      field_5: 0.375  # freetext with float response
      ```
