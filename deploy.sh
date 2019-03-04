#!/bin/bash

set -e # Exit on non-zero exit value

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

slash_to_underscore () {
    local string=$1
    echo ${string//\//'-'} 
}

# App name convention: [project]-[trimmed-branch]-[c|s]
# Max length = 30 characters
heroku_app_name () { 
    local project=$1
    local component=$(echo $2 | head -c 1)
    local branch=$(slash_to_underscore $3)
    echo "$(trim_string $project-$branch)-$component"
}

heroku_app_url () {
    local heroku_app_name=$1
    echo "https://$1.herokuapp.com/"
}

# Image name convention: [project]/[component]:[branch-name]
build_project () {
    local component=$1
    local project=$2
    local branch=$3

    if [ -d $component ]; then
        echo "Building image for $component..."
        cd ./$component

        echo "Install, lint, test and build '$component' using Docker..."
        time docker build . -t $project/$component:$branch

        cd ../ 
    fi
}

login_to_heroku_docker () {
    local heroku_api_key=$1
    echo "Logging in to Heroku Docker Hub..."
    docker login --username=_ --password=$heroku_api_key registry.heroku.com
}

deploy_docker_image () {
    local component=$1
    local project=$2
    local branch=$3

    if [ -d $component ]; then
        echo "Building and pushing container for $component..."

        local heroku_app_name=$(heroku_app_name $project $component $branch)
        local image_id=$(docker images $project/$component:$branch --format "{{.ID}}")
        local image_name="registry.heroku.com/$heroku_app_name/web"
        
        echo "Tagging $image_id as $image_name..."
        docker tag $image_id $image_name

        echo "Creating app '$heroku_app_name'..."
        heroku create -a $heroku_app_name --region eu || true

        echo "Pushing image $image_name..."
        time docker push $image_name

        echo "Releasing container to '$heroku_app_name'..."
        heroku container:release web -a $heroku_app_name

        echo "Deployed app to $(heroku_app_url $heroku_app_name)"
    fi
}

build_base_image () {
    if [ "$(docker images -q base:latest 2> /dev/null)" == "" ]; then
        echo "Building base image..."
        time docker build . \
            -f ./devops/Dockerfile.base \
            -t base:latest # TODO Tag this as project and branch specific (e.g. recipes/base:latest)
    else 
        echo "Base image already exists..."
    fi
}

HEROKU_API_KEY=$1
if [ -n "$HEROKU_API_KEY" ]; then
    echo HEROKU_API_KEY $HEROKU_API_KEY

    repo_url=$(git config --get remote.origin.url)
    repo=${repo_url##*/}
    proj=${repo%%.*}
    PROJECT=${2:-$proj}
    echo PROJECT $PROJECT

    BRANCH=${3:-$(git symbolic-ref -q --short HEAD)}
    trimmed_branch=$(slash_to_underscore $BRANCH)

    BITBUCKET_COMMIT=${4:-$(git rev-parse --short HEAD)}
    echo BITBUCKET_COMMIT $BITBUCKET_COMMIT

    # Build
    build_base_image
    build_project module $PROJECT "latest" # TODO: fix branch here and in Client Dockerfile (COPY --from)
    build_project client $PROJECT $trimmed_branch
    # build_project server $PROJECT $trimmed_branch

    # Deploy
    login_to_heroku_docker $HEROKU_API_KEY
    deploy_docker_image client $PROJECT $trimmed_branch
    # deploy_docker_image server $PROJECT $trimmed_branch
fi
