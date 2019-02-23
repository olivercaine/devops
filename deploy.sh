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

heroku_app_name () {
    local project=$1
    local component=$(echo $2 | head -c 1)
    local branch=${3////'-'} # Heroku doesn't allow "/" so replace it with "-"
    echo $(trim_string $project-$component-$branch)
}

build_dockerfile () {
    # Image name convention: [project]/[component]:[branch-name]
    local component=$1
    local project=$2
    local branch=$3

    if [ -d $component ]; then
        echo "cd to $component..."
        cd ./$component

        echo "Install, test, lint and build '$component' using Docker..."
        if [ "$component" == 'module' ]; then
            time docker build . -t $project/$component:$branch -f ../devops/Dockerfile.build
        else
            time docker build . -t $project/$component:$branch
        fi

        echo "cd up root..."
        cd ../ 
    fi
}

login_to_heroku_docker () {
    local heroku_api_key=$1
    echo "Logging in to Heroku Docker Hub..."
    docker login --username=_ --password=$heroku_api_key registry.heroku.com
}

deploy_docker_image () {
    # App name convention: [project]-[s|c]-[branch-name-short]
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

slash_to_underscore () {
    local string=$1
    echo ${string/\//'-'} 
}

repo_url=$(git config --get remote.origin.url)
repo=${repo_url##*/}
proj=${repo%%.*}

# Params
HEROKU_API_KEY=$1
echo HEROKU_API_KEY $HEROKU_API_KEY
[ -z "$HEROKU_API_KEY" ] && { echo "Error: HEROKU_API_KEY not specified"; exit 1; }

PROJECT=${2:-$proj}
echo PROJECT $PROJECT

BRANCH=${3:-$(git symbolic-ref -q --short HEAD)}
trimmed_branch=$(slash_to_underscore $BRANCH)

BITBUCKET_COMMIT=${4:-$(git rev-parse --short HEAD)}
echo BITBUCKET_COMMIT $BITBUCKET_COMMIT

build_dockerfile module $PROJECT "latest" # TODO: fix branch here and in Client Dockerfile (COPY --from)
build_dockerfile client $PROJECT $trimmed_branch
build_dockerfile server $PROJECT $trimmed_branch

login_to_heroku_docker $HEROKU_API_KEY

deploy_docker_image client $PROJECT $trimmed_branch
deploy_docker_image server $PROJECT $trimmed_branch