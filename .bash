#!/usr/bin/env bash

source ~/.nvm/nvm.sh

CLIENT=https://github.com/olivercaine/react-redux-starter-kit-extended.git
MODULE=https://github.com/olivercaine/typescript-library-boilerplate.git
SERVER=https://github.com/olivercaine/express-typescript-boilerplate.git

function seed {
    git submodule add -b master https://github.com/olivercaine/common.git common
    git submodule add -b master https://github.com/olivercaine/devops.git devops
    git subtree add --prefix=client $CLIENT modpack/latest --squash
    git subtree add --prefix=module $MODULE modpack/latest --squash
    git subtree add --prefix=server $SERVER modpack/latest --squash
}

function update_client {
    git subtree pull --prefix=client $CLIENT modpack/latest --squash
}

function update_module {
    git subtree pull --prefix=module $MODULE modpack/latest --squash
}

function update_server {
    git subtree pull --prefix=server $SERVER modpack/latest --squash
}

function update_modules {
    cd client/devops;gco master;gl;../common;gco master;gl;../../devops;gco master;gl;../;
}

function uat {
    local directory=${PWD##*/}
    open "https://${directory}-${3:-$(git symbolic-ref -q --short HEAD)}-c.herokuapp.com/"
}
