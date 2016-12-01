> wpmanage.sh is a shell script to aid local development of Wordpress with version control.

It offers a command for dumping the database in a git friendly way, so
that updates to the database are "human readable" and "diff-able".
It also offers a command for quickly importing that database back into the
local or production server.

It assumes the local development and remote deployment database name and credentials 
are the same. But that can be resolved by git-ignoring `wp-config.php` and `wp_manage.conf`
and using seperate files for production vs staging.

There is also a function for adding an entry to the hosts file for the Wordpress site domain name.

It's useful for a local wordpress install to have the same domain name as production,
so there are no issues with hard-coded assets loading (e.g. anything in a post entry).
Note after running wpmanage.sh hosts, you will not be able to vist your production
site until removing the hosts entry; `wp_manage.sh hosts clean` will do it.

### Usage

* 'wp_manage.sh dump'
    Dumps database to 'database.sql',
    using credentials from 'wp_manage.conf' and 'wp-config.php'

* 'wp_manage.sh importdb'
    Imports database from 'database.sql',
    using credentials from 'wp_manage.conf' and 'wp-config.php'.
    If the database will be overwritten it will also generate
    a backup sql file with the name "db_bak_wpmanage_$(timestamp).sql"

* 'wp_manage.sh hosts'
    Adds localhost entries for "$sitedomain" and "www.$sitedomain"
	**(Requires admin console or sudo)**
	**(Should only be used on local computer)**

* 'wp_manage.sh hosts clean'
    Looks for dns entries in 'hosts' file ending with '#wp_manage_entry' comment
    and removes them.
	**(Requires admin console or sudo)**
	**(Should only be used on local computer)**

* 'wp_manage.sh [showconfig|config]'
    prints the loaded configuration. 

* 'wp_manage.sh [h|-h|help|-help|*]'
    prints this help message.

### Install
You will need to use a bash commandline in windows. Note: git for windows comes with a bash shell.
Create a `wp_manage.conf` in the directory that you will run `wp_manage.sh` from.
Configure it appropriately.

The hosts file changer function of this script requires 'unix2dos' and 'dos2unix', for converting line endings? You may need to download and add these to your path manually.


### Configure

`wp_manage.sh` relies on the file `wp_manage.conf`
Variables are extracted from `wp_manage.conf` via the `extract_config` function. 
`wp_manage.conf` should be in the directory that `wp_manage.sh` is excuted from, not necessarily where it is installed.


Copy , paste, then edit this section into a file 'wp_manage.conf'.
```
# Directory containing 'mysql' and 'mysqldump'
# Only necessary when mysql is not on $PATH
# e.g. on Windows with xampp or similar all in one A.M.P. stack.
mysqlpath="/c/Program Files (x86)/xampp/mysql/bin"

# For the 'importdb' command you _might_ need a mysql user who
# can create users and grant on the wordpress database (from "wp-config.php").
# If the user exists with grant privilege for that database,
# that user can be used instead of a higher privileged user i.e. root.

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
```
