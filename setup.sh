#!/bin/sh

set -e

if [[ $(whoami) == 'root' ]]; then
    echo "Don't run this as root!" && exit
fi

mkdir -p ~/git && cd ~/git

echo '##### Fetching koha-testing-docker... #####'
git clone https://gitlab.com/LMSCloudPaulD/koha-testing-docker-lmscloud-devel.git && echo '##### Fetching complete! #####'

echo '##### Fetching kohaclone... #####'
git clone https://gitlab.com/koha-community/Koha.git && echo '##### Fetching complete! Renaming ... #####'

if [[ $(pwd) == /home/${USER}/git && -d Koha ]]; then
    mv Koha kohaclone
else
    echo '##### Wrong working directory! Switching.. #####'
    if [[ -n ${USER} ]]; then
        cd /home/${USER}/git
        mv Koha kohaclone
    else
        echo "##### ${USER} undefined! Exiting.. #####" && exit 1
    fi
fi
echo '##### Done! #####'

echo '##### Appending environment variables to bashrc.. #####'
KOHA_TESTING_DOCKER_HOME="/home/${USER}/git/koha-testing-docker-lmscloud-devel"
cat << EOF >> /home/${USER}/.bashrc
# ENV variables for kohadevbox
export SYNC_REPO="/home/${USER}/git/kohaclone"
export LOCAL_USER_ID=$(id -u)
export KOHA_TESTING_DOCKER_HOME=${KOHA_TESTING_DOCKER_HOME}
if ! command -v lscpu &> /dev/null; then
    if [[ $(sysctl -a | grep machdep.cpu | awk 'FNR == 1 {print $2 " " $3}') == "Apple M1" ]]; then
        export ARCHITECTURE="aarch64"
    fi
else
    export ARCHITECTURE=$(lscpu | awk 'FNR == 1 {print $2}')
fi
source ${KOHA_TESTING_DOCKER_HOME}/files/bash_aliases
EOF
echo '##### Done! #####'

echo '##### Switching to koha-testing-docker.. #####'
cd /home/${USER}/git/koha-testing-docker-lmscloud-devel && echo '##### Copying defaults.. #####'
cp env/defaults.env .env && echo 'Done!'

echo '##### Maybe test the setup with "ku" #####'


