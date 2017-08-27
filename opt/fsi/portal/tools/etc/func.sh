#
#   Function script for fsi deploy server tools
#
#   This program is free software; you can redistribute it and/or modify it under the
#   terms of the GNU General Public License as published by the Free Software Foundation;
#   either version 3 of the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
#   without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#   See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License along with this program;
#   if not, see <http://www.gnu.org/licenses/>.
#
#
export funcver="1.1.31 - 03.03.2017"
export ls=""
export hostname=$(hostname -s)
export vitemp=$(/sbin/ifconfig eth0 | sed -n "2s/[^:]*:[ \t]*\([^ ]*\) .*/\1/p")
export vithost=$(hostname)
export ksc=1235155
export sshopts="-q -o userknownhostsfile=/dev/null -o stricthostkeychecking=false"  # outdated - please use g_ssh_options
export basedir="/opt/fsi"
export instdir="$basedir/inst"
export portaldir="$basedir/portal"
export pxedir="$basedir/pxe"
export macdir="$pxedir/sys"
export rcsysdir="$portaldir/etc/sys"
export rcbindir="$portaldir/bin/ctrl"

export regex_ip='\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b'
export regex_ip_dns='^(((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|((([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])))$'
export regex_mac='^([0-9a-f]{2}[:-]){5}([0-9a-f]{2})$'
export regex_port='port 22: No route to host*'
export regex_remotechanged='*WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED*'
export regex_nofile='No such file or directory'
export regex_createdir='t create directory'
export regex_masterip='^.*Master IP address: (.*)'
export regex_hostname='.*<hostname>.*'
export regex_char='^[0-9]+$'
export regex_bracket='^\[.*\]$'

export g_ssh_options="-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

export osver=$(sed -n 's/^.*[ ]\([0-9]\.[0-9]*\)[ .].*/\1/p' /etc/redhat-release)
export osmain=${osver%%.*}

if [ -z $progname ]; then
   export logfile="$portaldir/logs/tools.log"
else
   export logfile="$portaldir/logs/$progname.log"
fi
# write to file level
export debug="info"
export deb2scr="yes"          # write to screen
export rzenvconf="$progdir/../etc/rzenv.xml"
export xe="$progdir/../bin/xe"

