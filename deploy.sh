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

prep_heroku_app_name () {
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
    echo $string | tr / - # Heroky doesn't allow "/" so replace it with "-"
}

docker_build () {
    local directory=$1

    if [ -d $directory ]; then
        echo "cd to $directory..."
        cd ./$directory

        echo "Installing, testing, linting and building $directory using Docker..."
        time npm run build:docker -- -t $PROJECT_NAME/$directory

        echo "cd back to root..."
        cd ../ 
    fi
}

docker_build_and_push () {
    if [ -d $1 ]; then
        echo "cd to $1..."
        cd ./$1

        suffix="$(echo $1 | head -c 1)"
        local heroku_app_name=$HEROKU_APP_NAME-$suffix

        echo "Creating app '$heroku_app_name'..."
        heroku create -a $heroku_app_name --region eu || true

        echo "Building image '$heroku_app_name:$BITBUCKET_COMMIT' and pushing to Heroku..."
        docker login --username=_ --password=$HEROKU_API_KEY registry.heroku.com

        echo "Building and pushing container..."
        ID=$(docker build . -q -t $heroku_app_name:$BITBUCKET_COMMIT)
        NAME="registry.heroku.com/$heroku_app_name/web"
        docker tag $ID $NAME
        docker push $NAME
        
        echo "Releasing container to '$heroku_app_name'..."
        time heroku container:release web -a $heroku_app_name

        echo "Deployed app to https://$heroku_app_name.herokuapp.com"

        echo "cd to root..."
        cd ../
    fi
}

HEROKU_APP_NAME=$(prep_heroku_app_name "$PROJECT_NAME-$BITBUCKET_BRANCH")

# TODO: use docker_build_and_push for module
time docker_build module
time docker_build_and_push client
time docker_build_and_push server
