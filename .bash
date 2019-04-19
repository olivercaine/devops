#!/usr/bin/env bash

source ~/.nvm/nvm.sh

alias bash_project='code $(dirname $0)/.functions'

function install_tools {
    echo "Installing Brew..."
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

    echo "Homebrew Cask..."
    brew tap caskroom/cask

    echo "Installing Docker packages..."
    brew install docker docker-compose docker-machine xhyve docker-machine-driver-xhyve

    echo "Installing API and database apps..."
    brew cask install docker
}

function seed {
    git submodule add -b master https://github.com/olivercaine/common.git common
    git submodule add -b master https://github.com/olivercaine/devops.git devops
    git submodule add -b master https://github.com/olivercaine/docker-postgres.git database
    git subtree add --prefix=client https://github.com/olivercaine/react-redux-starter-kit-extended.git modpack/latest --squash
    git subtree add --prefix=module https://github.com/olivercaine/typescript-library-boilerplate.git modpack/latest --squash
    git subtree add --prefix=server https://github.com/olivercaine/express-typescript-boilerplate.git modpack/latest --squash
}

function update_client {
    git subtree pull --prefix=client https://github.com/olivercaine/react-redux-starter-kit-extended.git modpack/latest --squash
}

function update_module {
    git subtree pull --prefix=module https://github.com/olivercaine/typescript-library-boilerplate.git modpack/latest --squash
}

function update_server {
    git subtree pull --prefix=server https://github.com/olivercaine/express-typescript-boilerplate.git modpack/latest --squash
}

function update_modules {
    cd client/devops;gco master;gl;../common;gco master;gl;../../devops;gco master;gl;../;
}

function uat {
    local directory=${PWD##*/}
    open "https://${directory}-${3:-$(git symbolic-ref -q --short HEAD)}-c.herokuapp.com/"
}
