FROM node:8.15-alpine as ci-environment

RUN apk add --no-cache curl
RUN apk update && apk add bash
RUN curl https://cli-assets.heroku.com/install.sh | sh; heroku --version; which heroku;