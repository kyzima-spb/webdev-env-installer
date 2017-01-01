##
# Установка и настройка темы оформления и значков Numix
#
# Официальный репозиторий для релизов:
# Debian: jessie, stretch (репы от ubuntu xenial)
# Ubuntu: zesty yakkety xenial wily vivid utopic trusty saucy raring quantal precise
##


numix_update_source_list()
{
    local codenames="jessie stretch zesty yakkety xenial wily vivid utopic trusty saucy raring quantal precise"
    local source_list="${APT_SOURCE_DIR}numix-ppa.list"
    local cn=$CODENAME


    if ! in_list $codenames $cn; then
        return
    fi

    if [ $DISTR_ID == "Ubuntu" ]; then
        add-apt-repository ppa:numix/ppa -y
        apt-get update
        return
    fi

    if [ "$DISTR_ID" == "Debian" ]; then
        cn="xenial"

        if ! [ -f $source_list ]; then
            local url=http://ppa.launchpad.net/numix/ppa/ubuntu

            if [ "$(getHttpStatusCode $url/dists/$cn)" != "404" ]; then
                echo deb $url $cn main >> $source_list
                echo deb-src $url $cn main >> $source_list

                apt-key add "keys/numix.key"
                apt-get update
            fi
        fi
    fi
}


numix_install()
{
    numix_update_source_list

    apt-get install -y numix-gtk-theme \
                       numix-icon-theme numix-icon-theme-circle numix-icon-theme-square \
                       numix-folders

    # Apply GTK Theme
    # gsettings set org.gnome.desktop.interface gtk-theme ""
}