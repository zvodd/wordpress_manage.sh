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

# Is this needed?
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
    dbdumpfile=$(extract_config dbdumpfile)
    echo "# dbdumpfile = $dbdumpfile"
    sitedomain=$(extract_config sitedomain)
    mysql_su=$(extract_config mysql_su)
    mysql_su_pw=$(extract_config mysql_su_pw)

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

# Pull database settings config from "wp-config.php" in $sitefolder
init_mysql_settings() {
    # mysql_su=$(extract_config mysql_su)
    # mysql_su_pw=$(extract_config mysql_su_pw)

    wp_folder="$sitefolder"
    dbdumpfile="$dbdumpfile"
    wpconfig="$wp_folder""/wp-config.php"
    mydb=$(extract_wpconf_value "$wpconfig" "DB_NAME")
    myuser=$(extract_wpconf_value "$wpconfig" "DB_USER")
    mypass=$(extract_wpconf_value "$wpconfig" "DB_PASSWORD")

    #all settings should be checked before proceeding?
}

###################
## Main Commands ##
###################

command_db_dump()
{
    init_mysql_settings
    function_db_dump "$dbdumpfile"
}

function_db_dump(){
    local dumpdest="$1"
    mysqldump "$mydb" -u"$myuser" -p"$mypass" --opt --skip-dump-date --order-by-primary | sed 's$VALUES ($VALUES\n($g' | sed 's$),($),\n($g' > "$dumpdest" 2> /devnull
}

function_does_db_exist(){
    local true=0
    local false=1
    local db_exists="$false"
    # check database exist,
    # grep returns 1(false) if no match for "ERROR" is found.
    echo "USE ""$mydb"";" | mysql -u"$mysql_su" -p"$mysql_su_pw" 2>&1 | grep "ERROR" > /dev/null 2>&1
    if [ "$?" -gt 0 ]; then
        db_exists="$true"
    fi
    return "$db_exists"
}

command_import_mysql () {
    init_mysql_settings 
    echo "exit" | mysql -u"$mysql_su" -p"$mysql_su_pw" 2> /dev/null
    if [ "$?" -gt 0 ]; then
        echo "Failed to login to mysql database as root"
        exit 1
    fi

    #check for user and create if needed
    echo "SELECT User FROM mysql.user;" | mysql -u"$mysql_su" -p"$mysql_su_pw" 2> /dev/null | grep "$myuser" > /dev/null 2>&1
    if [ "$?" -gt 0 ]; then
        echo "# User '""$myuser""' not found"

        echo "CREATE USER '""$myuser""'@'localhost' IDENTIFIED BY '""$mypass""';" | mysql -u"$mysql_su" -p"$mysql_su_pw" 2> /dev/null
        echo "GRANT ALL ON ""$mydb"".* TO '""$myuser""'@'localhost';" | mysql -u"$mysql_su" -p"$mysql_su_pw" 2> /dev/null
        
        echo "# Created user '""$myuser""' with ALL privileges to database"
    else
        echo "# User '""$myuser""' found"
    fi

    
    if function_does_db_exist; then
        echo "# Database '""$mydb""' already exists"
        echo "# Drop the Database? [yes|no]"
        yesnochoose
        case "$?" in 
            0)
            echo "# Database Will Be Dropped by Import"
            local tmptime=$(date +"%H.%M.%S_%d-%h-%y")
            local dumpdest="db_bak_wpmanage_$tmptime.sql"
            function_db_dump "$dumpdest"
            echo "# Database backed up to '""$dbdumpfile""'"
            ;;
            *)
            echo "# Database Left Intact. Nothing left to do."
            exit 0 
            ;;
        esac
    else
        echo "# Database '""$mydb""' doesn't exist."
    fi

    
    if function_does_db_exist; then
        #create DB
        echo "creating database '""$mydb""'"
        echo "CREATE DATABASE $mydb;" | mysql -u"$mysql_su" -p"$mysql_su_pw" > /dev/null 2>&1 
    fi
    # Bash's Process Substitution doesn't work in windows...
    REALLYBIGSTRING=$(echo "USE ""$mydb"";" && cat "$dbdumpfile")
    echo "$REALLYBIGSTRING" | mysql -u"$mysql_su" -p"$mysql_su_pw" > /dev/null 2>&1


    exit 0
}


