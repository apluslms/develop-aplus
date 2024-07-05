import os
import random
import sys
from threading import Thread, Lock
import time
import urllib.parse

from bs4 import BeautifulSoup
import requests
import yaml


CONFIG_FILENAME = "config.yaml"
FILES_DIRNAME = "files"


config_path = os.path.join(os.path.dirname(__file__), CONFIG_FILENAME)
files_path = os.path.join(os.path.dirname(__file__), FILES_DIRNAME)
user_tasks_done = {}
total_tasks_done = {
    'submit': 0,
    'questionnaire': 0,
    'page': 0,
}
tasks_lock = Lock()
print_lock = Lock()


def spinning_cursor():
    while True:
        for cursor in '|/-\\':
            yield cursor


spinner = spinning_cursor()


def print_progress_bar(iteration, total, prefix="", suffix="", decimals=1, length=50, fill='█'):
    """Call in a loop to create terminal progress bar

    @param iteration: Current iteration (int)
    @param total: Total iterations (int)
    @param prefix: Prefix string (str)
    @param suffix: Suffix string (str)
    @param decimals: Positive number of decimals in percent complete (int)
    @param length: Character length of bar (int)
    @param fill: Bar fill character (str)
    """
    percent = ("{0:." + str(decimals) + "f}").format(100 * (iteration / float(total)))
    filled_length = int(length * iteration // total)
    bar = fill * filled_length + '▒' * (length - filled_length)
    print("\033[K", end='') # Clear previous line to ensure that ALL previous characters are removed
    print(f'\r{prefix} {bar} {percent}% {suffix}', end='\r')
    if iteration == total:
        print()


def print_status(total_tasks_done, user, group, request_type):
    with print_lock:
        print("\033[J", end='') # Erase from the cursor position to the bottom right corner
        print(
            "\nTotal tasks done:\n"
            f"POST submit: {total_tasks_done['submit']}\n"
            f"POST questionnaire: {total_tasks_done['questionnaire']}\n"
            f"GET page: {total_tasks_done['page']}\n\n"
            "Performing tasks, press CTRL + C to quit... "
            f"{next(spinner)} (User {user}, Task: {request_type} {group} #{user_tasks_done[user][group] + 1})"
        )
        print("\033[7A", end='') # Move the cursor up by 7 lines


def send_request(method, url, session, **kwargs):
    if method == 'GET':
        res = session.get(url)
    elif method == 'POST':
        session.post(url, **kwargs)


def fire_and_forget(method, url, session, **kwargs):
    Thread(target=send_request, args=(method, url, session), kwargs=kwargs).start()


def submit(host_url, uri, session, group, exercise_id, file_dirs):
    submit_api_url = urllib.parse.urljoin(
        host_url,
        f"api/v2/exercises/{exercise_id}/submissions/submit/"
    )
    if group == 'submit':
        files = {}
        for key in file_dirs:
            dirname = os.path.join(files_path, uri, file_dirs[key])
            all_filenames = [
                f for f in os.listdir(dirname)
                if os.path.isfile(os.path.join(dirname, f))
                and not f.startswith('.')
            ]
            filename = random.choice(all_filenames)
            full_path = os.path.join(dirname, filename)
            files[key] = open(full_path, 'rb')
        fire_and_forget('POST', submit_api_url, session, files=files)
    elif group == 'questionnaire':
        dirname = os.path.join(files_path, uri)
        all_filenames = [
            f for f in os.listdir(dirname)
            if os.path.isfile(os.path.join(dirname, f))
            and not f.startswith('.')
        ]
        filename = random.choice(all_filenames)
        full_path = os.path.join(dirname, filename)
        with open(full_path, 'r') as stream:
            fields = yaml.safe_load(stream)
        fire_and_forget('POST', submit_api_url, session, data=fields)
    else:
        raise Exception(f"Unknown group: {group}")


def load_page(course_details, uri, session):
    course_url = course_details['html_url']
    page_url = urllib.parse.urljoin(course_url, uri)
    fire_and_forget('GET', page_url, session)


def get_exercise_id(exercise_post_urls_and_ids, uri):
    for post_url in exercise_post_urls_and_ids:
        if uri in post_url:
            return exercise_post_urls_and_ids[post_url]


def time_requests(
        host_url,
        course_details,
        exercise_post_urls_and_ids,
        group,
        batch,
        start_time,
        duration,
        session,
        user_count,
        user,
    ):
    exercise_ids = {}
    if group in ['submit', 'questionnaire']:
        for uri in batch['uris']:
            exercise_ids[uri] = get_exercise_id(exercise_post_urls_and_ids, uri)

    mean = batch['interval_milliseconds']
    sigma = batch['interval_std_deviation']
    delay_original = max(0, random.gauss(mean, sigma) / 1000)
    delay_adjusted = max(0, random.gauss(mean * user_count, sigma) / 1000)
    time.sleep(delay_original * (user - 1))

    # Send requests at somewhat randomized intervals
    batch_tasks_done = 0
    while True:
        uri = random.choice(list(batch['uris']))
        if group == 'page':
            request_type = 'GET'
            print_status(total_tasks_done, user, group, request_type)
            load_page(course_details, uri, session)
        elif group in ['submit', 'questionnaire']:
            request_type = 'POST'
            print_status(total_tasks_done, user, group, request_type)
            file_dirs = batch['uris'][uri] if group == 'submit' else None
            exercise_id = exercise_ids[uri]
            submit(host_url, uri, session, group, exercise_id, file_dirs)
        else:
            raise Exception(f"Unknown group: {group}")
        batch_tasks_done += 1
        with tasks_lock:
            user_tasks_done[user][group] += 1
            total_tasks_done[group] += 1
        if duration:
            batch_completed = (time.time() - start_time + delay_adjusted) >= (duration * 60)
        else:
            batch_completed = batch_tasks_done == batch['count_per_user']
        if batch_completed:
            break

        time.sleep(delay_adjusted)


with requests.Session() as session:
    api_tokens = sys.argv[1:]

    # Read config
    with open(config_path, 'r') as stream:
        config = yaml.safe_load(stream)
    host_url = config['host_url']
    course_id = config['course_id']
    api_tokens_file = config.get('api_tokens_file', "")
    username = config.get('username', None)
    password = config.get('password', None)
    duration = config.get('global_duration_minutes', None)

    if username and password:
        # Log in using username and password
        session.headers.update({
            'Accept': "text/html",
            'User-Agent': "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36",
        })
        login_url = urllib.parse.urljoin(host_url, f"accounts/login/")
        response = session.get(login_url)
        soup = BeautifulSoup(response.text, 'html.parser')
        csrf_token = soup.select_one('input[name="csrfmiddlewaretoken"]')['value']
        session.headers.update({
            'Referer': login_url,
        })
        payload = {
            'csrfmiddlewaretoken': csrf_token,
            'username': username,
            'password': password,
        }
        response = session.post(login_url, data=payload, allow_redirects=False)
        session.headers.update({
            'Accept': "application/json",
            'X-CSRFToken': session.cookies['csrftoken'],
        })
    elif api_tokens_file:
        absolute_path = os.path.join(os.path.dirname(__file__), api_tokens_file)
        # Use API token for authorization
        api_tokens = []
        with open(absolute_path, 'r') as file:
            for line in file:
                line = line.strip()
                if line:
                    api_tokens.append(line)
        session.headers.update({
            'Accept': "application/json",
            'Authorization': f"Token {api_tokens[0]}",
        })
    elif api_tokens:
        # Use API token for authorization
        session.headers.update({
            'Accept': "application/json",
            'Authorization': f"Token {api_tokens[0]}",
        })
    else:
        raise Exception("Either API tokens or username and password must be provided")

    # Get course details and exercises
    print("Fetching course details...")
    course_details_api_url = urllib.parse.urljoin(
        host_url,
        f"api/v2/courses/{course_id}/",
    )
    response = session.get(course_details_api_url)
    course_details_dict = response.json()

    print("Fetching all exercises...")
    course_exercises_api_url = urllib.parse.urljoin(
        host_url,
        f"api/v2/courses/{course_id}/exercises/",
    )
    response = session.get(course_exercises_api_url)
    exercises_dict = response.json()

    print("Fetching all exercise post URLs and IDs...")
    total_count = len(exercises_dict['results'])
    print_progress_bar(0, total_count, prefix="Progress:", suffix=f"Complete {next(spinner)}", length=32)
    exercise_post_urls_and_ids = {}
    for i, module in enumerate(exercises_dict['results']):
        for exercise in module['exercises']:
            response = session.get(exercise['url'])
            exercise_dict = response.json()
            if 'post_url' in exercise_dict:
                exercise_post_urls_and_ids[exercise_dict['post_url']] = exercise_dict['id']
            print_progress_bar(i + 1, total_count, prefix="Progress:", suffix=f"Complete {next(spinner)}", length=32)
    print_progress_bar(i + 1, total_count, prefix="Progress:", suffix="Complete", length=32)

    # Do tasks
    start_time = time.time()
    if username and password:
        user_count = 1
        user = 1
        user_tasks_done[user] = {
            'submit': 0,
            'questionnaire': 0,
            'page': 0,
        }
        for group in config['groups']:
            for batch in config['groups'][group]:
                if duration or batch.get('count_per_user'):
                    Thread(
                        target=time_requests,
                        args=(
                            host_url,
                            course_details_dict,
                            exercise_post_urls_and_ids,
                            group,
                            batch,
                            start_time,
                            duration,
                            session,
                            user_count,
                            user,
                        )
                    ).start()
    else:
        user_count = len(api_tokens)
        for i, api_token in enumerate(api_tokens):
            user = i + 1
            user_tasks_done[user] = {
                'submit': 0,
                'questionnaire': 0,
                'page': 0,
            }
            with requests.Session() as session2:
                session2.headers.update({
                    'Accept': "application/json",
                    'Authorization': f"Token {api_token}",
                })
                for group in config['groups']:
                    for batch in config['groups'][group]:
                        if duration or batch.get('count_per_user'):
                            Thread(
                                target=time_requests,
                                args=(
                                    host_url,
                                    course_details_dict,
                                    exercise_post_urls_and_ids,
                                    group,
                                    batch,
                                    start_time,
                                    duration,
                                    session2,
                                    user_count,
                                    user,
                                ),
                            ).start()
