#!/bin/bash

######################
## Config Functions ##
######################
extract_config (){
    cat $config | grep -i ^"$1=" |  cut -f2 -d'='
}

extract_wpconf_value (){
    file=$1
    field=$2
    cat $file | grep -i "define('$field'" | cut -f4 -d"'"
}

convert_winpath () {
    # convert Windows path to Unix path
    # 2 Steps: 1) Swaps slashes. 2) Replace "X:" with "/X".
    echo $1 | sed -e 's_\\_\/_' -e 's_\([a-zA-Z]\)\:_\/\1_'
}

yesnochoose () {
    # $1 is the maximum number of retries
    max=$( [ "$1" -eq "$1" ] 2>/dev/null && echo $1  || echo 5 )
    # $2 is the retry count and should not be set when called outside of recursion.
    count=$( [ "$2" -eq "$2" ] 2>/dev/null && echo $2  || echo 0 )
    read uchoose
    uchoose=$(echo $uchoose | sed -e 's/\(.*\)/\U\1/' -e 's/ //g')
    case "$uchoose" in
        "YES"|"YE"|"Y")
        return 0
        ;;
        "NO"|"N")
        return 1
        ;;
        *)
        count=$(expr $count + 1)
        if [ "$count" -ge "$max" ]; then
            return 2
        else
            >&2 echo "Please type 'yes' or 'no'"
            return $(yesnochoose "$max" "$count")
        fi
        ;;
    esac
}

###########################
## Initial Configuration ##
###########################
# check the OS and configure defaults
osenv=""
case $( uname -a | sed 's/.*\(MINGW\|LINUX\).*/\U\1/I') in
    "MINGW")
    osenv="MINGW"
    windows_root=$(convert_winpath $("cmd.exe" /c "echo %SystemRoot%"))
    hostsfile="$windows_root/System32/drivers/etc/hosts"
    lineconvert="unix2dos"
    revlineconvert="dos2unix"
    echo "# OS Environment is MINGW32_NT"
    ;;
    "LINUX" )
    osenv="LINUX"
    hostsfile="/etc/hosts"
    lineconvert="cat"
    revlineconvert="cat"
    echo "# OS Environment is LINUX"
    ;;
    *)
    echo "# Unknown OS Environment"
    exit 1
esac

# load settings from config file   
config="wp_manage.conf"
if [ -e "$config" ]; then
    sitefolder=$(extract_config sitefolder)
    echo "# sitefolder = $sitefolder"
    dumpfile=$(extract_config dumpfile)
    echo "# dumpfile = $dumpfile"
    sitedomain=$(extract_config sitedomain)

    # check for mysqlpath in "wp_manage.conf" and add to execution path.
    mysqlpath=$(extract_config mysqlpath)
    if [ "$mysqlpath" == "" ]; then
        echo '# "$mysqlpath" empty'
        else
        PATH=$PATH:"$mysqlpath"
    fi   
    where mysqldump > /dev/null 2>&1
    if [ "$?" -gt 0 ]; then
        echo "# Executable 'mysqldump' not found, environment needs setup."
        exit 1
    else
        echo "# mysqldump is found in the temporary \"\$PATH\""
    fi
else
    echo "# 'wp_manage.conf' not found in "$(pwd)
    exit 1
fi

###########################
## Main Config Functions ##
###########################

init_mysql_settings() {
    mysqluser=$(extract_config mysqluser)
    mysqluserpw=$(extract_config mysqluserpw)

    wp_folder="$sitefolder"
    db_file="$dumpfile"
    wpconfig="$wp_folder""/wp-config.php"
    mydb=$(extract_wpconf_value "$wpconfig" "DB_NAME")
    myuser=$(extract_wpconf_value "$wpconfig" "DB_USER")
    mypass=$(extract_wpconf_value "$wpconfig" "DB_PASSWORD")
}

############################
## Main Command Functions ##
############################

do_db_dump (){
    init_mysql_settings
    mysqldump "$mydb" -u"$myuser" -p"$mypass" > $dumpfile 2>/devnull
}

do_import_mysql () {
    init_mysql_settings 
    echo "exit" | mysql -u"$mysqluser" -p"$mysqluserpw" 2> /dev/null
    if [ "$?" -gt 0 ]; then
        echo "Failed to login to mysql database as root"
        exit 1
    fi

    #check for user and create if needed
    echo "SELECT User FROM mysql.user;" | mysql -u"$mysqluser" -p"$mysqluserpw" 2> /dev/null | grep "$myuser" > /dev/null 2>&1
    if [ "$?" -gt 0 ]; then
        echo "# User '""$myuser""' not found"

        echo "CREATE USER '""$myuser""'@'localhost' IDENTIFIED BY '""$mypass""';" | mysql -u"$mysqluser" -p"$mysqluserpw" 2> /dev/null
        echo "GRANT ALL ON ""$mydb"".* TO '""$myuser""'@'localhost';" | mysql -u"$mysqluser" -p"$mysqluserpw" 2> /dev/null
        
        echo "# Created user '""$myuser""' with ALL privileges to database"
    else
        echo "# User '""$myuser""' found"
    fi

    #user selections
    mydbdodrop=1
    echo "USE ""$mydb"";" | mysql -u"$mysqluser" -p"$mysqluserpw" 2>&1 | grep "ERROR" > /dev/null 2>&1
    if [ "$?" -gt 0 ]; then
        echo "# Database '""$mydb""' already exists"
        echo "# Drop the Database? [yes|no]"
        yesnochoose
        case "$?" in 
            0)
            mydbdodrop=0
            echo "# Database Will Be Dropped by Import"
            mydbbackup="databasebackup.sql"
            tmpdbf="$dumpfile"
            dumpfile="$mydbbackup"
            do_db_dump
            dumpfile="$tmpdbf"
            echo "# Database backed up to '""$dumpfile""'"

            ;;
            *)
            mydbdodrop=1
            echo "# Database Left Intact. Nothing left to do."
            exit 0 
            ;;
        esac
    else
        echo "# Database '""$mydb""' doesn't exist"
    fi

    echo "USE ""$mydb"";" | mysql -u"$mysqluser" -p"$mysqluserpw" 2>&1 | grep "ERROR" > /dev/null 2>&1
    if [ "$?" -eq 0 ]; then
        #create DB
        echo "creating database '""$mydb""'"
        echo "CREATE DATABASE $mydb;" | mysql -u"$mysqluser" -p"$mysqluserpw" > /dev/null 2>&1 
    fi
    # Bash's Process Substitution doesn't work in windows...
    REALLYBIGSTRING=$(echo "USE ""$mydb"";" && cat "$dumpfile")
    echo "$REALLYBIGSTRING" | mysql -u"$mysqluser" -p"$mysqluserpw" > /dev/null 2>&1


    exit 0
}


