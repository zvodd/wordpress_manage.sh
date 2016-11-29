### Usage

 'wp_manage.sh dump'
    Dumps database to 'database.sql',
    using credentials from 'wp_manage.conf' and 'wp-config.php'
 'wp_manage.sh importdb'
    Imports database from 'database.sql',
    using credentials from 'wp_manage.conf' and 'wp-config.php'
 'wp_manage.sh hosts'
    Looks for dns entries in 'hosts' file,
    adds or removes depending on comment '#wp_manage_entry'


### Configure

wp_manage.sh relies on the file 'wp_manage.conf'
That will be executed as a bash script internally,
to set the following required variables.
Copy , paste, then edit this section into 'wp_manage.conf'

````
# Directory containing 'mysql' and 'mysqldump'
# Only necessary when mysql is not on $PATH, i.e. on Windows
mysqlpath="/c/Program Files (x86)/mysql/bin"

# mysql root username
mysqluser="root"

# mysql root password
mysqluserpw="mysql"

# wordpress directory path
sitefolder="./site/public_html/wordpress"

# filepath for database dump
dumpfile="./database.sql"

# domain name (not including 'www') for wordpress site.
sitedomain="example.com"
````

### Pre-Install

On msys in windows (i.e. git for windows):
This script requires 'unix2dos' and 'dos2unix',
for converting line endings.
You may need to download and add these to your path manually.