if [ -f $rzenvconf ]; then                   # rz rausfinden
   rz=$(tac $portaldir/etc/rzenv.xml | sed -n "/$vithost/,/\<rz/p" | grep -i "\<rz")
   rz=${rz%%'>'*}
   export rz=${rz##*'<rz '}
else
   export rz="unknown"
fi

   

# Logging
tracemsg() {
   if [ "$debug" == "trace" ] || [ "$debug" == "press" ] || [ "$debug" == "sleep" ] ; then
      logmsg "TRACE  : $1" 3
   fi
}
debmsg() {
   if [ "$debug" == "debug" ] || [ "$debug" == "trace" ] || [ "$debug" == "press" ] || [ "$debug" == "sleep" ]; then
      logmsg "DEBUG  : $1" 7
   fi
}
warnmsg() {
   logmsg "WARN   : $1" 4
}
infmsg() {
   logmsg "INFO   : $1" 2
}
errmsg() {
   logmsg "ERROR  : $1" 5
}

function logmsg() {
   local timestamp=$(date +%H:%M:%S)
   local datetimestamp=$(date +%Y.%m.%d)"-"${timestamp}
   tmpmsg=$1
   tmp=${tmpmsg:0:5}
   #   if [ "$deb2scr" == "yes" ] || ( [ "$tmp" != "DEBUG" ] && [ "$tmp" != "TRACE" ] ); then
   if [ "$deb2scr" == "yes" ]; then
      tput -T xterm setaf $2
      echo $timestamp "$1" [${BASH_LINENO[1]}]
      tput -T xterm sgr0
   fi
   local progname=${0##*/}
   local pidnr=$$
   #   printf "%-19s : %-6d - %-30s %s\n" $datetimestamp,000 $pidnr $progname "$1" >>$logfile
   printf "%-19s : %-6d - %-19s %s %s \n" $datetimestamp $pidnr $progname "$1" "[${BASH_LINENO[1]}]" >>$logfile
}

change() {
   tracemsg "Function [$FUNCNAME] startet"
   local suche=$1
   local ersetze=$2
   local datei=$3
   local retc=0
   debmsg "  search [$suche]"
   debmsg "  change to [$ersetze]"
   debmsg "  file [$datei]"
   OUTPUT=$(2>&1 sed -i s%$suche%$ersetze%g $datei)
   
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot change $suche with $ersetze in $datei - $retc"
      errmsg "$OUTPUT"
   else
      debmsg "  ok"
   fi
   tracemsg "Function [$FUNCNAME] ended - rc=$retc"
   return $retc
}

change_param() {
   tracemsg "Function [$FUNCNAME] startet"
   local suche=$1
   local param=$2
   local datei=$3
   local retc=0
   debmsg "  search [$suche]"
   debmsg "  change to [$param]"
   debmsg "  file [$datei]"
   OUTPUT=$(2>&1 sed -i '/^'$suche'=/{h;s/=.*/='$param'/};${x;/^$/{s//'$suche'='$param'/;H};x}' $datei)
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot change $suche with $param in $datei - $retc"
      errmsg "$OUTPUT"
   else
      debmsg "  ok"
   fi
   tracemsg "Function [$FUNCNAME] ended - rc=$retc"
   return $retc
}

   


function warte() {
   wend=$1
   wtime=$2
   if [ -z $wend ]; then
      waitend=10
   else
      waitend=$wend
   fi
   if [ -z $wtime ]; then
      waittime=15
   else
      waittime=$wtime
   fi
   waitcount=0
   echo -n $(date +%H:%M:%S)" INFO   : $ls     Waiting ."
   while [ $waitcount -le $waitend ]; do
      echo -n "."
      sleep $waittime
      waitcount=$((waitcount+1))
   done
   echo " ok"
}

function trim() {
    # Determine if 'extglob' is currently on.
    local extglobWasOff=1
    shopt extglob >/dev/null && extglobWasOff=0 
    (( extglobWasOff )) && shopt -s extglob # Turn 'extglob' on, if currently turned off.
    # Trim leading and trailing whitespace
    local var=$1
    var=${var##+([[:space:]])}
    var=${var%%+([[:space:]])}
    var=${var%$'\n'}   # Remove a trailing newline.
    var=${var%$'\r'}
    (( extglobWasOff )) && shopt -u extglob # If 'extglob' was off before, turn it back off.
    echo -n "$var"  # Output trimmed string.
}


function isvarset(){
   local v="$1"
   [[ ! ${!v} && ${!v-unset} ]] && return 1 || return 0
}

function srvonline() {
   tracemsg "$ls  Function [$FUNCNAME] startet"
   ls="$ls  "
   tracemsg "$ls server [$1] online ?"
   local srv=$1
   if [ -z $srv ]; then
      errmsg "no server given"
      exit 40
   fi
   ping $srv -c 1  >/dev/nul 2>&1
   online=$?
   if [ $online -eq 0 ]; then
      tracemsg "$ls srv: $1 - online"
   elif [ $online -eq 1 ]; then
      tracemsg "$ls srv: $1 - offline "
   elif [ $online -eq 2 ]; then
      tracemsg "$ls srv: $1 - unknown server"
   else
      tracemsg "$ls srv: $1 - unknown error $online"
   fi
   ls=${ls:0:${#ls}-2}
   tracemsg "$ls  Function [$FUNCNAME] ended"
   # bash >4.2: ls=${ls:0:-2}
   return $online
}

function getsrvbyname() {
   local rc=0
   tracemsg "$ls  Function [$FUNCNAME] startet"
   ls="$ls  "
   
   local fqdn=$1
   local shortname=$2

   tracemsg "$ls fqdn: $fqdn"
   tracemsg "$ls shortname: $shortname"
   local dirmac
   local mac
   local tree
   
   # Global vars:
   if [ -z $macdir ]; then
      errmsg "global var macdir not set - abort"
      rc=30
   else
      tracemsg "$ls  mac dir: $macdir"
   fi
   
   tracemsg "$ls start searching sys dir"
   list=$(egrep -iRw "$fqdn|$shortname" $macdir/*/*.xml $macdir/*/*.cfg | cut -d "/" -f 6)

   for foundmac in $list ; do
      dirmac=$macdir/$foundmac
      mac=$(echo $foundmac | tr 'A-Z' 'a-z')
      
      if [[ ! $mac =~ $regex_mac ]]; then
         tracemsg "$ls  [$mac] is not a valid MAC / Config directory - ignore"
         continue
      else
      
         rccfgfile="$rcsysdir/$mac/rc.ini"
         rc_type=""
         rc_icon="default.png"
         rc_desc="no remote control"
         rc_http=""
         rc_ssh=""
         srv_type="none"
         srv_cmd=""
         mgmt_pw=""
         mgmt_pwc=""
         mgmt_user=""
         
         findfile=$(find $dirmac -type f -name '*.pxe' -printf "%f")
         tracemsg "$ls  file: $findfile"
         if [ -z $findfile ]; then
            continue
         fi
         findfile=${findfile%%.*}
         typ=${findfile##*-}
         #tracemsg "$ls  typ: $typ"
         if [ "$typ" == "" ]; then
            warnmsg "$ls  cannot find typ [$findfile][$mac] - ignore"
            continue
         fi
         
         if [[ "$typ"  =~ ^xen ]]; then
            tracemsg "$ls  found xen config in $dirmac"
            sfile="$dirmac/$findfile.xml"
            tracemsg "$ls  search file: $sfile"
            
            host=$(grep -m 1 -i "<hostname>" "$sfile"| sed -e 's/\(^.*>\)\(.*\)\(<.*$\)/\2/')
            tracemsg "$ls  host found: $host"
            
            if [ "$host" == "" ]; then
               errmsg "host name [$host] is empty - abort"
               rc=31
            else
               tracemsg "$ls   host = [$host]"
               if [ "$host" == "$fqdn" ] || [ "$host" == "$shortname" ]; then
                  tracemsg "$ls   found server config for $host"
                  if [ -f $rccfgfile ]; then
                     . $rccfgfile
                     tracemsg "$ls  $mgmt_pw / $mgmt_pwc / $mgmt_user"
                     
                     if [ "$rc_type" == "" ]; then
                        warnmsg "$ls  no remote control found"
                     else
                        tracemsg "$ls  rc_type: $rc_type"
                        srv_rctype=$rc_type
                     fi
                     
                     if [ "$mgmt_pwc" == "" ]; then
                        warnmsg "$ls  no mgmt password count found"
                     else
                        if [ "$mgmt_pw" == "" ]; then
                           warnmsg "$ls  no crypted password found"
                        else   
                           tracemsg "$ls   crypt ks pw: [$mgmt_pw]"
                           srv_userpw=""
                           srv_userpw=`$progdir/crypt --pw $mgmt_pw --code $mgmt_pwc`
                           if [ "$srv_userpw" == "" ]; then
                              errmsg "cannot decrypt password - abort"
                              rc=38
                              break
                           else
                              srv_user=$mgmt_user
                              tracemsg "$ls   server login user: $srv_user"
                           fi
                        fi
                     fi
                  else
                     warnmsg "$ls  found no remote control file - cannot get important server data [$host]"
                     rc=99
                     break
                  fi
                  
                  if [ $rc -eq 0 ]; then
                     srv_typ="xen"
                     srvver=$(grep -i "post-install-script" "$sfile")
                     srvver=${srvver%%'/ks/'*}
                     srvver=${srvver##*'/inst/'}
                     srv_ver=${srvver#xen}
                     srv_osmain=${srv_ver:0:1}
                     if [ "$srv_ver" != "" ]; then
                        tracemsg "$ls  found server version [$srv_ver]"
                        tracemsg "$ls  main os version [$srv_osmain]"
                     else
                        errmsg "cannot find server version - abort"
                        rc=32
                        break
                     fi   
                  else
                     errmsg "cannot find host pw - abort"
                     rc=33
                     break
                  fi

                  if [ $rc -eq 0 ]; then
                     tracemsg "$ls  search tree"
                     tree=$(grep -i "source type" "$sfile"| awk -F "/" '{print $5}')
                     srv_tree="$tree"
                     if [ "$srv_tree" != "" ]; then
                        tracemsg "$ls  found server tree [$srv_tree]"
                     else
                        errmsg "cannot find server tree - abort"
                        rc=34
                        break
                     fi   
                  fi
                  if [ $rc -eq 0 ]; then
                     debmsg "$ls  get pool name"
                     xenpoolfile=$dirmac/xen$srv_osmain.conf
                     tracemsg "$ls   poolfile=$xenpoolfile"
                     
                     srv_pool=$(grep -i "\\bpool\\b" "$xenpoolfile"| awk -F "=" '{print $2}')
                     srv_pool=${srv_pool%#*}   # remove comments
                     srv_pool=$(trim "$srv_pool")
                     srv_pool=$(echo $srv_pool  | sed -e 's/^"//'  -e 's/"$//' -e "s/^'//"  -e "s/'$//")

                     if [ "$srv_pool" != "" ]; then
                        tracemsg "$ls  found server pool [$srv_pool]"
                        srv_log="$instdir/$srv_tree/ks/log/${shortname}.log"
                        srv_info="$instdir/$srv_tree/ks/pool/$srv_pool/info/${shortname}"
                     else
                        errmsg "cannot find server pool - abort"
                        rc=35
                        break
                     fi   

                  fi
                  if [ $rc -eq 0 ]; then
                     srv_mac=$mac
                  else
                     errmsg "something wrong - do not assign mac"
                  fi
                  debmsg "$ls  found my server [$fqdn] - break now"
                  break 
               fi
            fi
         elif [[ "$typ" =~ ^esxi ]]; then
            tracemsg "$ls  found esxi config"
            sfile="$dirmac/$findfile.cfg"
            tracemsg "$ls  search file: $sfile"
            # host=`cat "$sfile"| grep -i "hostname=" | awk -F "hostname=" '{print $2}' `
            host=`grep -m 1 -i "hostname=" "$sfile" | awk -F "hostname=" '{print $2}' `
            host=${host## }
            host=${host%% }
            host=${host%$'\n'}   # Remove a trailing newline.
            host=${host%$'\r'}
            tracemsg "$ls  host found: $host"
            
            if [ "$host" == "" ]; then
               errmsg "host name [$host] is empty - abort"
               rc=36
            else
               if [ "$host" == "$fqdn" ] || [ "$host" == "$shortname" ]; then
                  sfile="$dirmac/ks-$typ.cfg"
                  

                  if [ -f $rccfgfile ]; then
                     . $rccfgfile
                     tracemsg "$ls  $mgmt_pw / $mgmt_pwc / $mgmt_user"
                     
                     if [ "$rc_type" == "" ]; then
                        warnmsg "$ls  no remote control found"
                     else
                        tracemsg "$ls  rc_type: $rc_type"
                        srv_rctype=$rc_type
                     fi
                     
                     if [ "$mgmt_pwc" == "" ]; then
                        warnmsg "$ls  no mgmt password count found"
                     else
                        if [ "$mgmt_pw" == "" ]; then
                           warnmsg "$ls  no crypted password found"
                        else   
                           tracemsg "$ls   crypt ks pw: [$mgmt_pw]"
                           srv_userpw=""
                           srv_userpw=`$progdir/crypt --pw $mgmt_pw --code $mgmt_pwc`
                           if [ "$srv_userpw" == "" ]; then
                              errmsg "cannot decrypt password - abort"
                              rc=38
                              break
                           else
                              srv_user=$mgmt_user
                              tracemsg "$ls   server login user: $srv_user"
                           fi
                        fi
                     fi
                  else
                     warnmsg "$ls  found no remote control file - cannot get important server data [$host]"
                     rc=99
                     break
                  fi
                  
                  if [ $rc -eq 0 ]; then
                     if [ -z $mgmt_pw ]; then
                        warnmsg "no mgmt password found"
                     fi
                  fi
                        
                  if [ $rc -eq 0 ]; then
                     tracemsg "$ls   srv: [$host]"
                     srv_typ="esxi"
                     srv_ver=${typ#esxi}
                     srv_osmain=${srv_ver:0:1}
                     if [ "$srv_ver" != "" ]; then
                        tracemsg "$ls  found server version [$srv_ver]"
                        tracemsg "$ls  os main version: [$srv_osmain]"
                     else
                        errmsg "cannot find server version - abort"
                        rc=39
                        break
                     fi   
                        
                  fi
                  
                  
                  if [ $rc -eq 0 ]; then
                     tracemsg "$ls   set srv vars"
                     srv_tree="$typ"
                     srv_log="$instdir/$srv_tree/ks/log/${shortname}.log"
                     srv_info="$instdir/$srv_tree/ks/log/info/${fqdn}"
                  fi
                  if [ $rc -eq 0 ]; then
                     tracemsg "$ls  get virtual center name"
                     srv_vc=$(grep -i "#vc:" "$sfile" | awk -F ":" '{print $2}')
                     srv_vc=$(trim "$srv_vc")
                     
                     if [ "$srv_vc" == "" ]; then
                        tracemsg "$ls   no virtual center found - set to none"
                        srv_vc="none"
                     fi
                     srv_log="$instdir/$srv_tree/ks/log/${shortname}.log"
                     srv_info="$instdir/$srv_tree/ks/log/info/${shortname}"
                  fi

                  if [ $rc -eq 0 ]; then
                     srv_mac=$mac
                  else
                     errmsg "something wrong - do not assign mac"
                  fi
                  break
               fi
            fi
         elif [[ "$typ" =~ ^co ]]; then
            tracemsg "$ls  found centos config"
            sfile="$dirmac/$findfile.cfg"
            tracemsg "$ls   file: $sfile"
            host=$(grep -m 1 -i '\-\-hostname ' $sfile | sed 's/.*hostname \(.[^ \t]*\)[ \t]*\(.[^ \t]*\)\(.*\)/\1/')
            tracemsg "$ls   hostname: $host"
            
            if [ "$host" == "" ]; then
               errmsg "host name [$host] is empty - abort"
               rc=40
            else
               if [ "$host" == "$fqdn" ] || [ "$host" == "$shortname" ]; then
                  
                  if [ -f $rccfgfile ]; then
                     . $rccfgfile
                     tracemsg "$ls  $mgmt_pw / $mgmt_pwc / $mgmt_user"
                     
                     if [ "$rc_type" == "" ]; then
                        warnmsg "$ls  no remote control found"
                     else
                        tracemsg "$ls  rc_type: $rc_type"
                        srv_rctype=$rc_type
                     fi
                     
                     if [ "$mgmt_pwc" == "" ]; then
                        warnmsg "$ls  no mgmt password count found"
                     else
                        if [ "$mgmt_pw" == "" ]; then
                           warnmsg "$ls  no crypted password found"
                        else   
                           tracemsg "$ls   crypt ks pw: [$mgmt_pw]"
                           srv_userpw=""
                           srv_userpw=`$progdir/crypt --pw $mgmt_pw --code $mgmt_pwc`
                           if [ "$srv_userpw" == "" ]; then
                              errmsg "cannot decrypt password - abort"
                              rc=38
                              break
                           else
                              srv_user=$mgmt_user
                              tracemsg "$ls   server login user: $srv_user"
                              srv_typ="co"
                              srv_ver=${typ#co}
                              srv_osmain=${srv_ver:0:1}
                              srv_tree=$typ
                           fi
                        fi
                     fi
                  else
                     warnmsg "$ls  found no remote control file - cannot get important server data [$host]"
                     rc=99
                     break
                  fi
                  
                  sfile="$dirmac/$typ.cfg"
                  if [ $rc -eq 0 ]; then
                     tmodel=$(grep -i "#model: " $sfile| awk -F "#model: " '{print $2}' )
                     tmodel=$(trim "$tmodel")
                     if [ "$tmodel" == "" ]; then
                        tracemsg "$ls   cannot get centos model - set to none for [$host]"
                        srv_model="none"
                     else
                        tracemsg "$ls   model $tmodel"
                        srv_model=$tmodel
                     fi
                  fi
                  
                  if [ $rc -eq 0 ]; then
                     srv_log="$instdir/$srv_tree/ks/log/${shortname}.log"
                     srv_info="$instdir/$srv_tree/ks/log/info/${fqdn}"
                  fi
                  if [ $rc -eq 0 ]; then
                     srv_mac=$mac
                  else
                     errmsg "something wrong - do not assign mac"
                  fi
                  break
               fi
            fi
         elif [[ "$typ" =~ ^rh ]]; then
            tracemsg "$ls  found redhat config"
            sfile="$dirmac/$findfile.cfg"
            tracemsg "$ls   file: $sfile"
            host=$(grep -m 1 -i '\-\-hostname ' $sfile | sed 's/.*hostname \(.[^ \t]*\)[ \t]*\(.[^ \t]*\)\(.*\)/\1/')
            tracemsg "$ls   hostname: $host"
            
            if [ "$host" == "" ]; then
               errmsg "host name [$host] is empty - abort"
               rc=44
            else
               if [ "$host" == "$fqdn" ] || [ "$host" == "$shortname" ]; then
                  if [ -f $rccfgfile ]; then
                     . $rccfgfile
                     tracemsg "$ls  $mgmt_pw / $mgmt_pwc / $mgmt_user"
                     
                     if [ "$rc_type" == "" ]; then
                        warnmsg "$ls  no remote control found"
                     else
                        tracemsg "$ls  rc_type: $rc_type"
                        srv_rctype=$rc_type
                     fi
                     
                     if [ "$mgmt_pwc" == "" ]; then
                        warnmsg "$ls  no mgmt password count found"
                     else
                        if [ "$mgmt_pw" == "" ]; then
                           warnmsg "$ls  no crypted password found"
                        else   
                           tracemsg "$ls   crypt ks pw: [$mgmt_pw]"
                           srv_userpw=""
                           srv_userpw=`$progdir/crypt --pw $mgmt_pw --code $mgmt_pwc`
                           if [ "$srv_userpw" == "" ]; then
                              errmsg "cannot decrypt password - abort"
                              rc=38
                              break
                           else
                              srv_user=$mgmt_user
                              tracemsg "$ls   server login user: $srv_user"
                              srv_typ="rh"
                              srv_ver=${typ#rh}
                              srv_osmain=${srv_ver:0:1}
                              srv_tree=$typ
                           fi
                        fi
                     fi
                  else
                     warnmsg "$ls  found no remote control file - cannot get important server data [$host]"
                     rc=99
                     break
                  fi

                  sfile="$dirmac/$typ.cfg"
                  if [ $rc -eq 0 ]; then
                     tmodel=$(grep -i "#model: " $sfile| awk -F "#model: " '{print $2}' )
                     tmodel=$(trim "$tmodel")
                     if [ "$tmodel" == "" ]; then
                        tracemsg "$ls   cannot get centos model - set to none for [$host]"
                        srv_model="none"
                     else
                        tracemsg "$ls   model $tmodel"
                        srv_model=$tmodel
                     fi
                  fi
                  if [ $rc -eq 0 ]; then
                     srv_log="$instdir/$srv_tree/ks/log/${shortname}.log"
                     srv_info="$instdir/$srv_tree/ks/log/info/${fqdn}"
                  fi
                  if [ $rc -eq 0 ]; then
                     srv_mac=$mac
                  else
                     errmsg "something wrong - do not assign mac"
                  fi
                  break
               fi
            fi
         else
            tracemsg "$ls   server in [$mac] unsupported typ - abort"
         fi
      fi
   done
   if [ "$srv_mac" == "" ]; then
      errmsg "$ls no server config found - abort"
      rc=48
   fi
   
   ls=${ls:0:${#ls}-2}
   tracemsg "$ls  Function [$FUNCNAME] ended - rc=$rc"
   return $rc
}
         
function get_srv_data() {
   local rc=0
   tracemsg "$ls  Function [$FUNCNAME] startet"
   ls="$ls  "
   
   local tosearch=$1
   
   local shortname
   local fqdn
   local dirmac
   local ipaddr
   local mac
   local findfile
   local typ
   local sfile
   local user
   local pass
   local srvtyp
   local srvver
   local host
   local tmodel
   
   # Set global return vars to zero
   srv_typ=""
   srv_ver=""
   srv_osmain=""
   srv_user=""
   srv_userpw=""
   srv_log=""
   srv_mac=""
   srv_fqdn=""
   srv_shortname=""
   srv_ip=""
   srv_info=""
   
   srv_model="-"
   srv_pool="-"
   srv_vc="-"
   srv_hw="-"
   
   
   # Global vars:
   if [ -z $macdir ]; then
      errmsg "global var macdir not set - abort"
      rc=49
   fi
   
   if [ -z $tosearch ]; then
      errmsg "no search parameter found - abort"
      rc=50
   fi
   
   if [ $rc -eq 0 ] ; then
      if [[ $tosearch =~ $regex_mac ]]; then                                             # search for server data with mac
         tracemsg "$ls  get mac to search [$tosearch]"
         tosearch=$(echo $tosearch | tr ':' '-')
         if [ -d $macdir/$tosearch ]; then
            tracemsg "$ls  found server config for mac [$tosearch]"
            srv_mac=$tosearch
            findfile=$(find $macdir/$tosearch -type f -name '*.pxe' -printf "%f")
            tracemsg "$ls  file: $findfile"
            findfile=${findfile%%.*}
            typ=${findfile##*-}
            tracemsg "$ls  typ: $typ"
            
            if [[ "$typ"  =~ ^xen ]]; then
               tracemsg "$ls  found xen config"
               sfile="$macdir/$tosearch/$findfile.xml"
               tracemsg "$ls  search file: $sfile"
               host=`grep -i "<hostname>" "$sfile"| sed -e 's/\(^.*>\)\(.*\)\(<.*$\)/\2/'`
               host=${host## }
               host=${host%% }
               host=${host%$'\n'}   # Remove a trailing newline.
               host=${host%$'\r'}
               tracemsg "$ls  host found: $host"
               
               if [ "$host" == "" ]; then
                  warnmsg "$ls  ==> cannot find host name, it is empty - abort"
                  rc=51
               else
                  ipaddr=$(dig -4 $host +short)
                  if [ -z $ipaddr ]; then
                     tracemsg "$ls no fqdn hostname [$host] - try if short name"
                     ipaddr=$(host $host | awk '{print $NF}')
                     if [ -z $ipaddr ]; then
                        errmsg "cannot find ip for [$host] - no server name or dns not configure"
                        rc=52
                     elif [ "$ipaddr" == "3(NXDOMAIN)" ]; then
                        tracemsg "cannot find fqdn for [$host] - no server name or dns not configure"
                        rc=53
                     else
                        tracemsg "$ls found server [$host] short name"
                        tracemsg "$ls  ip: [$ipaddr]"
                        srv_shortname=$host
                        srv_ip=$ipaddr
                        fqdn="$(dig -x $srv_ip +short)"
                        fqdn="$(echo $fqdn | tr 'A-Z' 'a-z')"
                        srv_fqdn="${fqdn%.}"                                                       # remove final dot which is always appended by dig
                        if [ -z $srv_fqdn ]; then
                           errmsg "cannot resolv ip addr [$ipaddr] - abort"
                           rc=54
                        else
                           tracemsg "$ls  cmd: getsrvbyname $srv_fqdn $srv_shortname"
                           getsrvbyname $srv_fqdn $srv_shortname
                           rc=$?
                        fi
                     fi
                  else
                     tracemsg "$ls found fqdn name [$host]"
                     srv_fqdn=$host
                     srv_ip=$ipaddr
                     srv_shortname="${host%%.*}"
                     getsrvbyname $srv_fqdn $srv_shortname
                     rc=$?
                  fi
               fi
            elif [[ "$typ" =~ ^esxi ]]; then
               tracemsg "$ls  found esxi config"
               sfile="$macdir/$tosearch/$findfile.cfg"
               tracemsg "$ls  search file: $sfile"
               host=`grep -i "hostname=" "$sfile" | awk -F "hostname=" '{print $2}' `
               host=${host## }
               host=${host%% }
               host=${host%$'\n'}   # Remove a trailing newline.
               host=${host%$'\r'}
               tracemsg "$ls  host found: $host"
               
               if [ "$host" == "" ]; then
                  errmsg "host name [$host] is empty - abort"
                  rc=60
               else
                  ipaddr=$(dig -4 $host +short)
                  if [ -z $ipaddr ]; then
                     tracemsg "$ls no fqdn hostname [$host] - try if short name"
                     ipaddr=$(host $host | awk '{print $NF}')
                     if [ -z $ipaddr ]; then
                        errmsg "cannot find ip for [$host] - no server name or dns not configure"
                        rc=61
                     elif [ "$ipaddr" == "3(NXDOMAIN)" ]; then
                        tracemsg "cannot find fqdn for [$host] - no server name or dns not configure"
                        rc=62
                     else
                        tracemsg "$ls found server [$host] short name"
                        srv_shortname=$host
                        srv_ip=$ipaddr
                        fqdn="$(dig -x $ip +short)"
                        fqdn="$(echo $fqdn | tr 'A-Z' 'a-z')"
                        srv_fqdn="${fqdn%.}"                                                       # remove final dot which is always appended by dig
                        if [ -z $srv_fqdn ]; then
                           errmsg "cannot resolv ip addr [$ipaddr] - abort"
                           rc=63
                        else
                           tracemsg "$ls  cmd: getsrvbyname $srv_fqdn $srv_shortname"
                           getsrvbyname $srv_fqdn $srv_shortname
                           rc=$?
                        fi
                     fi
                  else
                     tracemsg "$ls found fqdn name [$host]"
                     srv_fqdn=$host
                     srv_ip=$ipaddr
                     srv_shortname="${host%%.*}"
                     getsrvbyname $srv_fqdn $srv_shortname
                     rc=$?
                  fi
               fi
            elif [[ "$typ" =~ ^co ]]; then
               tracemsg "$ls  found centos config"
               sfile="$macdir/$tosearch/$findfile.cfg"
               tracemsg "$ls   file: $sfile"
               host=$(grep -m 1 -i '\-\-hostname ' $sfile | sed 's/.*hostname \(.[^ \t]*\)[ \t]*\(.[^ \t]*\)\(.*\)/\1/')
               # host=$(cat "$sfile" | grep -i '\-\-hostname ' | sed 's/.*hostname \(.[^ \t]*\)[ \t]*\(.[^ \t]*\)\(.*\)/\1/')
               # host=$(cat "$sfile"| grep -i "hostname=" | awk -F "hostname=" '{print $2}' )
               tracemsg "$ls   hostname: $host"
               
               if [ "$host" == "" ]; then
                  errmsg "host name [$host] is empty - abort"
                  rc=64
               else
                  ipaddr=$(dig -4 $host +short)
                  if [ -z "$ipaddr" ]; then
                     tracemsg "$ls no fqdn hostname [$host] - try if short name"
                     ipaddr=$(host $host | awk '{print $NF}')
                     if [ -z $ipaddr ]; then
                        errmsg "cannot find ip for [$host] - no server name or dns not configure"
                        rc=65
                     elif [ "$ipaddr" == "3(NXDOMAIN)" ]; then
                        tracemsg "cannot find fqdn for [$host] - no server name or dns not configure"
                        rc=66
                     else
                        tracemsg "$ls found server [$host] short name"
                        srv_shortname=$host
                        srv_ip=$ipaddr
                        fqdn="$(dig -x $ip +short)"
                        fqdn="$(echo $fqdn | tr 'A-Z' 'a-z')"
                        srv_fqdn="${fqdn%.}"                                                       # remove final dot which is always appended by dig
                        if [ -z $srv_fqdn ]; then
                           errmsg "cannot resolv ip addr [$ipaddr] - abort"
                           rc=67
                        else
                           tracemsg "$ls  cmd: getsrvbyname $srv_fqdn $srv_shortname"
                           getsrvbyname $srv_fqdn $srv_shortname
                           rc=$?
                        fi
                     fi
                  else
                     tracemsg "$ls found fqdn name [$host]"
                     srv_fqdn=$host
                     srv_ip=$ipaddr
                     srv_shortname="${host%%.*}"
                     getsrvbyname $srv_fqdn $srv_shortname
                     rc=$?
                  fi
               fi                     
            elif [[ "$typ" =~ ^rh ]]; then
               tracemsg "$ls  found redhat config"
               sfile="$macdir/$tosearch/$findfile.cfg"
               tracemsg "$ls   file: $sfile"
               host=$(grep -m 1 -i '\-\-hostname ' $sfile | sed 's/.*hostname \(.[^ \t]*\)[ \t]*\(.[^ \t]*\)\(.*\)/\1/')
               # host=$(cat "$sfile" | grep -i '\-\-hostname ' | sed 's/.*hostname \(.[^ \t]*\)[ \t]*\(.[^ \t]*\)\(.*\)/\1/')
               # host=$(cat "$sfile"| grep -i "hostname=" | awk -F "hostname=" '{print $2}' )
               tracemsg "$ls   hostname: $host"
               
               if [ "$host" == "" ]; then
                  errmsg "host name [$host] is empty - abort"
                  rc=68
               else
                  ipaddr=$(dig -4 $host +short)
                  if [ -z $ipaddr ]; then
                     tracemsg "$ls no fqdn hostname [$host] - try if short name"
                     ipaddr=$(host $host | awk '{print $NF}')
                     if [ -z $ipaddr ]; then
                        errmsg "cannot find ip for [$host] - no server name or dns not configure"
                        rc=69
                     elif [ "$ipaddr" == "3(NXDOMAIN)" ]; then
                        tracemsg "cannot find fqdn for [$host] - no server name or dns not configure"
                        rc=70
                     else
                        tracemsg "$ls found server [$host] short name"
                        srv_shortname=$host
                        srv_ip=$ipaddr
                        fqdn="$(dig -x $ip +short)"
                        fqdn="$(echo $fqdn | tr 'A-Z' 'a-z')"
                        srv_fqdn="${fqdn%.}"                                                       # remove final dot which is always appended by dig
                        if [ -z $srv_fqdn ]; then
                           errmsg "cannot resolv ip addr [$ipaddr] - abort"
                           rc=71
                        else
                           tracemsg "$ls  cmd: getsrvbyname $srv_fqdn $srv_shortname"
                           getsrvbyname $srv_fqdn $srv_shortname
                           rc=$?
                        fi
                     fi
                  else
                     tracemsg "$ls found fqdn name [$host]"
                     srv_fqdn=$host
                     srv_ip=$ipaddr
                     srv_shortname="${host%%.*}"
                     getsrvbyname $srv_fqdn $srv_shortname
                     rc=$?
                  fi
               fi                     
            else
               tracemsg "$ls   server in [$mac] unsupported typ - ignore"
            fi
         else
            errmsg "searched mac dir not found [$tosearch] - abort"
            rc=72
         fi
         
      elif [[ $tosearch =~ $regex_ip ]]; then                                              # search for server data with ip
         tracemsg "$ls  get ip [$tosearch] to search"
         ipaddr=$tosearch
         srv_ip=$ipaddr
         
         fqdn="$(dig -x $ipaddr +short)"
         if [ -z $fqdn ]; then
            tracmsg "Cannot find fqdn to [$ipaddr] - abort"
            rc=73
         else
            infmsg "$ls  found fqdn server config for [$tosearch]"
            fqdn="$(echo $fqdn | tr 'A-Z' 'a-z')"
            fqdn="${fqdn%.}"                                                              # remove final dot which is always appended by dig
            srv_fqdn=$fqdn
            srv_shortname="${fqdn%%.*}"
            if [ -z $srv_shortname ]; then
               errmsg "cannot get shortname from [$srv_fqdn] - abort"
               rc=74
            else
               getsrvbyname $srv_fqdn $srv_shortname
               rc=$?
            fi
         fi

      else                                                                                # search for server data with server name
         tracemsg "$ls is it a server name [$tosearch] ?"
         ipaddr=$(dig -4 $tosearch +short)
         if [ -z $ipaddr ]; then
            tracemsg "$ls no fqdn hostname [$tosearch] - try if short name"
            ipaddr=$(host $tosearch | awk '{print $NF}')
            if [ -z $ipaddr ]; then
               errmsg "cannot find ip for [$tosearch] - no server name or dns not configure"
               rc=75
            elif [ "$ipaddr" == "3(NXDOMAIN)" ]; then
               tracemsg "cannot find fqdn for [$tosearch] - no server name or dns not configure"
               rc=76
            else
               tracemsg "$ls found server [$tosearch] short name"
               srv_shortname=$tosearch
               srv_ip=$ipaddr
               fqdn="$(dig -x $srv_ip +short)"
               fqdn="$(echo $fqdn | tr 'A-Z' 'a-z')"
               srv_fqdn="${fqdn%.}"                                                       # remove final dot which is always appended by dig
               if [ -z $srv_fqdn ]; then
                  errmsg "cannot resolv ip addr [$ipaddr] - abort"
                  rc=77
               else
                  tracemsg "$ls  cmd: getsrvbyname $srv_fqdn $srv_shortname"
                  getsrvbyname $srv_fqdn $srv_shortname
                  rc=$?
               fi
            fi
         else
            tracemsg "$ls found fqdn name [$tosearch]"
            srv_fqdn=$tosearch
            srv_ip=$ipaddr
            srv_shortname="${tosearch%%.*}"
            getsrvbyname $srv_fqdn $srv_shortname
            rc=$?
         fi
      fi
   fi
   
   ls=${ls:0:${#ls}-2}
   tracemsg "$ls  Function [$FUNCNAME] ended - rc=$rc"
   return $rc
}


function dir_contains() {
   local retc=0
   tracemsg "$ls  Function [$FUNCNAME] startet"
   ls="$ls  "
   local dir=$1
   local filesonly=$2
   if [ -z $filesonly ]; then
      filesonly=0
   elif [ "$filesonly" == "1" ] || [ "$filesonly" == "file" ] || [ "$filesonly" == "fo" ]; then
      filesonly=1
   else
      filesonly=0
   fi
   
   tracemsg "$ls check dir content: $dir"
   if [ -z $dir ]; then
      errmsg "no dir to check given - abort"
      retc=3 # error
   else
      if [ -d $dir ]; then
         if [ "`ls -A $dir 2>/dev/null`" ]; then
            if (( $filesonly )); then
               out=$(find $dir -type f)
               local found=$?
               if [ $found -eq 0 ]; then
                  retc=0
               else
                  retc=1
               fi
            else
               retc=0  # dir content found
            fi
         else
           retc=1  # empty
         fi
      else
         retc=2 # dir not exist
      fi
   fi

   ls=${ls:0:${#ls}-2}
   tracemsg "$ls  Function [$FUNCNAME] ended - rc=$retc"
   return $retc
}

function crypw() {
   local notfound=1
   local epw=""
   while (( $notfound )); do
      pwc=$RANDOM$RANDOM
      pwv=$(2>/dev/null /opt/fsi/portal/tools/crypt --pw $pw --code $pwc)
      if [[ "$pwv" == *\`* ]] || [[ "$pwv" == *\'* ]] || [[ "$pwv" == *\´* ]] || [[ "$pwv" == *\\* ]] || [[ "$pwv" == *\&* ]] || [[ "$pwv" == *\/* ]] || [[ "$pwv" == *\^* ]] || [[ "$pwv" == *\?* ]] || [[ "$pwv" == *\#* ]]; then continue; fi
      epw=$(2>/dev/null /opt/fsi/portal/tools/crypt --pw $pwv --code $pwc)
      if [ "$epw" == "$pw" ]; then notfound=0; fi
   done
}

function containsElement () { 
   # http://stackoverflow.com/questions/3685970/check-if-an-array-contains-a-value
   for e in "${@:2}"; do 
      [[ "$e" = "$1" ]] && return 0
   done
   return 1
}

export -f crypw
export -f trim
export -f warte
export -f change
export -f logmsg
export -f errmsg
export -f infmsg
export -f warnmsg
export -f debmsg
export -f tracemsg
export -f isvarset
export -f srvonline
export -f get_srv_data
export -f dir_contains
export -f containsElement

if ! rpm -q sshpass --quiet; then
   errmsg "RPM package $sshpassrpm is not installed. Sshpass command is not available"
   exit 99
fi
if [ ! -f /usr/bin/dig ]; then
   errmsg "program dig does not exist - abort"
   exit 98
fi
if [ ! -f /usr/bin/host ]; then
   errmsg "program host does not exist - abort"
   exit 98
fi


# End