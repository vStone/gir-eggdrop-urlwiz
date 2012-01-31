# Partly based on 
# * url2irc by Lily (starlily@gmail.com)
# * rss-synd script by Andrew Scott
#
#

namespace eval ::urlwiz {
    variable urlwiz
    variable packages

    source urlwiz.conf

    set urlwiz(tlength)     60              ;# minimum url length for tinyurl (tinyurl is 18 chars..)

    set urlwiz(pubmflags)  "-|-"            ;# user flags required for use
    set urlwiz(ignore)      "bdkqr|dkqr"    ;# user flags script will ignore 
    set urlwiz(length)      12              ;# minimum url length for title (12 chars is the shortest url possible, equalling all)

    set urlwiz(delay)       2               ;# minimum seconds between use
    set urlwiz(timeout)     90000           ;# geturl timeout 
    set urlwiz(last)        13              ;# initialize sth silly here


    ### WARNING ### 
    # If you change any of following settings, make sure to adjust the database scheme to reflect those changes.
    # Also, if you changed the database scheme, this is the place where you would have to adjust stuff.
    ###############

    set urlwiz(db_url)      "url"           ;# Table name for urls.
    set urlwiz(db_tag)      "tag"           ;# Table to store tags.
    set urlwiz(db_urltag)   "urltag"        ;# Linking urls to the tags.

    set urlwiz(db_max_tag)  100             ;# Maximum length for a tag. Longer tags are ignored (field `tag` in `urltag` table)

}


