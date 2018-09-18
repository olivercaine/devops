#!/usr/bin/env bash
cd "$(dirname "$0")"

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

install_and_test () {
    npm install
    npm test
    if [ $? -eq 0 ]; then
        echo OK
    else
        echo FAIL
        exit 1
    fi
}

deploy_client () {
    echo "Creating app '$HEROKU_APP_NAME'..."
    heroku create -a $HEROKU_APP_NAME --region eu

    echo "cd to client..."
    cd ./client

    echo "Testing client..."
    install_and_test

    echo "Creating dist..."
    npm run build

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

    echo "cd to root..."
    cd ../
}

deploy_server () {
    echo "Creating app '$HEROKU_APP_NAME-s'..."
    heroku create -a $HEROKU_APP_NAME-s --region eu

    echo "cd to server..."
    cd ./server

    echo "Testing server..."
    install_and_test

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

    echo "cd to root..."
    cd ../../
}

echo "Deploying https://bitbucket.org/olliecaine/$PROJECT_NAME/commits/$BITBUCKET_COMMIT"

deploy_client
echo "Deployed app to https://$HEROKU_APP_NAME.herokuapp.com"

deploy_server
echo "Deployed app to https://$HEROKU_APP_NAME-s.herokuapp.com"