do_hosts_switch(){
    sitedomain=$1
    entry_comment="#wp_manage_entry"

    if [ "$2" == "clean" ]; then
        cat "$hostsfile" | grep -v "$entry_comment"  | "$lineconvert" > "$hostsfile"
        echo "# hosts file cleaned of all wp_manage entries"
        exit 0
    fi


    cat "$hostsfile" | grep "$sitedomain" > /dev/null 2>&1
    if [ "$?" -gt 0 ]; then
        # nothing in hosts.
        #fill in $sitedomain and "www.""$sitedomain"
        echo "# No entries for '$sitedomain' in '$hostsfile"
        # Note ">>" appends to the file, where are ">" would overwrite.
        echo "  127.0.0.1   $sitedomain $entry_comment" | "$lineconvert" >> "$hostsfile"
        echo "  127.0.0.1   www.$sitedomain $entry_comment" | "$lineconvert" >> "$hostsfile"
        echo "# Hosts entries added to '$hostsfile'"
        exit 0
    else
        echo "# Hosts Entries already added. In this case we could comment the lines, but we don't"
        echo "# Use arguments 'hosts clean' to remove all hosts file entries created by this script"
    fi
}

print_help(){
    echo " usage:"
    echo " 'wp_manage.sh dump'"
    echo "    Dumps database to 'database.sql',"
    echo "    using credentials from 'wp_manage.conf' and 'wp-config.php'"
    echo " 'wp_manage.sh importdb'"
    echo "    Imports database from 'database.sql',"
    echo "    using credentials from 'wp_manage.conf' and 'wp-config.php'"
    echo " 'wp_manage.sh hosts'"
    echo "    Looks for dns entries in 'hosts' file,"
    echo "    adds or removes depending on comment '#wp_manage_entry'"
    echo ""
    echo "###########################################################"
    echo ""
    echo "This script relies on the file 'wp_manage.conf'"
    echo "That will be executed as a bash script internally,"
    echo "to set the following  required environment variables:"
    echo ""
    echo "#Directory containing 'mysql' and 'mysqldump'"
    echo "#Only necessary when mysql is not on \$PATH, i.e. on Windows"
    echo "mysqlpath=/usr/bin"
    echo ""
    echo "# mysql root username"
    echo "mysqluser=root"
    echo ""
    echo "#mysql root password"
    echo "mysqluserpw=mysql"
    echo ""
    echo "# wordpress directory path "
    echo "sitefolder=./site/public_html/wordpress"
    echo ""
    echo "# filepath for database dump"
    echo "dumpfile=./database.sql"
    echo ""
    echo "# domain name (not including 'www') for wordpress site."
    echo "sitedomain=example.com"
    echo ""
    echo "###########################################################"
    echo ""
    echo "On msys in windows (i.e. git for windows):"
    echo "This script requires 'unix2dos' and 'dos2unix',"
    echo "for converting line endings."
    echo "May need to download and add these to your path manually."
    echo ""
}

#######################
## Command Selection ##
#######################
# call one of the above functions
case "$1" in
    "dump")
    echo "# Dumping WordPress DataBase"
    do_db_dump 
    ;;
    "importdb")
    do_import_mysql
    ;;
    "hosts")
    echo "# Hosts Switch"
    do_hosts_switch $sitedomain $2
    ;;
    "cygpath")
    echo "Unimplemented"
    #TODO cygpath ???
    #cygpath $*
    ;;
    'h'|'-h'|'help'|'-help')
    print_help
    exit 0
    ;;
    *)
    echo "___ Current Configuration ___"
    echo osenv=$osenv
    echo windows_root=$windows_root
    echo hostsfile=$hostsfile
    echo lineconvert=$lineconvert
    echo revlineconvert=$revlineconvert
    echo ""
    echo "___ Loaded Config ___"
    echo mysqlpath=$mysqlpath
    echo mysqluser=$mysqluser
    echo mysqluserpw=$mysqluserpw
    echo sitefolder=$sitefolder
    echo dumpfile=$dumpfile
    echo sitedomain=$sitedomain
    echo print_help
    exit 1
    ;;
esac
