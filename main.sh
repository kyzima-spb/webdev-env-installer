#!/bin/bash


SCRIPT_PATH="$(dirname "$0")"
APT_SOURCE_DIR="/etc/apt/sources.list.d/"


. "$SCRIPT_PATH/functions.sh"
. "$SCRIPT_PATH/scripts/nginx.sh"
. "$SCRIPT_PATH/scripts/php.sh"


installMenuHandler()
{
    # if [ "$1" != "" ]; then
    #     apt-get update
    # fi

    for task in $1; do
        case "$task" in
            system-tools) installSystemSoft;;
            nginx) nginx_install;;
            #php5) setupPHP;;
            php7) php_install;;
            mysql-server) setupMySQL;;
            nodejs) setupNodeJS;;
            dnsmasq) setupDNS;;
            tools) installDevelopementTools;;
            soft) installLocalSoft;;
        esac
    done
}


installMenu()
{
    answer=$(whiptail --title "webdev-env-installer" \
        --checklist --separate-output \
        "Select what you want to install" 20 75 13 \
            system-tools "Install necessary software like Flash, Vim and etc." 0 \
            nginx        "Install and configure the web server Nginx" 0 \
            php7         "Install and configure the PHP7.0 interpreter" 0 \
            mysql-server "Install and configure the MySQL database server" 0 \
            nodejs       "Install and configure the NodeJS interpreter" 0 \
            dnsmasq      "Install and configure a local DNS server" 0 \
            tools        "Install the software necessary to develop" 0 \
            soft         "Install packages from folder \"soft\"" 0 \
        3>&1 1>&2 2>&3
    )

    installMenuHandler "$answer"
}


mainMenu()
{
    answer=$(whiptail --title "webdev-env-installer" \
        --menu --notags \
        "Choose your option" 20 75 13 \
            1 "Install environment" \
            2 "Fix MySQL character set" \
            3 "Add users" \
            4 "Update users" \
            x "Exit" \
        3>&1 1>&2 2>&3
    )

    exitstatus=$?

    case "$answer" in
        1) installMenu;;
        2) fixMysqlCharset;;
        3) addUsers;;
        4) updateUsers;;
        x) exitstatus=1;;
    esac

    return $exitstatus
}


main()
{
    if [ "$(whoami)" != 'root' ]; then
        echo $"You have no permission to run $0 as non-root user. Use sudo" >&2
        exit 1;
    fi

    distInfo

    while [ "$?" = 0 ]; do
        mainMenu
    done

    exit 0
}


main