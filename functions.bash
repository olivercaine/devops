#!/usr/bin/env bash

alias bash_functions="code $(dirname $0)/.bash"

# Docker
alias dc='docker-compose'
alias dcu='docker-compose up'
alias dcd='docker-compose down'
# Apps
alias st='open -a SourceTree .'
alias ij='open -a "IntelliJ IDEA" .'
# Maven
alias mci='mvn clean install'
alias mcist='mci -DskipTests'
# Yarn
alias ys='yarn start'
alias ysb='yarn storybook'
# Git
alias prune_remote='git remote prune origin'
alias prune_merged="git pull origin master:master; git branch --merged master | grep -v '^[ *]*master$' | xargs git branch -d"

# Reset to fresh checkout but keep (stash) all non-tracked files
function gpristine { 
    git stash --include-untracked --all
    git reset --hard
    git clean -dfx
}

# Opens the repo's remote
function repo {
    repoUrl=$(git config remote.origin.url)
    if [[ $repoUrl == *"bitbucket"* ]]; then
        open "${repoUrl/.git/}"
    else
        open $(git config remote.origin.url)
    fi
}

# (n)ode (v)ersion (m)anager (d)efault
function nvmd { 
    node_version=${1:-8.15}
    nvm alias default $node_version 
    nvm use $node_version
    echo 'Switched Node to lts/carbon...'
}

# (b)ranch (f)rom (c)ommit, e.g, 'bfc new-branch-name gItHaSh'
function bfc {
    git checkout -b $1 $2  
    git push --set-upstream origin $1
}