#!/bin/bash

set -e # Exit on non-zero exit value

repo_url=$(git config --get remote.origin.url)
repo=${repo_url##*/}
proj=${repo%%.*}

# Params
HEROKU_API_KEY=$1
echo "HEROKU_API_KEY $HEROKU_API_KEY" 
[ -z "$HEROKU_API_KEY" ] && { echo "Error: HEROKU_API_KEY not specified"; exit 1; }

PROJECT_NAME=${2:-$proj}
echo "PROJECT_NAME $PROJECT_NAME"

BITBUCKET_BRANCH=${3:-$(git symbolic-ref -q --short HEAD)}
echo "BITBUCKET_BRANCH $BITBUCKET_BRANCH" 

BITBUCKET_COMMIT=${4:-$(git rev-parse --short HEAD)}
echo "BITBUCKET_COMMIT $BITBUCKET_COMMIT"

trim_string () {
    local string=$1
    local max_length=${2:-28}
    if [ ${#string} -gt $max_length ]; then 
        tmp=""
        index=1
        while [ $index -le $max_length ]
        do
            var=$(echo ${string} | cut -c${index}-${index})
            tmp=$tmp"$var"
            index=$(expr $index + 1)
        done
        string=$tmp
    fi
    echo $string
}

install_lint_and_test () {
    if [ -d $1 ]; then
        echo "cd to $1..."
        cd ./$1

        echo "Installing, linting and testing $1..."
        yarn install
        npm run lint
        npm test
        
        echo "cd to root..."
        cd ../ 
    fi
}

build_and_push_container () {
    local HEROKU_APP_NAME=$1
    local BITBUCKET_COMMIT=$2
    local HEROKU_API_KEY=$3

    echo "Creating app '$HEROKU_APP_NAME'..."
    heroku create -a $HEROKU_APP_NAME --region eu || true

    echo "Building image '$HEROKU_APP_NAME:$BITBUCKET_COMMIT' and pushing to Heroku..."
    docker login --username=_ --password=$HEROKU_API_KEY registry.heroku.com

    echo "Building and pushing container..."
    ID=$(docker build . -q -t $HEROKU_APP_NAME:$BITBUCKET_COMMIT)
    NAME="registry.heroku.com/$HEROKU_APP_NAME/web"
    docker tag $ID $NAME
    docker push $NAME
    
    echo "Releasing container to '$HEROKU_APP_NAME'..."
    heroku container:release web -a $HEROKU_APP_NAME

    echo "Deployed app to https://$HEROKU_APP_NAME.herokuapp.com"
}

deploy () {
    if [ -d $1 ]; then
        echo "cd to $1..."
        cd ./$1

        echo "Creating dist..."
        npm run build

        suffix="$(echo $1 | head -c 1)"
        build_and_push_container $HEROKU_APP_NAME-$suffix $BITBUCKET_COMMIT $HEROKU_API_KEY

        echo "cd to root..."
        cd ../
    fi
}

HEROKU_APP_NAME=$(trim_string "$PROJECT_NAME-$BITBUCKET_BRANCH")

# install_lint_and_test module
# install_lint_and_test client
# install_lint_and_test server

FAIL=0

echo "starting"

install_lint_and_test module &
install_lint_and_test client &
install_lint_and_test server &

for job in `jobs -p`
do
echo $job
    wait $job || let "FAIL+=1"
done

echo $FAIL

if [ "$FAIL" == "0" ];
then
echo "YAY!"
else
echo "FAIL! ($FAIL)"
fi

deploy client
deploy server