proc ::urlwiz::init {args} {
    variable urlwiz
    variable version
    variable packages

    set version(number) "0.1" 
    set version(date)   "2012.01.30"


    package require http
    package require htmlparse
    package require uri

    set packages(mysql) [catch {package require mysqltcl}]; #store links.
    set packages(tls) [catch {package require tls}];
    

    setudef flag urlwiz
    setudef flag logurlwiz


    bind evnt -|- prerehash [namespace current]::deinit
    bind pubm $urlwiz(pubmflags) {*://*} [namespace current]::trigger

    bind pubm $urlwiz(pubmflags) "% !url*" [namespace current]::command_trigger

    putlog "URL Wiz $version(number) ($version(date)): Loaded."
}

proc ::urlwiz::deinit {args} {
    variable urlwiz

    catch {unbind evnt -|- prerehash [namespace current]::deinit}
    catch {unbind pubm $urlwiz(pubmflags) {*://:*} [namespace current]::trigger}

}

proc ::urlwiz::todb {alink} {
    variable packages
    if {$packages(mysql) != 0} {
        putlog "\[urlwiz\] error: could not save to db. required package mysqltcl not found"
        return 0;
    }
    
    upvar $alink link
    variable urlwiz

    array set tags {}
    set db [::mysql::connect -host $urlwiz(mysqlhost) -user $urlwiz(mysqluser) -password $urlwiz(mysqlpass)]
    ::mysql::use $db $urlwiz(mysqldb)

    foreach tag $link(tags) {
        set tag [::mysql::escape $db $tag]
        set tagsql "INSERT INTO `$urlwiz(db_tag)` (`tag`) VALUES ('$tag') ON DUPLICATE KEY UPDATE `count` = `count` + 1"
        ::mysql::exec $db $tagsql      
 
        set tags($tag) [::mysql::insertid $db]
##        puthelp "PRIVMSG #euronarp : Tag: $tag -- ID: $tags($tag)"
    }

    set url "'[::mysql::escape $db $link(url)]'"
    set tiny "''"
    
    if {[info exists link(tinyurl)]} {
        set tiny "'[::mysql::escape $db $link(tinyurl)]'"
    }

    set ref "'[::mysql::escape $db $link(ref)]'"
    set nick "'[::mysql::escape $db $link(nick)]'"
    set chan "'[::mysql::escape $db $link(chan)]'"
    set title "'[::mysql::escape $db $link(title)]'"

    set urlsql "INSERT INTO `$urlwiz(db_url)` ( `url`, `tinyurl`, `title` , `nick`, `reffed`, `channel`, `date` ) ";
    append urlsql "VALUES ( $url, $tiny , $title , $nick , $ref , $chan , [unixtime] )"

    ::mysql::exec $db $urlsql
    set urlid [::mysql::insertid $db]

    foreach tag [array names tags] {
        ::mysql::exec $db "INSERT INTO `$urlwiz(db_urltag)` ( `url_id` , `tag_id` ) VALUES ( '$urlid', '$tags($tag)' )"
    }

    ##mysqlescape string 
 
    

    ::mysql::close $db

    #puthelp "PRIVMSG #euronarp : todb($link(url)) - tags: $link(tags)"
}

proc ::urlwiz::command_trigger {nick host user chan text} {
    variable urlwiz

    #puthelp "PRIVMSG $chan ::DEBUG: $text"

    switch -glob $text {
        "!url last*" {[namespace current]::url_last $nick $chan $text}
	"!url search*" {[namespace current]::url_search $nick $chan $text}
	"!url respam*" {[namespace current]::url_respam $nick $chan $text}
	"!url reffed*" {[namespace current]::url_reffed $nick $chan $text}
	"!url stats" {[namespace current]::url_stats $nick $chan $text}
	"!url" -
	default {
	    puthelp "NOTICE $nick :\[URL usage\]:"
	    puthelp "NOTICE $nick :Last x url's (default 5)     : !url last \[x\]"
	    puthelp "NOTICE $nick :Search for keyword           : !url search <keyword>"
            puthelp "NOTICE $nick :Respam a url                 : !url respam <id>"
	    puthelp "NOTICE $nick :View reffered url's for nick : !url reffed \[nick\]"
	    puthelp "NOTICE $nick :Show some basic stats        : !url stats"
	    return
	}
    }
}

proc ::urlwiz::url_last {nick chan text} {

    variable urlwiz

    set db [::mysql::connect -host $urlwiz(mysqlhost) -user $urlwiz(mysqluser) -password $urlwiz(mysqlpass)]
    ::mysql::use $db $urlwiz(mysqldb)

    if {[string is double -strict [lindex $text 2]] && [lindex $text 2] <= 10} {
        puthelp "NOTICE $nick :\[URL\] Showing last [lindex $text 2] url's"
        set sqlsel "SELECT * FROM url ORDER BY url_id DESC LIMIT [lindex $text 2]"
    } else {
        puthelp "NOTICE $nick :\[URL\] Showing last 5 url's"
        set sqlsel "SELECT * FROM url ORDER BY url_id DESC LIMIT 5"
    }

    set result [::mysql::sel $db $sqlsel -list]

    foreach urlinfo $result {

        set currentime [clock seconds]
	set timeago [duration [expr {$currentime - [lindex $urlinfo 7]}]]

        if {[lindex $urlinfo 3] != ""} {
            puthelp "NOTICE $nick :\[URL [lindex $urlinfo 0]\] [lindex $urlinfo 3] ([lindex $urlinfo 2]) linked by [lindex $urlinfo 4] $timeago ago"
	} else {
            puthelp "NOTICE $nick :\[URL [lindex $urlinfo 0]\] [lindex $urlinfo 1] ([lindex $urlinfo 2]) linked by [lindex $urlinfo 4] $timeago ago"
	}
    }
}

proc ::urlwiz::url_search {nick chan text} {

    variable urlwiz

    set db [::mysql::connect -host $urlwiz(mysqlhost) -user $urlwiz(mysqluser) -password $urlwiz(mysqlpass)]
    ::mysql::use $db $urlwiz(mysqldb)

    set keyword [lrange $text 2 end]

    puthelp "NOTICE $nick :\[URL\] Searching for: $keyword"

    set sqlsel "SELECT * FROM url WHERE url LIKE '%$keyword%' OR title LIKE '%$keyword%' OR nick LIKE '%$keyword%' OR url_id LIKE '%$keyword%' ORDER BY url_id DESC LIMIT 5"
    set result [::mysql::sel $db $sqlsel -list]

    if {$result == ""} {puthelp "NOTICE $nick :\[URL\] Nothing found."}

    foreach urlinfo $result {
        set currentime [clock seconds]
	set timeago [duration [expr {$currentime - [lindex $urlinfo 7]}]]

        if {[lindex $urlinfo 3] != ""} {
            puthelp "NOTICE $nick :\[URL [lindex $urlinfo 0]\] [lindex $urlinfo 3] ([lindex $urlinfo 2]) linked by [lindex $urlinfo 4] $timeago ago"
	} else {
            puthelp "NOTICE $nick :\[URL [lindex $urlinfo 0]\] [lindex $urlinfo 1] ([lindex $urlinfo 2]) linked by [lindex $urlinfo 4] $timeago ago"
	}
    }
}

proc ::urlwiz::url_respam {nick chan text} {

    variable urlwiz

    set db [::mysql::connect -host $urlwiz(mysqlhost) -user $urlwiz(mysqluser) -password $urlwiz(mysqlpass)]
    ::mysql::use $db $urlwiz(mysqldb)

    set sqlsel "SELECT * FROM url WHERE url_id LIKE '[lindex $text 2]'"
    set result [::mysql::sel $db $sqlsel -list]

    if {$result == ""} {
        puthelp "PRIVMSG $chan :URL not found."
	return
    }

    foreach urlinfo $result {

        set currentime [clock seconds]
	set timeago [duration [expr {$currentime - [lindex $urlinfo 7]}]]

        if {[lindex $urlinfo 3] != ""} {
            puthelp "PRIVMSG $chan :\[URLrespam [lindex $urlinfo 0]\] [lindex $urlinfo 3] ([lindex $urlinfo 2]) linked by [lindex $urlinfo 4] $timeago ago"
	} else {
            puthelp "PRIVMSG $chan :\[URLrespam [lindex $urlinfo 0]\] [lindex $urlinfo 1] ([lindex $urlinfo 2]) linked by [lindex $urlinfo 4] $timeago ago"
	}
    }
}

proc ::urlwiz::url_reffed {nick chan text} {

    variable urlwiz

    set db [::mysql::connect -host $urlwiz(mysqlhost) -user $urlwiz(mysqluser) -password $urlwiz(mysqlpass)]
    ::mysql::use $db $urlwiz(mysqldb)

    set sqlsel "SELECT * FROM url WHERE reffed LIKE '[lindex $text 2]' ORDER BY url_id DESC LIMIT 5"
    set result [::mysql::sel $db $sqlsel -list]

    if {$result == ""} {
        puthelp "NOTICE $nick :No refs found for nick: [lindex $text 2]"
	return
    }

    puthelp "NOTICE $nick :\[URL\] Showing refs for nick: [lindex $text 2]"

    foreach urlinfo $result {

        set currentime [clock seconds]
	set timeago [duration [expr {$currentime - [lindex $urlinfo 7]}]]

        if {[lindex $urlinfo 3] != ""} {
            puthelp "NOTICE $nick :\[URL [lindex $urlinfo 0]\] [lindex $urlinfo 3] ([lindex $urlinfo 2]) linked by [lindex $urlinfo 4] $timeago ago"
	} else {
            puthelp "NOTICE $nick :\[URL [lindex $urlinfo 0]\] [lindex $urlinfo 1] ([lindex $urlinfo 2]) linked by [lindex $urlinfo 4] $timeago ago"
	}
    }
}

proc ::urlwiz::url_stats {nick chan text} {

    variable urlwiz

    set db [::mysql::connect -host $urlwiz(mysqlhost) -user $urlwiz(mysqluser) -password $urlwiz(mysqlpass)]
    ::mysql::use $db $urlwiz(mysqldb)

    set sqlsel "SELECT count(*) FROM url"
    set total [::mysql::sel $db $sqlsel -list]

    set sqlsel "select nick, count(*) as count from url group by nick order by count desc limit 5"
    set top5 [::mysql::sel $db $sqlsel -list]

    set sqlsel "select count(*) from url where tinyurl like ''"
    set shortened [::mysql::sel $db $sqlsel -list]

    set percentage [expr (double($shortened) / double($total)) * 100]
    set percentage [expr floor($percentage * 10) / 10]

    puthelp "NOTICE $nick :\[URL Stats\]:"
    puthelp "NOTICE $nick :There are $total links saved."
    puthelp "NOTICE $nick :$shortened links had to be shortened ($percentage\%)."

    puthelp "NOTICE $nick : "
    puthelp "NOTICE $nick :Top 5 linkers:"

    set i 1

    foreach poster $top5 {

        puthelp "NOTICE $nick :$i. [lindex $poster 0] ([lindex $poster 1] links)"
	set i [expr $i + 1]

    }



}

proc ::urlwiz::trigger {nick host user chan text} {
    variable urlwiz
    variable packages

    array set link {}
    array set tags {}
    set ref ""

    if {([channel get $chan urlwiz]) && ([expr [unixtime] - $urlwiz(delay)] > $urlwiz(last)) && (![matchattr $user $urlwiz(ignore)])} {
      ## If the first word is a reference to somebody, we should store a ref!
      set first [string range $text 0 [expr {[string first " " $text] - 1}]]
      if {[regexp -nocase {^(.+?)[.,:]?$} $first match posnick] && [onchan $posnick $chan]} {
        set ref "$posnick" 
        set text [lrange [split $text] 1 end]
      }
      ##puthelp  "PRIVMSG $chan :DEBUG: $text"
      foreach word [split $text] {
        if {[regexp {^(f|ht)tp(s|)://} $word] && [string length $word] >= $urlwiz(length) && ![regexp {://([^/:]*:([^/]*@|\d+(/|$))|.*/\.)} $word]} {
          ## New link, flush old one.
          if {[channel get $chan logurlwiz] && [info exists link(url)]} {
            set link(ref) "$ref"
            set link(tags) [array names tags]
            set link(nick) $nick
            set link(chan) $chan
            [namespace current]::todb link 
            array unset link
            array unset tags 
          }
        
          set urlwiz(last) [unixtime]

          set link(url) $word

          if {[string length $word] >= $urlwiz(tlength)} {
            set newurl [[namespace current]::tinyurl $word]
            set link(tinyurl) $newurl
          } else { 
            set newurl "" 
          }

          set urltitle [[namespace current]::urltitle $word]
          set link(title) $urltitle
          if {[string length $newurl]} {
            puthelp  "PRIVMSG $chan :\002$urltitle\002 ( $newurl ), linked by $nick"
          } else { 
            puthelp "PRIVMSG $chan :\002$urltitle\002, linked by $nick" 
          }
        #break
        ## endif url.
        } elseif {[regexp {^#([^\s]+)} $word - tag]} {
            set tags($tag) ""
        }
      }

    }

    if {[channel get $chan logurlwiz] && [channel get $chan urlwiz]} {

    }


    if {[channel get $chan logurlwiz] && [info exists link(url)]} {
      set link(ref) "$ref"
      set link(tags) [array names tags]
      set link(nick) $nick
      set link(chan) $chan

      [namespace current]::todb link 
      unset link
      unset tags
    }

    return 1

}

proc ::urlwiz::geturl {url args} {
    variable packages 
    array set URI [::uri::split $url] ;# Need host info from here
    while {1} {
        if {[regexp {^https} $url] && $packages(tls) != 0} {
            ::http::register https 443 ::tls::socket
        }
        eval "set token \[::http::geturl $url $args\]"
        if {![string match {30[1237]} [::http::ncode $token]]} {
            return $token
        }
        array set meta [set ${token}(meta)]
        if {![info exist meta(Location)]} {
            return $token
        }
        array set uri [::uri::split $meta(Location)]
        unset meta
        if {$uri(host) == ""} { set uri(host) $URI(host) }
        set url [eval ::uri::join [array get uri]]
    }
}



## This is pretty much a copy paste of url2irc :)
proc ::urlwiz::urltitle {url} {
    variable urlwiz
    variable packages
set agent "Mozilla/5.0 (X11; Linux i686; rv:2.0.1) Gecko/20100101 Firefox/4.0.1"
  if {[info exists url] && [string length $url]} {

    if {[regexp -nocase {(.*)\.(jpg|gif|jpeg|png|bmp)} $url]} {
        return "Picture"
    } elseif {[regexp -nocase {(.*)\.(mp3|wma|wav|flac|ogg)} $url]} {
        return "Audio"
    } elseif {[regexp -nocase {(.*)\.(swf|avi|wmv|mkv|mpg|ogv|mp4)} $url]} {
        return "Video"
    } elseif {[regexp -nocase {(.*)\.(pdf)} $url]} {
        return "PDF file"
    } 

    set http [::http::config -useragent $agent]
    set http [[namespace current]::geturl $url -timeout $urlwiz(timeout)]
    set data [split [::http::data $http] \n] ; ::http::cleanup $http
    set title ""
    if {[regexp -nocase {<title>(.*?)</title>} $data match title]} {
      set title [::htmlparse::mapEscapes $title]
#   this regsub is purely for youtube. 
      regsub -all {[\{\}]} $title "" title
      regsub -all " +" $title " " title
      set title [string trim $title]
      return $title
    } else {
      if {[regexp -nocase {(.*)\.(jpg|gif|jpeg|png|bmp)} $url]} {
        set $title "Picture"
      } elseif {[regexp -nocase {(.*)\.(mp3|wma|wav)} $url]} {
        set $title "Audio"
      } elseif {[regexp -nocase {(.*)\.(swf)} $url]} {
        set $title "Flash video"
      } elseif {[regexp -nocase {(.*)\.(pdf)} $url]} {
        set $title "PDF file"
      } else {
        return "Unknown"
      }
    }
  }
}

proc ::urlwiz::tinyurl {url} {
  variable urlwiz
  if {[info exists url] && [string length $url]} {
    set http [::http::geturl "http://tinyurl.com/create.php" -query [::http::formatQuery "url" $url] -timeout $urlwiz(timeout)]
    set data [split [::http::data $http] \n] ; ::http::cleanup $http
    for {set index [llength $data]} {$index >= 0} {incr index -1} {
      if {[regexp {href="http://tinyurl\.com/\w+"} [lindex $data $index] url]} {
        return [string map { {href=} "" \" "" } $url]
      }
    }
  }
 return ""
}



::urlwiz::init;
putlog "URLWiz Loadeth";
