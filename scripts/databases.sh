##
# Изменить кодировку MySQL на UTF-8 по-умолчанию
##
mysql_fix_charset()
{
    if $(dirname "$0")/bin/mysqlFixCharset.sh; then
        service mysql restart
    fi
}


##
# Установка и настройка СУБД MySQL
##
mysql_install()
{
    apt-get install -y mysql-server
    mysql_fix_charset
}