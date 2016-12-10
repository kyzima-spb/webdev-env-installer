##
# Установка и настройка интерпретатора NodeJS
##
nodejs_install()
{
    if ! commandExists "nodejs"; then
        apt-get install -y nodejs npm
        ln -s /usr/bin/nodejs /usr/bin/node # todo: проверить в Ubuntu
    fi
}