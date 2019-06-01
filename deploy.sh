#!/bin/bash

set -e # Exit on non-zero

trim_string_to_length () {
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

# Replaces slashes with underscores
replace_slashes_with_underscores () {
    local string=$1
    echo ${string//\//'-'} 
}

# Builds module into Docker release image
build_module () {
    local component=$1
    local project=$2
    local branch=$3

    if [ -d $component ]; then
        echo "Install, lint, test and build image for '$component' using Docker..."
        time BRANCH=$branch PROJECT=$project docker-compose -f docker-compose.yml build $component
    fi
}

# Create Heroku app name based on variables
heroku_app_name () { 
    # Convention: [project]-[trimmed-branch]-[c|s]
    # Max length = 30 characters
    local project=$1
    local component=$(echo $2 | head -c 1)
    local branch=$(replace_slashes_with_underscores $3)
    echo "$(trim_string_to_length $project-$branch)-$component"
}

heroku_app_url () {
    local project=$1
    local component=$2
    local branch=$3
    echo "Deployed app to https://$(heroku_app_name $project $component $branch).herokuapp.com"
}

# Push Docker release image to Heroku
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

        echo "Deployed app to https://$heroku_app_name.herokuapp.com"
    fi
}

# Builds the image which contains Node version and build dependencies
build_base_image () {
    echo "Checking if base image exists..."
    if [ "$(docker images -q base:latest 2> /dev/null)" == "" ]; then
        echo "Base image doesn't exist. Building now..."
        time docker build . -f ./devops/Dockerfile.base -t base:latest
    else 
        echo "Bypassing build of base image as it already exists..."
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
    trimmed_branch=$(replace_slashes_with_underscores $BRANCH)

    BITBUCKET_COMMIT=${4:-$(git rev-parse --short HEAD)}
    echo BITBUCKET_COMMIT $BITBUCKET_COMMIT

    # Build
    build_base_image
    cp ./server/.env.dev ./server/.env
    # build_module shared $PROJECT "latest" # TODO: fix branch here and in Client Dockerfile (COPY --from)
    build_module client $PROJECT $trimmed_branch
    build_module server $PROJECT $trimmed_branch

    # Deploy
    docker login --username=_ --password=$HEROKU_API_KEY registry.heroku.com
    deploy_docker_image client $PROJECT $trimmed_branch
    # deploy_docker_image server $PROJECT $trimmed_branch
fi
