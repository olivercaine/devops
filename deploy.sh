#!/usr/bin/env bash

# Exit immediately if a simple command exits with a nonzero exit value
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

install_test_and_lint () {
    echo "cd to $1..."
    cd ./$1

    echo "Installing, testing and linting $1..."
    npm install
    npm test
    npm run lint

    echo "cd to root..."
    cd ../ 
}

deploy_client () {
    echo "cd to client..."
    cd ./client

    echo "Creating dist..."
    npm run build

    # echo "Creating app '$HEROKU_APP_NAME'..."
    # heroku create -a $HEROKU_APP_NAME --region eu

    echo "Preparing submodule deploy..."
    git submodule add --force https://heroku:$HEROKU_API_KEY@git.heroku.com/$HEROKU_APP_NAME.git tmp
    cd tmp
    git config --global user.email "olliecaine@gmail.com"
    git config --global user.name "Oliver Caine"
    rm -rf ./*
    cp -R ../dist/. .
    cp -R ../../devops/static-web-app/. .

    echo "Pushing client to Heroku..."
    git add . && git commit -am "Dist"
    git push https://heroku:$HEROKU_API_KEY@git.heroku.com/$HEROKU_APP_NAME.git master

    echo "Remove tmp folder..."
    cd ../
    rm -rf tmp

    echo "Deployed app to https://$HEROKU_APP_NAME.herokuapp.com"

    echo "cd to root..."
    cd ../    
}

deploy_server () {
    echo "cd to directory..."
    cd ./server

    # echo "Creating app '$HEROKU_APP_NAME-s'..."
    # heroku create -a $HEROKU_APP_NAME-s --region eu || true

    echo "Building image '$HEROKU_APP_NAME-s:$BITBUCKET_COMMIT' and pushing to Heroku..."
    docker login --username=_ --password=$HEROKU_API_KEY registry.heroku.com

    echo "Prepping env file..."
    cp -R .env.production .env
    sed -i.bak "s/^\(APP_NAME=\).*/\1'$BITBUCKET_BRANCH #$BITBUCKET_COMMIT'/" .env
    cat .env

    echo "Building and pushing container..."
    ID=$(docker build . -q -t $HEROKU_APP_NAME-s:$BITBUCKET_COMMIT)
    NAME="registry.heroku.com/$HEROKU_APP_NAME-s/web"
    docker tag $ID $NAME
    docker images
    docker push $NAME
    
    echo "Releasing container to '$HEROKU_APP_NAME-s'..."
    heroku container:release web -a $HEROKU_APP_NAME-s

    echo "Deployed app to https://$HEROKU_APP_NAME-s.herokuapp.com"

    echo "cd to root..."
    cd ../../
}

if [ -d module ]; then
    install_test_and_lint module
fi
install_test_and_lint client
install_test_and_lint server
deploy_client
deploy_server
