#!/bin/bash

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

echo "x"
echo $0
echo "y"

# Create app name and crop if it's too long
HEROKU_APP_NAME="$PROJECT_NAME-$BITBUCKET_BRANCH"
max_length=28
if [ ${#HEROKU_APP_NAME} -gt $max_length ]; then 
    # HEROKU_APP_NAME=''
    tmp=''

    # Characters="TESTING"
    index=1
    while [ $index -le ${#HEROKU_APP_NAME} ]
    do
        letter=$(${HEROKU_APP_NAME} | cut -c${index}-${index})
        echo "letter: $letter"
        tmp+=letter
        index=$(expr $index + 1)
    done


#     while read line ; do
#   ##this line is not correct, should strip :port and store to ip var
#   ip=$( echo "$line" |cut -d\: -f1 )
#   ping $ip
# done < ${file}

    # echo "end"

    # for value in {1..5}
    # do
    # # echo $value
    # echo ${HEROKU_APP_NAME:$value:1}
    # done

    # counter=1
    # until [ $counter -le 28 ]
    # do
    # HEROKU_APP_NAME+=${HEROKU_APP_NAME:$counter:1}
    # ((counter++))
    # done

    # for (( i=0; i<$max_length; i++ )); do
    #     new_name+=${HEROKU_APP_NAME:$i:1}
    # done
    # HEROKU_APP_NAME=$new_name
fi
echo "HEROKU_APP_NAME $HEROKU_APP_NAME"
exit

install_lint_and_test () {
    echo "cd to $1..."
    cd ./$1

    echo "Installing, linting and testing $1..."
    yarn install
    npm run lint
    npm test
    
    echo "cd to root..."
    cd ../ 
}

build_and_push_container () {
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

deploy_client () {
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

deploy_server () {
    echo "cd to directory..."
    cd ./server

    build_and_push_container "$HEROKU_APP_NAME-s" $BITBUCKET_COMMIT $HEROKU_API_KEY

    echo "cd to root..."
    cd ../
}

if [ -d module ]; then
    install_lint_and_test module
fi
if [ -d client ]; then
    install_lint_and_test client
fi
if [ -d server ]; then
    install_lint_and_test server
fi

deploy_client
deploy_server
