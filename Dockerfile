FROM node:8.15 as ci-environment

RUN curl https://cli-assets.heroku.com/install.sh | sh; heroku --version; which heroku;