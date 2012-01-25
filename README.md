# Description

This script grabs all urls (http only) on a irc channel 
(requires +urlwiz setting) and stores them in a database.

# Features

* support for tags (see below)
* stores who pasted the link
* stores for who the link was pasted 
  (if the line is starting with <nick> )
* only enable for specific channels (+urlwiz)
* supports logging if enabled for a channel (+urlwizlog)

## tags

Optionally, you can add tags to a url you are pasting by appending 
\#tags. These should be split up by spaces.

Also don't forget to add a space after the url or you would be
adding to the url in stead of specifying a tag.


# Prerequisites

* Eggdrop
* A mysql database
* Some tcl packages:
  * http
  * uri
  * htmlparse
  * mysqltcl
  * tls (optional)

# Instructions

## Database

Create a mysql database and use the urlwiz.sql file to generate 
the required structure:

    mysql -u admin -p localhost
    > CREATE DATABASE urlwiz;
    > GRANT USAGE ON *.* to 'urlwiz_user'@'localhost' IDENTIFIED BY 'P4ssw0r!)';
    > GRANT ALL PRIVILEGES ON 'urlwiz_db' TO 'urlwiz_user'@'localhost';
    > FLUSH PRIVILEGES;
    > exit
    Bye
    
    mysql -u urlwiz_user -p urlwiz_db < urlwiz.sql


## Configuration

Create a urlwiz.conf file with your settings the same dir as your
eggdrop configuration file. Define following settings.

    set urlwiz(mysqldb)   "db_schema" ;# name of mysql db
    set urlwiz(mysqluser) "db_user"   ;# username for the mysql db
    set urlwiz(mysqlpass) {P4ssw0r!)} ;# password for the mysql db
    set urlwiz(mysqlhost) "hostname"  ;# hostname for the mysql db


## Eggdrop

Edit your eggdrop configuration file and add the following:

    source scripts/urlwiz/urlwiz.tcl
