#!/usr/bin/env bash

source ~/.nvm/nvm.sh

CLIENT=https://github.com/olivercaine/react-redux-starter-kit-extended.git
MODULE=https://github.com/olivercaine/typescript-library-boilerplate.git
SERVER=https://github.com/olivercaine/express-typescript-boilerplate.git

seed () {
    git submodule add -b master https://github.com/olivercaine/common.git common
    git submodule add -b master https://github.com/olivercaine/devops.git devops
    git subtree add --prefix=client $CLIENT modpack/latest --squash
    git subtree add --prefix=module $MODULE modpack/latest --squash
    git subtree add --prefix=server $SERVER modpack/latest --squash
}

update_client () {
    git subtree pull --prefix=client $CLIENT modpack/latest --squash
}

update_module () {
    git subtree pull --prefix=module $MODULE modpack/latest --squash
}

update_server () {
    git subtree pull --prefix=server $SERVER modpack/latest --squash
}

update_modules () {
    cd client/devops;gco master;gl;../common;gco master;gl;../../devops;gco master;gl;../;
}

uat () {
    local directory=${PWD##*/}
    open "https://${directory}-${3:-$(git symbolic-ref -q --short HEAD)}-c.herokuapp.com/"
}

merge_to_remote_branches_from () {
    local merge_from=${1:-$(git symbolic-ref --short HEAD)} # Merge to all branches from current branch by default
    
    # Bitbucket's git is configured to not pull remote's branches
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git fetch origin

    for ref in $(git for-each-ref --format='%(refname:short)' | grep -v master | grep -v HEAD); do # Loops over refs except master and HEAD
        branch=${ref:7} # Strip 'origin/' from the beginning
        if [[ "$branch" != "master" ]]; then
            echo "Merge from $merge_from to $branch..."
            git checkout $branch
            git merge $merge_from
            git push origin --no-verify
        fi
    done
}
