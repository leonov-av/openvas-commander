#!/bin/bash

function install_dependencies()
{
    apt-get install -y build-essential devscripts dpatch curl libassuan-dev libglib2.0-dev libgpgme11-dev libpcre3-dev libpth-dev libwrap0-dev libgmp-dev libgmp3-dev libgpgme11-dev libpcre3-dev libpth-dev quilt cmake pkg-config libssh-dev libglib2.0-dev libpcap-dev libgpgme11-dev uuid-dev bison libksba-dev doxygen sqlfairy xmltoman sqlite3 libsqlite3-dev wamerican redis-server libhiredis-dev libsnmp-dev libmicrohttpd-dev libxml2-dev libxslt1-dev xsltproc libssh2-1-dev libldap2-dev autoconf nmap libgnutls28-dev gnutls-bin libpopt-dev heimdal-dev heimdal-multidev libpopt-dev mingw32 texlive-full rpm alien nsis rsync python2.7 python-setuptools checkinstall
}

function configure_redis()
{
    if [ ! -f /etc/redis/redis.orig ]; then
        cp /etc/redis/redis.conf /etc/redis/redis.orig
        echo "unixsocket /tmp/redis.sock" >> /etc/redis/redis.conf
        service redis-server restart        
    fi
}

function get_openvas_source_table()
{
    curl -s http://openvas.org/install-source.html | sed -e ':a;N;$!ba;s/\n/ /g' -e 's/.*<table class="dl_table"//' -e 's/<\/table>.*//' -e 's/<tr>/\n<tr>/g' | grep "<tr>" | grep -v "bgcolor"  | sed  -e 's/[ \t]*<\/t[dh]>[ \t]*/|/g' -e 's/"[ \t]*>[^<]*<\/a>//g' -e 's/<a href="//g' -e 's/[ \t]*<[/]*t[rdh]>[ \t]*//g' -e 's/|$//' | grep -v "Supports OMP "
}

function get_available_source_sets()
{
    get_openvas_source_table | head -n 1 | sed 's/|/\n/g'
}

function check_releas_name()
{
    local release_name="$1"
    is_available=`get_available_source_sets | grep "^$release_name$"`
    if [ "$is_available" == "" ]
    then
        echo "wrong release name"
    else
        echo "ok"
    fi
}

function get_source_set()
{
    local release_name="$1"
    col=`get_available_source_sets | awk -v name="$release_name" '{ if ( $0 == name ){print NR}}'`
    echo "$openvas_source_table" | awk -F"|" -v col="$col" '{ if ( NR != 1 && $1 != "" && $col != "" ){print $col}}'
}

function download_source_set()
{
    mkdir openvas 2>/dev/null
    cd openvas/
    get_source_set "$release_name" | xargs -i wget '{}'
    cd ../
}

function create_folders()
{
    cd openvas/
    find | grep ".tar.gz$" | xargs -i tar zxvfp '{}'
    cd ../
}

function install_component()
{
    local component="$1"
    cd openvas
    cd $component-* 
    mkdir build 
    cd build 
    cmake .. 
    make 
    make doc-full 
    version=`pwd | sed 's/\//\n/g' | grep "$component" | sed "s/$component-//"`
    checkinstall --pkgname "$component" --pkgversion "$version" --maintainer "openvas_commander" -y     
    cd ../../../
}


function mkcerts()
{
    
    openvas-mkcert 2>/dev/null
    openvas-mkcert-client -n -i 2>/dev/null
    openvas-manage-certs -a 2>/dev/null
}

#################################

release_name="$1"
openvas_source_table=`get_openvas_source_table`

if [ "$1" == "--install-dependencies" ]
then
    install_dependencies
fi

if [ "$1" == "--show-releases" ]
then
    get_available_source_sets
fi

if [ "$1" == "--show-sources" ]
then
    release_name="$2"
    check=`check_releas_name "$release_name"`
    if [ "$check" == "ok" ]
    then
        get_source_set "$release_name"
    else
        echo "$check"
    fi
fi

if [ "$1" == "--download-sources" ]
then
    release_name="$2"
    check=`check_releas_name "$release_name"`
    if [ "$check" == "ok" ]
    then
        download_source_set "$release_name"
    else
        echo "$check"
    fi
