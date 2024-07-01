#!/bin/bash

# User ID range to generate submissions for
MIN_USER_ID=7
MAX_USER_ID=16

# Create utils/submission-generator/config.yaml if it doesn't exist yet
if ! [ -f "utils/submission-generator/config.yaml" ]; then
    echo "Creating 'utils/submission-generator/config.yaml' from 'utils/submission-generator/config.example.yaml' since it does not exist yet..."
    cp utils/submission-generator/config.example.yaml utils/submission-generator/config.yaml
fi

output=$(docker exec --user aplus aplus-plus-1 bash -c "
python3 manage.py shell <<EOF
from userprofile.models import UserProfile
from rest_framework.authtoken.models import Token
userprofiles = UserProfile.objects.filter(id__range=($MIN_USER_ID, $MAX_USER_ID))
for userprofile in userprofiles:
    token, _created = Token.objects.get_or_create(user=userprofile.user)
    print(token.key)
EOF
" 2> /dev/null)

# Store the tokens in an array
tokens=($output)

# Pass the tokens as command line arguments
python3 utils/submission-generator/submit.py "${tokens[@]}"
