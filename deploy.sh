#!/usr/bin/env bash

# Exit immediately if a simple command exits with a non-zero exit value
set -e

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
# /Params

HEROKU_APP_NAME="$PROJECT_NAME-$BITBUCKET_BRANCH"
echo "HEROKU_APP_NAME $HEROKU_APP_NAME"

function install_lint_and_test {
    echo "cd to $1..."
    cd ./$1

    echo "Installing, linting and testing $1..."
    yarn install
    npm run lint
    npm test
    
    echo "cd to root..."
    cd ../ 
}

function build_and_push_container {
    HEROKU_APP_NAME=$1
    BITBUCKET_COMMIT=$2
    HEROKU_API_KEY=$3

    echo "Creating app '$HEROKU_APP_NAME'..."
    heroku create -a $HEROKU_APP_NAME --region eu || true

    echo "Building image '$HEROKU_APP_NAME:$BITBUCKET_COMMIT' and pushing to Heroku..."
    docker login --username=_ --password=$HEROKU_API_KEY registry.heroku.com

    echo "Building and pushing container..."
    ID=$(docker build . -q -t $HEROKU_APP_NAME:$BITBUCKET_COMMIT)
    NAME="registry.heroku.com/$HEROKU_APP_NAME/web"
    docker tag $ID $NAME
    docker images
    docker push $NAME
    
    echo "Releasing container to '$HEROKU_APP_NAME'..."
    heroku container:release web -a $HEROKU_APP_NAME

    echo "Deployed app to https://$HEROKU_APP_NAME.herokuapp.com"
}

function deploy_client {
    echo "cd to directory..."
    cd ./client

    echo "Creating dist..."
    npm run build

    echo "Copying in Node app..."
    cp ../devops/static-web-app/* ./dist

    build_and_push_container $HEROKU_APP_NAME $BITBUCKET_COMMIT $HEROKU_API_KEY

    echo "cd to root..."
    cd ../
}

function deploy_server {
    echo "cd to directory..."
    cd ./server

    build_and_push_container "$HEROKU_APP_NAME-s" $BITBUCKET_COMMIT $HEROKU_API_KEY

    echo "cd to root..."
    cd ../
}

if [ -d module ]; then
    install_lint_and_test module
fi
install_lint_and_test client
install_lint_and_test server

deploy_client
deploy_server
