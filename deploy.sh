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
replace_slashes_and_full_stops_with_hyphen () {
    local string=$1
    local no_slashes=${string//\//'-'} 
    local no_full_stops=${no_slashes//'.'/'-'} 
    echo $no_full_stops
}

create_heroku_app_name () { 
    local project=$1
    local component=$(echo $2 | head -c 1)
    local branch=$(replace_slashes_and_full_stops_with_hyphen $3)
    # Max 30 chars. Convention: [project]-[trimmed-branch]-[c|s]
    echo "$(trim_string_to_length $project-$branch)-$component" 
}

heroku_app_url () {
    local project=$1
    local component=$2
    local branch=$3
    echo "Deployed app to https://$(create_heroku_app_name $project $component $branch).herokuapp.com"
}

deploy_docker_image () {
    local component=$1
    local project=$2
    local branch=$3

    if [ -d $component ]; then
        echo "Building and pushing container for $component..."

        local heroku_app_name=$(create_heroku_app_name $project $component $branch)
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

build_base_and_dev_images () {
    local branch=${1:-$master}
    echo "Checking if base image exists..."
    if [ "$(docker images -q base:latest 2> /dev/null)" == "" ]; then
        echo "Base image doesn't exist. Building now..."
        time docker build . -f ./devops/Dockerfile.base -t olliecaine/base:$branch
        time docker build . -f ./devops/Dockerfile.dev -t olliecaine/dev:$branch
    else 
        echo "Bypassing build of base image as it already exists..."
    fi
}

build_and_deploy () {
    local HEROKU_API_KEY=$1

    local repo_url=$(git config --get remote.origin.url)
    repo=${repo_url##*/}
    
    local proj=${repo%%.*}
    PROJECT=${2:-$proj}
    echo PROJECT $PROJECT

    local BRANCH=${3:-$(git symbolic-ref -q --short HEAD)}
    echo BRANCH $BRANCH
    
    local trimmed_branch=$(replace_slashes_and_full_stops_with_hyphen $BRANCH)
    echo trimmed_branch $trimmed_branch

    local BITBUCKET_COMMIT=${4:-$(git rev-parse --short HEAD)}
    echo BITBUCKET_COMMIT $BITBUCKET_COMMIT

    cp ./server/.env.dev ./server/.env
    time BRANCH=$trimmed_branch PROJECT=$PROJECT docker-compose -f docker-compose.yml build --parallel

    # Deploy if Heroku key provided
    if [ -n "$HEROKU_API_KEY" ]; then
        docker login --username=_ --password=$HEROKU_API_KEY registry.heroku.com
        deploy_docker_image client $PROJECT $trimmed_branch
        deploy_docker_image server $PROJECT $trimmed_branch
    fi
}