command_hosts_switch(){
    sitedomain=$1
    entry_comment="#wp_manage_entry"

    if [ "$2" == "clean" ]; then
        # "example\\.com\\s\\#wp_manage_entry"
        cat "$hostsfile" | grep -v "$sitedomain\\s\\+$entry_comment"  | "$lineconvert" > "$hostsfile"
        echo "# hosts file cleaned of all wp_manage entries"
        exit 0
    fi


    cat "$hostsfile" | grep "$sitedomain" > /dev/null 2>&1
    if [ "$?" -gt 0 ]; then
        # nothing in hosts.
        # Add entries "$sitedomain" and "www.$sitedomain"
        echo "# No entries for '$sitedomain' in '$hostsfile"
        # Note ">>" appends to the file, where are ">" would overwrite.
        # extra line needed in case host file doesn't end with blank line.
        echo "" | "$lineconvert" >> "$hostsfile"
        echo "127.0.0.1   $sitedomain $entry_comment" | "$lineconvert" >> "$hostsfile"
        echo "127.0.0.1   www.$sitedomain $entry_comment" | "$lineconvert" >> "$hostsfile"
        echo "# Hosts entries added to '$hostsfile'"
        exit 0
    else
        echo "# Hosts Entries already added. In this case we could comment the lines, but we don't"
        echo "# Use arguments 'hosts clean' to remove all hosts file entries created by this script"
    fi
}

print_help(){
    echo " Usage:"
    echo " 'wp_manage.sh dump'"
    echo "    Dumps database to 'database.sql',"
    echo "    using credentials from 'wp_manage.conf' and 'wp-config.php'"
    echo " 'wp_manage.sh importdb'"
    echo "    Imports database from 'database.sql',"
    echo "    using credentials from 'wp_manage.conf' and 'wp-config.php'"
    echo " 'wp_manage.sh hosts'"
    echo "    Looks for dns entries in 'hosts' file,"
    echo "    adds or removes depending on comment '#wp_manage_entry'"
    echo " 'wp_manage.sh [showconfig|config]'"
    echo "    prints the loaded configuration. "
    echo " 'wp_manage.sh [h|-h|help|-help|*]'"
    echo "    prints this help message."
    echo ""

}

print_config(){
    echo "___ Current Configuration ___"
    echo osenv=\"$osenv\"
    echo windows_root=\"$windows_root\"
    echo hostsfile=\"$hostsfile\"
    echo lineconvert=\"$lineconvert\"
    echo revlineconvert=\"$revlineconvert\"
    echo ""
    echo "___ Loaded Config ___"
    echo mysqlpath=\"$mysqlpath\"
    echo mysql_su=\"$mysql_su\"
    echo mysql_su_pw=\"$mysql_su_pw\"
    echo sitefolder=\"$sitefolder\"
    echo dbdumpfile=\"$dbdumpfile\"
    echo sitedomain=\"$sitedomain\"
    echo ""
}

#######################
## Command Selection ##
#######################
# call one of the above functions
case "$1" in
    "dump")
    echo "# Dumping WordPress database"
    command_db_dump 
    ;;
    "importdb")
    command_import_mysql
    ;;
    "hosts")
    echo "# Hosts Switch"
    command_hosts_switch $sitedomain $2
    ;;
    'h'|'-h'|'help'|'-help')
    print_help
    exit 0
    ;;
    'config'|'showconfig')
    print_config
    exit 0
    ;;
    *)
    print_help
    exit 1
    ;;
esac
