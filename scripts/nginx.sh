##
# Установка и настройка веб сервера NGINX
#
# Официальный репозиторий для релизов:
# Debian: wheezy, jessie
# Ubuntu: precise, trusty, xenial
##


nginx_update_source_list()
{
    local codenames="wheezy jessie precise trusty xenial"
    local sourceList=${APT_SOURCE_DIR}nginx-mainline.list

    distInfo

    if ! in_list $codenames $CODENAME; then
        return
    fi

    if ! [ -f $sourceList ]; then
        local url=http://nginx.org/packages/mainline/${DISTR_ID,,}

        if [ "$(getHttpStatusCode $url/dists/$CODENAME)" != '404' ]; then
            echo deb $url/ $CODENAME nginx >> $sourceList
            echo deb-src $url/ $CODENAME nginx >> $sourceList

            wget -O - http://nginx.org/keys/nginx_signing.key | apt-key add -
            apt-get update
        fi
    fi
}


nginx_install()
{
    local scriptPath=$(dirname "$0")
    local installationPath=${1:-"/etc/nginx"}

    nginx_update_source_list

    if ! commandExists "nginx"; then
        apt-get install -y nginx
        cp $scriptPath/configs/nginx.conf $installationPath
    fi


    if [ ! -d $installationPath/sites-available ]; then
        mkdir -p $installationPath/sites-available
    fi

    if [ ! -d $installationPath/sites-enabled ]; then
        mkdir -p $installationPath/sites-enabled
    fi


    if [ ! -f $installationPath/sites-available/dev-zone-loc.conf ]; then
        cp $scriptPath/configs/nginx-dev-zone.conf $installationPath/sites-available/dev-zone-loc.conf
        ln -s $installationPath/sites-available/dev-zone-loc.conf $installationPath/sites-enabled/
        service nginx restart
    fi
}
