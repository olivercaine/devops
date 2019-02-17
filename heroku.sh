#!/bin/bash

# To uninstall:
# rm -rf /usr/local/heroku /usr/local/lib/heroku /usr/local/bin/heroku ~/.local/share/heroku ~/Library/Caches/heroku

if [ "$(which heroku)" != '/usr/local/bin/heroku' ]; then
    echo "Heroku not installed. Installing..."
    curl https://cli-assets.heroku.com/install.sh | sh; heroku --version; which heroku;
else
    echo "Heroku already installed!"
fi