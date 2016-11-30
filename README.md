### Usage

* 'wp_manage.sh dump'
    Dumps database to 'database.sql',
    using credentials from 'wp_manage.conf' and 'wp-config.php'
* 'wp_manage.sh importdb'
    Imports database from 'database.sql',
    using credentials from 'wp_manage.conf' and 'wp-config.php'
* 'wp_manage.sh hosts'
    Looks for dns entries in 'hosts' file,
    adds or removes depending on comment '#wp_manage_entry'
* 'wp_manage.sh [showconfig|config]'
    prints the loaded configuration. 
* 'wp_manage.sh [h|-h|help|-help|*]'
    prints this help message.



### Configure

wp_manage.sh relies on the file 'wp_manage.conf'
Variables are extracted from wp_manage.conf via the "extract_config".
"wp_manage.conf" should be in the directory that "wp_manage.sh" 
is excuted from, not necessarily where it is installed.


Copy , paste, then edit this section into a file 'wp_manage.conf'.
````
# Directory containing 'mysql' and 'mysqldump'
# Only necessary when mysql is not on $PATH
# e.g. on Windows with xampp or similair all in one A.M.P. stack.
mysqlpath="/c/Program Files (x86)/xampp/mysql/bin"

# For some functions we need a mysql user who
# can create users and grate ALL on tables.

# mysql super_user username 
mysql_su="root"

# mysql user password
mysql_su_pw="mysql"

# wordpress directory path
sitefolder="./site/public_html/wordpress"

# filepath for database dump
dumpfile="./database.sql"

# domain name (not including 'www') for wordpress site.
sitedomain="example.com"
````

### Pre-Install

On Windows running msys (i.e. git for windows):
The hosts file changer function of this script
requires 'unix2dos' and 'dos2unix', for converting line endings.
You may need to download and add these to your path manually.
