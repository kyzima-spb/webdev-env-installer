##
# Confirm action.
##
asksure()
{
    local msg=${1:-"Are you sure?"}
    local answer

    echo -n "$msg [Y/n]: "

    while read -r -n 1 -s answer; do
        case $answer in
            y|Y) echo; return 0;;
            n|N) echo; return 1;;
        esac
    done
}


##
# Возвращает 0, если команда найдена, или 1 - если не найдена.
##
commandExists()
{
    if [ "$(type -t $1)" = "" ]; then
        return 1
    else
        return 0
    fi
}


##
# Создает директорию с родителями с указанным пользователем и режимом.
##
make_dir()
{
    local dir=${1:-""}
    local owner=${2:-"root"}
    local mode=${3:-755}

    if [ -z $dir ]; then
        return 1
    fi

    if [ ! -d $dir ]; then
        mkdir -p $dir
        chown $owner:$owner $dir
        chmod $mode $dir
        return 0
    fi

    return 1
}


##
# Возвращает 0, если сервис с указанным именем существует, иначе 1.
##
service_exists()
{
    if service --status-all | grep -Fq "$1"; then    
        return 0
    fi

    return 1
}


##
# Возвращает 1, если элемент есть в списке или 0 - если нет.
##
in_list()
{
    local i

    for i in $1; do
        if [ $i = $2 ]; then
            return 1
        fi
    done

    return 0
}


##
# Возвращает путь к директории с конфигурацией
##
config_get_dir()
{
    local path=~/.config/workflow

    if [ ! -d $path ]; then
        mkdir -p $path
    fi

    echo $path
}


##
# Возвращает информацию о дистрибутиве
##
distr_get_info()
{
    # lsb_release

    local d_id=$(lsb_release -is)
    local codename=$(lsb_release -cs)
    local note=""

    if [ "$d_id" = "LinuxMint" ]; then
        note="LinuxMint"

        case $codename in
            betsy )
                d_id="Debian"
                codename="jessie"
                ;;
            sarah)
                d_id="Ubuntu"
                codename="xenial"
                ;;
            rebecca | qiana)
                d_id="Ubuntu"
                codename="trusty"
                ;;
            maya)
                d_id="Ubuntu"
                codename="precise"
                ;;
        esac
    fi

    echo "$d_id $codename $note"
}


##
# Инициализирует информацию о дистрибутиве
##
distr_read_info()
{
    local d_id
    local codename
    local note
    local filename="$(config_get_dir)/distr.conf"

    if [ -n "$DISTR_ID" ] && [ -n "$CODENAME" ]; then
        return
    fi

    read d_id codename note <<< $(distr_get_info)

    if [ -f $filename ]; then
        . $filename
    fi

    if [ "$DISTR_ID" = "$d_id" ] && [ "$CODENAME" = "$codename" ]; then
        return
    fi

    while [ 1 ]; do
        echo -e "The distributor's ID: $d_id ($note)"
        echo -e "The code name of the currently installed distribution: $codename ($note)\n"

        if asksure "Is this ok?"; then
            break
        fi

        read -r -e -p "Enter the distributor's ID: " d_id
        read -r -e -p "Enter the code name of the currently installed distribution: " codename
    done

    DISTR_ID=$d_id
    CODENAME=$codename

    printf "DISTR_ID=${DISTR_ID}\nCODENAME=${CODENAME}" > $filename
}


##
# Возвращает или создает новый файл по указанному шаблону с переданными данными
# Данные передаются как описание ассоциативного массива
# Аргументы: <шаблон> <данные> [<выходной_файл>]
##
render()
{
    local template=${1:-""}
    eval "declare -A context="${2#*=}
    local out=${3:-""}
    local key
    local args=""

    for key in "${!context[@]}"; do
        args+="-e \"s|{{ $key }}|${context[$key]}|\" "
    done

    if [ "$out" == "" ]; then
        eval "sed $args \"$template\""
    else
        eval "sed $args \"$template\" > \"$out\""
    fi
}


##
# Получить HTTP код ответа сервера
##
getHttpStatusCode()
{
    curl --write-out %{http_code} --silent --output /dev/null $1
}


##
# Установить программное обеспечение необходимое при разработке
##
installDevelopementTools()
{
    apt-get install -y git dia \
                       mysql-workbench sqlitebrowser
}


##
# Установка стороннего софта из папки "soft"
##
installLocalSoft()
{
    local scriptPath=$(dirname "$0")
    local f

    for f in "$(ls $scriptPath/soft/*.deb)"; do
        dpkg -i $f
        
        if [ $? != 0 ]; then
            apt-get install -y -f
        fi
    done
}


##
# Установка системных пакетов
##
installSystemSoft()
{
    apt-get install vim curl flashplugin-nonfree arandr zsh
}


##
# Установка и настройка легковесного локального DNS сервера
##
setupDNS()
{
    apt-get install -y resolvconf dnsmasq

    local configFile=${1:-'/etc/dnsmasq.conf'}

    if [ -f $configFile ]; then
        local found=$(grep -c address=/loc/127.0.0.1 $configFile)

        if [ $found -eq 0 ]; then
            sed -i '$ a \\naddress=/loc/127.0.0.1' $configFile
            sed -i '$ a \\naddress=/loc5/127.0.0.1' $configFile
            sed -i '$ a listen-address=127.0.0.1' $configFile

            service dnsmasq restart
        fi
    fi
}
