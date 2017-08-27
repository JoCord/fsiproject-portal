any [ 'get', 'post' ] => '/showxp/:pool' => sub {
   my $weburl = '/showxp';
   session 'now' => $weburl;
   local *__ANON__ = "dance: $weburl";                                                                                             # default if no function for caller sub
   $flvl=2;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: $weburl");
   my $retc   = 0;
   my $errmsg = "";

   if ( !session('logged_in') ) {
      $logger->info("$ll  redirect to root web site / ");
      return redirect '/';
   } else {

      if ( request->method() eq "GET" ) {
         $logger->debug("$ll  GET Section  [" . session('user') . "]");
         my $xenpool = param('pool');

         if ( "$xenpool" eq "" ) {
            $looger->error("cannot detect xen pool  [" . session('user') . "]");
            set_flash("!E:cannot detect xen pool");
            return redirect '/overview';
         } else {
            $logger->trace("$ll  pool: [$xenpool]  [" . session('user') . "]");

            my $sess_reload = $weburl . '/' . $xenpool;
            $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
            session 'reload' => $sess_reload;
            $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
            $retc = backurl_add("$sess_reload");

            my $vmshash_ref;
            my $vmnethash_ref;
            my $vmhdhash_ref;
            my $hosthash_ref;
            my $srhash_ref;
            my $nethash_ref;
            my $masterhash_ref;
            my $xenhash_ref;

            my $xenver = db_get_typ_pool($xenpool);

            if ( "$xenver" eq "0" ) {
               $looger->error("cannot detect xen pool version  [" . session('user') . "]");
               set_flash("!E:cannot detect xen pool version");
               return redirect '/overview';
            } else {

               $retc = db_reload();
               if ($retc) {
                  $looger->error("cannot reload db for xen pool $xenpool  [" . session('user') . "]");
                  set_flash("!E:cannot reload db for xen pool $xenpool");
                  return redirect '/overview';
               } else {

                  $retc = check_poolrun();
                  unless ($retc) {

#                     my $poolmaster = get_master_db_file($xenpool);
#
#                     if ( "$poolmaster" eq "" ) {
#                        $errmsg = "no poolmaster - maybe pool virgin";
#                        $logger->warn("$ll $errmsg  [" . session('user') . "]");
#                        set_flash("!W:$errmsg");
#                        $retc = get_pool_data_fork( $xenpool );
#                        if ($retc) {
#                           $errmsg = "fork getting pool [$xenpool] data failed";
#                           $logger->warn("$ll $errmsg  [" . session('user') . "]");
#                           set_flash("!E:$errmsg");
#                        }
#                     } else {
                        
                        
                        
                        my $poolpath="$global{'fsiinstdir'}/$xenver/ks/pool/$xenpool";
                        $logger->trace("$ll  poolpath: $poolpath  [" . session('user') . "]");
                        unless ( -f "$poolpath/info.last" ) {
                           $logger->debug("$ll no last pool data exist  [" . session('user') . "]");
                           $retc = get_pool_data_fork( $xenpool );
                           if ($retc) {
                              $errmsg = "fork getting pool [$xenpool] data failed";
                              $logger->warn("$errmsg  [" . session('user') . "]");
                              set_flash("!E:$errmsg");
                           }
                        } else {
                           $logger->trace("$ll old pool data exist - to old?  [" . session('user') . "]");
                           if ( status_last_2old( "$poolpath/info.last" ) ) {
                              $logger->debug("$ll last pool data to old  [" . session('user') . "]");
                              $retc = get_pool_data_fork( $xenpool );
                              if ($retc) {
                                 $errmsg = "fork getting pool [$xenpool] data failed";
                                 $logger->error("$errmsg  [" . session('user') . "]");
                                 set_flash("!E:$errmsg");
                              }
                           } else {
                              $logger->debug("$ll start getting all current xenpool data  [" . session('user') . "]");
                              $vmshash_ref=readjsonfile("$poolpath/info.vms");
                              $hosthash_ref=readjsonfile("$poolpath/info.hosts");
                              $srhash_ref=readjsonfile("$poolpath/info.srs");
                              $nethash_ref=readjsonfile("$poolpath/info.net");
                              $masterhash_ref=readjsonfile("$poolpath/info.master");
                              $xenhash_ref=readjsonfile("$poolpath/info.xen");
                           } 
                        }
#                     } ## end else [ if ( "$poolmaster" eq "" ) ]
                     if ( $global{'logprod'} < 10000 ) {
                        my $dumpout = Dumper( \$serverhash_p );
                        $logger->trace("$ll Server Hash Dump: $dumpout");
                     }

                     template 'show_xp.tt',
                       {
                         'msg'      => get_flash(),
                         'version'  => $ver,
                         'file'     => $datei,
                         'vitemp'   => $host,
                         'pool'     => $xenpool,
                         'entries'  => $serverhash_p,
                         'rzconfig' => \%rzconfig,
                         'master'   => $masterhash_ref,
                         'vms'      => $vmshash_ref,
                         'vmnet'    => $vmnethash_ref,
                         'vmhd'     => $vmhdhash_ref,
                         'hosts'    => $hosthash_ref,
                         'nets'     => $nethash_ref,
                         'srs'      => $srhash_ref,
                         'xensrv'   => $xenhash_ref,
                         'vienv'    => $global{'vienv'}, };

                  } ## end unless ($retc)
               } ## end else [ if ($retc) ]
            } ## end else [ if ( "$xenver" eq "0" ) ]
         } ## end else [ if ( "$xenpool" eq "" ) ]

      } elsif ( request->method() eq "POST" ) {
         $logger->debug("$ll  POST Section  [" . session('user') . "]");
         my %params      = params;
         my $sess_reload = session('reload');
         $retc = backurl_add("$sess_reload");

         if ( $global{'logprod'} < 10000 ) {
            my $dumpout = Dumper( \%params );
            $logger->trace("$ll Dump: $dumpout");
         }
         
         if ( params->{'Logout'} ) {
            $logger->info("$ll  logout  [" . session('user') . "]");
            return redirect '/logout';
         } elsif ( params->{'Overview'} ) {
            $logger->debug("$ll  go back to /overview  [" . session('user') . "]");
            return redirect '/overview';

         } elsif ( params->{'ChangeNTP'} ) {
            my $changepool=params->{'ChangeNTP'};
            $logger->debug("$ll  change NTP server in pool [$changepool]  [" . session('user') . "]");
            my $newntpserver="";
            if ( $params{'ntpsrv'} ne '' ) {
               $newntpserver=$params{'ntpsrv'};
               $logger->debug("$ll  manually ntp server input $newntpserver  [" . session('user') . "]");
               if ( $newntpserver =~ /,/ ) {
                  $logger->debug("$ll   more than one ntp server given - check all ips/dns  [" . session('user') . "]");
                  my @tmpntpserver = split /,/, $newntpserver;
                  foreach $tempntpsrv (@tmpntpserver) {
                     if ( $tempntpsrv =~ /$dnsipre/g ) {
                        $logger->trace("$ll  $tempntpsrv is a valid ip or dns name [" . session('user') . "]");
                        $newdnsserver=$newdnsserver . "," . $dnsserver;
                     } else {
                        $errmsg = "wrong ip or dns adr for ntp server [$tempntpsrv]";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 99;
                        set_flash("!I:$errmsg");
                        last;
                     }
                  }
               } else {
                  $logger->debug("$ll   only one ntp server given  [" . session('user') . "]");
                  if ( $newntpserver =~ /$dnsipre/g ) {
                     $logger->debug("$ll   found ntp server: $newdntpserver  [" . session('user') . "]");
                  } else {
                     $errmsg = "wrong ip or dns adr for ntp server [$newntpserver]";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 99;
                     set_flash("!I:$errmsg");
                  }
               }
            } else {
               if ( $params{'ntpserver'} eq '' ) {
                  $errmsg = "no ntp server choosen in select box and no manual input";
                  $logger->error("$errmsg  [" . session('user') . "]");
                  $retc = 99;
                  set_flash("!I:$errmsg");
               } else {
                  $logger->trace("$ll   ntp server(s) define in select box  [" . session('user') . "]");
                  if ( ref $params{'ntpserver'} eq 'ARRAY' ) {
                     $logger->trace("$ll  more than one ntp server define in select box  [" . session('user') . "]");
                     foreach my $ntpserver ( @{ $params{'ntpserver'} } ) {
                        $logger->debug("$ll   found ntp server: $ntpserver  [" . session('user') . "]");
                        if ( $ntpserver =~ /$dnsipre/g ) {
                           $logger->trace("$ll  $ntpserver is a valid ip or dns name [" . session('user') . "]");
                           $newntpserver=$newntpserver . "," . $ntpserver;
                        } else {
                           $errmsg = "wrong ip or dns adr for ntp server [$tempntpsrv]";
                           $logger->error("$errmsg  [" . session('user') . "]");
                           $retc = 99;
                           set_flash("!I:$errmsg");
                           last;
                        }
                     }
                     unless ( $retc ) {
                        $newntpserver =~ s/^,//;
                     }
                  } else {
                     $logger->trace("$ll  only one ntp server define in select box  [" . session('user') . "]");
                     $newntpserver="$params{'ntpserver'}";
                     if ( $newntpserver =~ /$dnsipre/g ) {
                        $logger->debug("$ll   found ntp server: $newdntpserver  [" . session('user') . "]");
                     } else {
                        $errmsg = "wrong ip or dns adr for ntp server [$newntpserver]";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 99;
                        set_flash("!I:$errmsg");
                     }
                  }
               }
            }
            unless ( $retc ) {
               $logger->debug("$ll   found ntp server: $newntpserver  [" . session('user') . "]");
               $logger->info("$ll  change ntp [$newntpserver] in pool [$changepool]  [" . session('user') . "]");
               my $addcmd = 'change ntp in ' . $changepool . ',change on all xenserver in pool ' . $changepool . ' ,' . session('user') . ',myShowTask,TASKID,' . $changepool . ',xp,yes';
               $logger->trace("$ll cmd: $addcmd  [" . session('user') . "]");
               $taskid = task_add($addcmd);
               if ($taskid) {
                  $logger->trace("$ll  fork now  [" . session('user') . "]");
                  set_flash("!I:Start changing ntp on all server in [$changepool] ...");
                  fork and return redirect $sess_reload;
                  
                  my $tasklog = $global{'logdir'} . "/task-" . $taskid;
                  $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
                  $retc = tasklog_add($tasklog);
                  
                  unless ( $retc ) {
                     $logger->debug("$ll change ntp of pool [$pool] to [$newntpserver]  [" . session('user') . "]");
                     my $command = "$global{'toolsdir'}/chntp -l $tasklog.log -p $changepool -n $newntpserver ";
                     $logger->trace("$ll  chntp cmd: [$command]  [" . session('user') . "]");
                     my $output = qx($command  2>&1);
                     $retc = $?;
                     $retc = $retc >> 8 unless ( $retc == -1 );
                     if ( $retc ) {
                        set_flash("!E:error [$retc] during changing ntp [$newntpserver] in pool [$changepool] ");
                        $logger->error("error while changing ntp on the xenserver in pool [$changepool]  [" . session('user') . "]");
                     } else {
                        $logger->info("$ll  all xenserver changed  [" . session('user') . "]");
                     }

                     $logger->debug("$ll  delete task  [" . session('user') . "]");
                     $retc = task_del( $taskid, 'yes' );
                     $logger->trace("$ll  delete task log file  [" . session('user') . "]");
                     $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
                     
                     $retc = tasklog_remove($tasklog);
                     if ( $retc ) {
                        set_flash("!E:error cannot remove tasklog [$retc]");
                     }
                     
                  } else {
                     set_flash("!E:cannot add tasklog [$retc]");
                  }
                  # if fork - than exit here
                  exit;

               } else {
                  set_flash("!E:cannot get taskid for changing ntp [$newntpserver] in pool [$changepool] ");
               }
            }
            return redirect $sess_reload;

            
         } elsif ( params->{'ChangeDNS'} ) {
            my $changepool=params->{'ChangeDNS'};
            $logger->debug("$ll  change DNS server in pool [$changepool]  [" . session('user') . "]");
            my $newdnsserver="";
            if ( $params{'dnssrv'} ne '' ) {
               $newdnsserver=$params{'dnssrv'};
               $logger->debug("$ll  manually dns server input $newdnsserver  [" . session('user') . "]");
               if ( $newdnsserver =~ /,/ ) {
                  $logger->debug("$ll   more than one dns server given - check all ips  [" . session('user') . "]");
                  my @tmpdnsserver = split /,/, $newdnsserver;
                  foreach $tempdnssrv (@tmpdnsserver) {
                     if ( $tempdnssrv =~ /^($ipre\.){3}$ipre$/ ) {
                        $logger->trace("$ll  $tempdnssrv is a valid ip  [" . session('user') . "]");
                     } else {
                        $errmsg = "wrong ip adr for dns server [$tempdnssrv]";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 99;
                        set_flash("!I:$errmsg");
                        last;
                     }
                  } ## end foreach $tempdnssrv (@tmpdnsserver)
               } else {
                  $logger->debug("$ll   only one dns server given  [" . session('user') . "]");
                  if ( $newdnsserver =~ /^($ipre\.){3}$ipre$/ ) {
                     $logger->debug("$ll   found dns server: $newdnsserver  [" . session('user') . "]");
                  } else {
                     $errmsg = "wrong ip adr for dns server [$newdnsserver]";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 99;
                     set_flash("!I:$errmsg");
                  }
               }
            } else {
               if ( $params{'dnsserver'} eq '' ) {
                  $errmsg = "no dns server choosen in select box and no manual input";
                  $logger->error("$errmsg  [" . session('user') . "]");
                  $retc = 99;
                  set_flash("!I:$errmsg");
               } else {
                  if ( ref $params{'dnsserver'} eq 'ARRAY' ) {
                     $logger->trace("$ll  more than one dns server define in select box  [" . session('user') . "]");
                     foreach my $dnsserver ( @{ $params{'dnsserver'} } ) {
                        $logger->debug("$ll   found dns server: $dnsserver  [" . session('user') . "]");
                        if ( $dnsserver =~ /^($ipre\.){3}$ipre$/ ) {
                           $newdnsserver=$newdnsserver . "," . $dnsserver;
                        } else {
                           $errmsg = "wrong ip adr for dns server [$dnsserver]";
                           $logger->error("$errmsg  [" . session('user') . "]");
                           $retc = 99;
                           set_flash("!I:$errmsg");
                           last;
                        }
                     }
                     unless ( $retc ) {
                        $newdnsserver =~ s/^,//;
                     }
                  } else {
                     $logger->trace("$ll  only one dns server define in select box  [" . session('user') . "]");
                     $newdnsserver="$params{'dnsserver'}";
                     if ( $newdnsserver =~ /^($ipre\.){3}$ipre$/ ) {
                        $logger->debug("$ll   found dns server: $newdnsserver  [" . session('user') . "]");
                     } else {
                        $errmsg = "wrong ip adr for dns server [$newdnsserver]";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 99;
                        set_flash("!I:$errmsg");
                     }
                  }
               } ## end else [ if ( $params{'dnsserver'} eq '' ) ]

            }
            
            unless ( $retc ) {
               $logger->debug("$ll   found dns server: $newdnsserver  [" . session('user') . "]");
               $logger->info("$ll  change dns [$newdnsserver] in pool [$changepool]  [" . session('user') . "]");
               my $addcmd = 'change dns in ' . $changepool . ',change on all xenserver in pool ' . $changepool . ' ,' . session('user') . ',myShowTask,TASKID,' . $changepool . ',xp,yes';
               $logger->trace("$ll cmd: $addcmd  [" . session('user') . "]");
               $taskid = task_add($addcmd);
               if ($taskid) {
                  $logger->trace("$ll  fork now  [" . session('user') . "]");
                  set_flash("!I:Start changing dns on all server in [$changepool] ...");
                  fork and return redirect $sess_reload;
                  
                  my $tasklog = $global{'logdir'} . "/task-" . $taskid;
                  $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
                  $retc = tasklog_add($tasklog);
                  
                  unless ( $retc ) {
                     $logger->debug("$ll change dns of pool [$pool] to [$newdnsserver]  [" . session('user') . "]");
                     my $command = "$global{'toolsdir'}/chdns -l $tasklog.log -p $changepool -d $newdnsserver ";
                     $logger->trace("$ll  chdns cmd: [$command]  [" . session('user') . "]");
                     my $output = qx($command  2>&1);
                     $retc = $?;
                     $retc = $retc >> 8 unless ( $retc == -1 );
                     if ( $retc ) {
                        set_flash("!E:error [$retc] during changing dns [$newdnsserver] in pool [$changepool] ");
                        $logger->error("error while changing dns on the xenserver in pool [$changepool]  [" . session('user') . "]");
                     } else {
                        $logger->info("$ll  all xenserver changed  [" . session('user') . "]");
                     }

                     $logger->debug("$ll  delete task  [" . session('user') . "]");
                     $retc = task_del( $taskid, 'yes' );
                     $logger->trace("$ll  delete task log file  [" . session('user') . "]");
                     $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
                     
                     $retc = tasklog_remove($tasklog);
                     if ( $retc ) {
                        set_flash("!E:error cannot remove tasklog [$retc]");
                     }
                     
                  } else {
                     set_flash("!E:cannot add tasklog [$retc]");
                  }
                  # if fork - than exit here
                  exit;

               } else {
                  set_flash("!E:cannot get taskid for changing dns [$newdnsserver] in pool [$changepool] ");
               }
            }
            return redirect $sess_reload;
            
         } elsif ( params->{'ChangeSyslog'} ) {
            my $changepool=params->{'ChangeSyslog'};
            $logger->debug("$ll  change Syslog server in pool [$changepool]  [" . session('user') . "]");
            my $newsyslogserver="";
            if ( $params{'syslogsrv'} ne '' ) {        # manual input
               $newsyslogserver=$params{'syslogsrv'};
               $logger->debug("$ll  manually syslog server input $newsyslogserver  [" . session('user') . "]");
            } elsif ( $params{'syslogserver'} eq '' ) {     # choose syslog
               $logger->trace("$ll  no dns server choosen in select box  [" . session('user') . "]");
            } else {
               if ( ref $params{'dnsserver'} eq 'ARRAY' ) {
                  $errmsg = "more than one syslog server define in select box";
                  $logger->error("$errmsg  [" . session('user') . "]");
                  $retc = 99;
                  set_flash("!I:$errmsg");
               } else {
                  $logger->trace("$ll  one syslog server define in select box  [" . session('user') . "]");
                  $newsyslogserver="$params{'syslogserver'}";
                  $logger->debug("$ll   found syslog server: $newsyslogserver  [" . session('user') . "]");
                  
               }
            } ## end else [ if ( $params{'dnsserver'} eq '' ) ]

            unless ( $retc ) {
               if ( $newsyslogserver =~ /$dnsre/ ) {
                  $logger->debug("$ll   found new syslog server as dns: $newsyslogserver  [" . session('user') . "]");
               } else {
                  if ( $newsyslogserver =~ /^($ipre\.){3}$ipre$/ ) {
                     $logger->debug("$ll   found new syslog server as ip: $newsyslogserver  [" . session('user') . "]");
                  } else {
                     $errmsg = "[$newsyslogserver] is not a valid hostname or ip";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 99;
                     set_flash("!I:$errmsg");
                  }
               }
            }

            unless ( $retc ) {
               $logger->info("$ll  change syslog [$newsyslogserver] in pool [$changepool]  [" . session('user') . "]");
               my $addcmd = 'change syslog in ' . $changepool . ',change on all xenserver in pool ' . $changepool . ' ,' . session('user') . ',myShowTask,TASKID,' . $changepool . ',xp,yes';
               $logger->trace("$ll cmd: $addcmd  [" . session('user') . "]");
               $taskid = task_add($addcmd);
               if ($taskid) {
                  $logger->trace("$ll  fork now  [" . session('user') . "]");
                  set_flash("!I:Start changing syslog on all server in [$changepool] ...");
                  fork and return redirect $sess_reload;
                  
                  my $tasklog = $global{'logdir'} . "/task-" . $taskid;
                  $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
                  $retc = tasklog_add($tasklog);
                  
                  unless ( $retc ) {
                     
                     my $command = "$global{'toolsdir'}/chsyslog -l $tasklog.log -p $changepool -d $newsyslogserver ";
                     $logger->trace("$ll  cmd: [$command]  [" . session('user') . "]");
                     my $output = qx($command  2>&1);
                     $retc = $?;
                     $retc = $retc >> 8 unless ( $retc == -1 );
                     if ( $retc ) {
                        set_flash("!E:error [$retc] during changing syslog [$newsyslogserver] in pool [$changepool] ");
                        $logger->error("error while changing syslog on the xenserver in pool [$changepool]  [" . session('user') . "]");
                     } else {
                        $logger->info("$ll  all xenserver changed  [" . session('user') . "]");
                     }

                     $logger->debug("$ll  delete task  [" . session('user') . "]");
                     $retc = task_del( $taskid, 'yes' );
                     $logger->trace("$ll  delete task log file  [" . session('user') . "]");
                     $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
                     
                     $retc = tasklog_remove($tasklog);
                     if ( $retc ) {
                        set_flash("!E:error cannot remove tasklog [$retc]");
                     }
                     
                  } else {
                     set_flash("!E:cannot add tasklog [$retc]");
                  }
                  # if fork - than exit here
                  exit;

               } else {
                  set_flash("!E:cannot get taskid for changing dns [$newdnsserver] in pool [$changepool] ");
               }
            }
            return redirect $sess_reload;
            
         } elsif ( params->{'DelReadFlag'} ) {
            my $poolname=params->{'DelReadFlag'};
            my $xenver  = db_get_typ_pool($poolname);
            
            $flagfile="$global{'fsiinstdir'}/$xenver/ks/pool/$poolname/info.last";
            unless ( unlink($flagfile) ) {
               $logger->debug("$ll  $flagfile does not exist - do not need to delete!  [" . session('user') . "]");
            } else {
               $logger->debug("$ll  $flagfile deleted!  [" . session('user') . "]");
            }
            redirect $sess_reload;
            
         } elsif ( params->{'Back'} ) {
            my $sess_back = backurl_getlast("$sess_reload");
            $logger->debug("$ll  go back to $sess_back  [" . session('user') . "]");
            return redirect $sess_back;

         } elsif ( params->{'Reload'} ) {
            $logger->debug("$ll  reload xen pool view [$sess_reload]  [" . session('user') . "]");
            redirect $sess_reload;

            # Server Jobs
         } elsif ( params->{'Install'} ) {
            my $job = params->{'Install'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Install Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/instsrvmark';
            } else {
               $logger->debug("$ll  run single job - Install Server  [" . session('user') . "]");

               # $srvid = substr( params->{'Install'}, 3 );
               session 'srvarray' => substr( params->{'Install'}, 3 );
               redirect '/instsrvmark';
            } ## end else [ if ( $job eq "marked" ) ]
            
         } elsif ( params->{'EditFile'} ) {
            my $parameter = params->{'EditFile'};
            $logger->trace("$ll  parameter: $parameter  [" . session('user') . "]");
            my ( $file, $srv, $fileformat ) = split( ':', $parameter );
            $logger->debug("$ll  edit config file $file for $srv  [" . session('user') . "]");
            if ( -f "$file" ) {
               if ( "$fileformat" eq "" ) {
                  $fileformat='text';
               }
               $logger->trace("$ll  found file - open editor  [" . session('user') . "]");
               session 'edit_file'   => $file;
               session 'edit_ctrl'   => 'srv';
               session 'edit_what'   => $srv;
               session 'edit_format' => $fileformat;
               session 'backsik'     => $back;

               # session 'back'        => session('reload');
               return redirect "/editfile";
            } else {
               $logger->warn("$ll  cannot find file $file - abort  [" . session('user') . "]");
               set_flash("!E:Error - cannot find config file for $srv");
            }
            return redirect $sess_reload;
            
            

         } elsif ( params->{'Abort'} ) {
            my $job = params->{'Abort'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Abort Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked - go overview  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/stopsrvmark';
            } else {
               $logger->debug("$ll  run single job - Abort Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'Abort'}, 3 );
               redirect '/stopsrvmark';
            }

         } elsif ( params->{'PowerON'} ) {
            my $job = params->{'PowerON'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Power ON Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/ponsrvmark';
            } else {
               $logger->debug("$ll  run single job - Power ON Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'PowerON'}, 3 );
               redirect '/ponsrvmark';
            }
         } elsif ( params->{'PowerOFF'} ) {
            my $job = params->{'PowerOFF'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Power OFF Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/poffsrvmark';
            } else {
               $logger->debug("$ll  run single job - Power OFF Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'PowerOFF'}, 3 );
               redirect '/poffsrvmark';
            }
         } elsif ( params->{'Reboot'} ) {
            my $job = params->{'Reboot'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Reboot Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked   [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/bootsrvmark';
            } else {
               $logger->debug("$ll  run single job - Reboot Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'Reboot'}, 3 );
               redirect '/bootsrvmark';
            }
         } elsif ( params->{'Shutdown'} ) {
            my $job = params->{'Shutdown'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Shutdown Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked   [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/shutdownsrvmark';
            } else {
               $logger->debug("$ll  run single job - Shutdown Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'Shutdown'}, 3 );
               redirect '/shutdownsrvmark';
            }
         } elsif ( params->{'SetMaintenanceMode'} ) {
            my $job = params->{'SetMaintenanceMode'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - set server to maintenance mode  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked   [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/setmaintenancemodemark';
            } else {
               $logger->debug("$ll  run single job - set server to maintenance mode  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'SetMaintenanceMode'}, 3 );
               redirect '/setmaintenancemodemark';
            }
         } elsif ( params->{'ExitMaintenanceMode'} ) {
            my $job = params->{'ExitMaintenanceMode'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - exit server from maintenance mode  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked   [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/exitmaintenancemodemark';
            } else {
               $logger->debug("$ll  run single job - exit server from maintenance mode  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'ExitMaintenanceMode'}, 3 );
               redirect '/exitmaintenancemodemark';
            }
         } elsif ( params->{'Delete'} ) {
            my $job = params->{'Delete'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Delete Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/delsrvmark';
            } else {
               $logger->debug("$ll  run single job - Delete Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'Delete'}, 3 );
               redirect '/delsrvmark';
            }
         } elsif ( params->{'ShowLog'} ) {
            session 'srvid' => substr( params->{'ShowLog'}, 3 );
            redirect '/showlog/notail';
         } elsif ( params->{'Update'} ) {
            my $job = params->{'Update'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Update Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/updsrvmark';
            } else {
               $logger->debug("$ll  run single job - Delete Logfile  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'Update'}, 3 );
               redirect '/updsrvmark';
            }
         } elsif ( params->{'ResetMsg'} ) {
            $logger->debug("$ll  reset message  [" . session('user') . "]");
            session 'srvid' => substr( params->{'ResetMsg'}, 3 );
            my $rc = reset_msg( substr( params->{'ResetMsg'}, 3 ) );
            return redirect $sess_reload;
         } elsif ( params->{'DeploySSHKeys'} ) {
            $logger->debug("$ll  deploy ssh keys  [" . session('user') . "]");
            my $pool = params->{'DeploySSHKeys'};
            my $rc   = deploy_sshkeys($pool);
            return redirect $sess_reload;
         } elsif ( params->{'DelLog'} ) {
            my $job = params->{'DelLog'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Delete Logfiles  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/dellogmark';
            } else {
               $logger->debug("$ll  run single job - Delete Logfile  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'DelLog'}, 3 );
               redirect '/dellogmark';
            }

            # XenPool specify
         } elsif ( params->{'ChkMaster'} ) {
            my $pool = params->{'ChkMaster'};
            $retc = portal_check_master($pool);
            redirect $sess_reload;
         } elsif ( params->{'EnableHA'} ) {
            my $pool = params->{'EnableHA'};
            $retc = haenable($pool);
            redirect $sess_reload;
         } elsif ( params->{'DisableHA'} ) {
            my $pool = params->{'DisableHA'};
            $retc = hadisable($pool);
            redirect $sess_reload;
         } elsif ( params->{'DelPoolDir'} ) {
            $retc = del_pool_dir( params->{'DelPoolDir'} );
            redirect $sess_reload;
         } elsif ( params->{'Auth2AD'} ) {
            $retc = set_auth( params->{'Auth2AD'},"AD" );
            redirect $sess_reload;
         } elsif ( params->{'Auth2LOC'} ) {
            $retc = set_auth( params->{'Auth2LOC'},"LOC" );
            redirect $sess_reload;
         } elsif ( params->{'DelPoolRun'} ) {
            $retc = del_pool_run( params->{'DelPoolRun'} );
            redirect $sess_reload;
         } elsif ( params->{'ResetMsgPool'} ) {
            $logger->debug("$ll  reset pool message  [" . session('user') . "]");
            my $pool = params->{'ResetMsgPool'};
            my $rc   = reset_msg_pool($pool);
            return redirect $sess_reload;
         } elsif ( params->{'CleanPatches'} ) {
            my $pool = params->{'CleanPatches'};
            $logger->debug("$ll  clean patchdir in pool [$pool]  [" . session('user') . "]");
            my $rc = clean_pool_patches($pool);
            return redirect $sess_reload;
         } elsif ( params->{'ResetBlockPool'} ) {
            $logger->debug("$ll  reset pool blockade  [" . session('user') . "]");
            my $pool = params->{'ResetBlockPool'};
            my $rc   = reset_block_pool($pool);
            return redirect $sess_reload;
         } elsif ( params->{'UpdateVIScripts'} ) {
            $logger->debug("$ll  update and deploy vi tool scripts on $pool  [" . session('user') . "]");
            my $pool   = params->{'UpdateVIScripts'};
            my $addcmd = 'copy vi tools to ' . $pool . ',copy vi tools to all xen server on ' . $pool . ',' . session('user') . ',myShowTask,TASKID,' . $pool . ',xp,yes';
            $logger->trace("$ll cmd: $addcmd  [" . session('user') . "]");
            $taskid = task_add($addcmd);
            if ($taskid) {
               $logger->trace("$ll  fork now  [" . session('user') . "]");
               set_flash("!I:Start copy vi scripts to all server on [$pool] ...");
               fork and return redirect $sess_reload;
               my $tasklog = $global{'logdir'} . "/task-" . $taskid;
               $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
               $retc = tasklog_add($tasklog);
               my $rc = deploy_scripts_xenpool( $pool, $tasklog );
               $logger->debug("$ll  delete task  [" . session('user') . "]");
               $retc = task_del( $taskid, 'yes' );
               $logger->trace("$ll  delete task log file  [" . session('user') . "]");
               $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
               $retc = tasklog_remove($tasklog);

               # if fork - than exit here
               exit;
            } else {
               set_flash("!E:Server $vc cannot get new task id ");
            }
            return redirect $sess_reload;

            # Xen VM specify
         } elsif ( params->{'VMStop'} ) {
            my $job = params->{'VMStop'};
            @markedvm = ();
            if ( $job eq "VMmarked" ) {
               $logger->debug("$ll  run vm marked job - VMStop  [" . session('user') . "]");
               if ( ref $params{'VMMarked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $markvm ( @{ $params{'VMMarked'} } ) {
                     if ( $markvm ne "0" && $markvm ne "on" ) {
                        @markedvm = ( @markedvm, $markvm );
                     }
                  }
               } else {
                  if ( $params{'VMMarked'} ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedvm = ( @markedvm, $params{'VMMarked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'VMMarked'} eq 'ARRAY' ) ]
               session 'vmarray' => "@markedvm";
               redirect '/xenvm/stop';
            } else {
               $logger->debug("$ll  run single job - VMStop  [" . session('user') . "]");
               @markedvm = ( @markedvm, $params{'VMStop'} );
               session 'vmarray' => "@markedvm";
               redirect '/xenvm/stop';
            } ## end else [ if ( $job eq "VMmarked" ) ]
         } elsif ( params->{'VMStart'} ) {
            my $job = params->{'VMStart'};
            @markedvm = ();
            if ( $job eq "VMmarked" ) {
               $logger->debug("$ll  run marked job - VMStart  [" . session('user') . "]");
               if ( ref $params{'VMMarked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $markvm ( @{ $params{'VMMarked'} } ) {
                     if ( $markvm ne "0" && $markvm ne "on" ) {
                        @markedvm = ( @markedvm, $markvm );
                     }
                  }
               } else {
                  if ( $params{'VMMarked'} ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedvm = ( @markedvm, $params{'VMMarked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'VMMarked'} eq 'ARRAY' ) ]
               session 'vmarray' => "@markedvm";
               redirect '/xenvm/start';
            } else {
               $logger->debug("$ll  run single job - VMStart  [" . session('user') . "]");
               @markedvm = ( @markedvm, $params{'VMStart'} );
               session 'vmarray' => "@markedvm";
               redirect '/xenvm/start';
            } ## end else [ if ( $job eq "VMmarked" ) ]
         } elsif ( params->{'VMReboot'} ) {
            my $job = params->{'VMReboot'};
            @markedvm = ();
            if ( $job eq "VMmarked" ) {
               $logger->debug("$ll  run marked job - VMReboot  [" . session('user') . "]");
               if ( ref $params{'VMMarked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $markvm ( @{ $params{'VMMarked'} } ) {
                     if ( $markvm ne "0" && $markvm ne "on" ) {
                        @markedvm = ( @markedvm, $markvm );
                     }
                  }
               } else {
                  if ( $params{'VMMarked'} ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedvm = ( @markedvm, $params{'VMMarked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'VMMarked'} eq 'ARRAY' ) ]
               session 'vmarray' => "@markedvm";
               redirect '/xenvm/reboot';
            } else {
               $logger->debug("$ll  run single job - VMReboot  [" . session('user') . "]");
               @markedvm = ( @markedvm, $params{'VMReboot'} );
               session 'vmarray' => "@markedvm";
               redirect '/xenvm/reboot';
            } ## end else [ if ( $job eq "VMmarked" ) ]
         } elsif ( params->{'VMShutdown'} ) {
            my $job = params->{'VMShutdown'};
            @markedvm = ();
            if ( $job eq "VMmarked" ) {
               $logger->debug("$ll  run marked job - VMShutdown  [" . session('user') . "]");
               if ( ref $params{'VMMarked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $markvm ( @{ $params{'VMMarked'} } ) {
                     if ( $markvm ne "0" && $markvm ne "on" ) {
                        @markedvm = ( @markedvm, $markvm );
                     }
                  }
               } else {
                  if ( $params{'VMMarked'} ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedvm = ( @markedvm, $params{'VMMarked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'VMMarked'} eq 'ARRAY' ) ]
               session 'vmarray' => "@markedvm";
               redirect '/xenvm/shutdown';
            } else {
               $logger->debug("$ll  run single job - VMShutdown  [" . session('user') . "]");
               @markedvm = ( @markedvm, $params{'VMShutdown'} );
               session 'vmarray' => "@markedvm";
               redirect '/xenvm/shutdown';
            } ## end else [ if ( $job eq "VMmarked" ) ]
         } elsif ( params->{'EditPoolUpd'} ) {
            my $file = params->{'EditPoolUpd'};
            $logger->debug("$ll  edit config file $file  [" . session('user') . "]");
            if ( -f "$file" ) {
               $logger->trace("$ll  found file - open editor  [" . session('user') . "]");
               session 'edit_file'   => $file;
               session 'edit_ctrl'   => 'fsi';
               session 'edit_what'   => 'fsi';
               session 'edit_format' => 'xml';
               return redirect "/editfile";
            } else {
               $logger->warn("$ll  cannot find file $file - abort  [" . session('user') . "]");
               set_flash("!E:Error - cannot find config file $file");
               return redirect $sess_reload;
            }
         } else {
            $logger->error("unknown method for fsi  [" . session('user') . "]");
            template 'error',
              {
                'msg'     => "unknown method in /showxp",
                'version' => $ver,
                'vitemp'  => $host,
                'vienv'   => $global{'vienv'}, };
         } ## end else [ if ( params->{'Overview'} ) ]
      } else {
         template 'error',
           {
             'msg'     => "unknown method in /showxp",
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'}, };
      } ## end else [ if ( request->method() eq "GET" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
