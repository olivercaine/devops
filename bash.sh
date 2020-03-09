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

merge_to_all_branches_from () {
    echo "1 $1"
    local merge_from=${1:-$(git symbolic-ref --short HEAD)} # Merge to all branches from current branch by default
    echo "merge_from $merge_from"

    for branch in $(git for-each-ref --format="%(refname:short)" refs/heads); do
        echo "b $branch"
        if [[ "${branch}" != "master" ]]; then
            echo "Merge from $merge_from to ${branch}"
            git checkout "${branch}"
            git merge $merge_from
            git push --no-verify
        fi
    done
}