fi

if [ "$1" == "--create-folders" ]
then
    create_folders
fi

if [ "$1" == "--uninstall-all" ]
then
    dpkg -r "openvas-smb"
    dpkg -r "openvas-libraries"
    dpkg -r "openvas-scanner"
    dpkg -r "openvas-manager"
    dpkg -r "openvas-cli"
    dpkg -r "greenbone-security-assistant"
fi

if [ "$1" == "--install-all" ]
then
    install_component "openvas-smb"
    install_component "openvas-libraries"
    install_component "openvas-scanner"
    install_component "openvas-manager"
    install_component "openvas-cli"
    install_component "greenbone-security-assistant"
fi

if [ "$1" == "--install-component" ]
then
    install_component "$2"
fi

if [ "$1" == "--uninstall-component" ]
then
    dpkg -r "$2"
fi

if [ "$1" == "--configure-all" ]
then
    mkdir /usr/local/var/lib/openvas/openvasmd/
    mkdir /usr/local/var/lib/openvas/openvasmd/gnupg
    configure_redis
    mkcerts
    ldconfig
    openvasmd --create-user=admin --role=Admin && openvasmd --user=admin --new-password=1
fi

if [ "$1" == "--delete-admin" ]
then
    openvasmd --delete-user=admin
fi

if [ "$1" == "--update-content" ]
then
    if [ -f /usr/local/sbin/openvas-nvt-sync ]
    then
        /usr/local/sbin/openvas-nvt-sync
        /usr/local/sbin/openvas-scapdata-sync
        /usr/local/sbin/openvas-certdata-sync
    fi 
    if [ -f /usr/local/sbin/greenbone-certdata-sync ]
    then
        /usr/local/sbin/greenbone-nvt-sync
        /usr/local/sbin/greenbone-scapdata-sync
        /usr/local/sbin/greenbone-certdata-sync
    fi
fi

if [ "$1" == "--update-content-nvt" ]
then
    if [ -f /usr/local/sbin/openvas-nvt-sync ]
    then
        /usr/local/sbin/openvas-nvt-sync --curl
    fi 
    if [ -f /usr/local/sbin/greenbone-certdata-sync ]
    then
        /usr/local/sbin/greenbone-nvt-sync --curl
    fi
fi

if [ "$1" == "--rebuild-content" ]
then
    /usr/local/sbin/openvasmd --rebuild --progress
fi

if [ "$1" == "--start-all" ]
then

    mkdir /usr/local/var/run 2>/dev/null; 
    mkdir /usr/local/var/run/openvasmd 2>/dev/null; 
    touch /usr/local/var/run/openvasmd/openvasmd.pid;

    /usr/local/sbin/openvasmd
    /usr/local/sbin/openvassd
    /usr/local/sbin/gsad
fi

if [ "$1" == "--kill-all" ]
then
    ps aux | egrep "(openvas.d|gsad)" | awk '{print $2}' | xargs -i kill -9 '{}'
fi

if [ "$1" == "--check-status" ]
then
    if [ ! -f openvas-check-setup ]; 
    then
        wget https://svn.wald.intevation.org/svn/openvas/trunk/tools/openvas-check-setup --no-check-certificate
        chmod 0755 openvas-check-setup
    fi
    
    if [ "$2" == "" ]
    then
        version="v9"
    else
        version="$2"
    fi
    
    ./openvas-check-setup --$version --server
fi

if [ "$1" == "--check-proc" ]
then
    ps aux | egrep "(openvas.d|gsad)"
fi

#### TODO OSPD

#cd ospd-1*
#python setup.py install --prefix=/usr/local
#cd ../


#cd ospd-ancor-*
#python setup.py install --prefix=/usr/local
#cd ../

#cd ospd-debsecan-*
#python setup.py install --prefix=/usr/local
#cd ../

#cd ospd-ovaldi-*
#python setup.py install --prefix=/usr/local
#cd ../

#cd ospd-paloalto-*
#python setup.py install --prefix=/usr/local
#cd ../

#cd ospd-w3af-*
#python setup.py install --prefix=/usr/local
#cd ../
