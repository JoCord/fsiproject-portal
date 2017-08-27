# 4.01.30 - 11.4.2016
any [ 'get', 'post' ] => '/addesxi' => sub {
   my $weburl = '/addesxi';
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
      if ( request->method() eq "POST" ) {
         $logger->trace("$ll  start input from esxi input site  [" . session('user') . "]");
         my %params;
         %params = params;
         my $reload = session('reload');
         my $back   = backurl_getlast("$reload");
         if ( params->{'OK'} ) {
            if ( $global{'logprod'} < 10000 ) {
               my $dump = Dumper( \%params );
               $logger->trace("$ll  Parameter Dump: [$dump]");
            }
            $logger->trace("$ll  params = OK  [" . session('user') . "]");
            my $retc = 0;
            $logger->trace("$ll  esxi server name: $params{'Server'}  [" . session('user') . "]");
            my $scriptcall = "$global{'toolsdir'}/mkesxi -l $global{'logfile'}.log";

            my $esxiinstloglevel = "info";
            $scriptcall = "$scriptcall -O $esxiinstloglevel";

            my $mac;
            unless ($retc) {
               $mac = $params{'MACAdr'};
               if ( $mac =~ /^([0-9A-Fa-f]{1,2}[\.:-]){5}([0-9A-Fa-f]{1,2})$/ ) {
                  $mac =~ s/[:|.]/-/g;
                  $mac = lc($mac);
               } else {
                  $errmsg = "mac not correkt formated - [$mac]";
                  $logger->error("$errmsg  [" . session('user') . "]");
                  $retc = 77;
               }
            } ## end unless ($retc)
            my $mgmtnet = $params{'esxmgmt'};
            $logger->trace("$ll  esx mgmt template: $mgmtnet  [" . session('user') . "]");
            my $esxiver = $params{'esxiver'};
            my $esxicore = substr( $esxiver, 0, 1 );
            $logger->trace("$ll  esxi ver: [$esxiver] / [$esxicore]   [" . session('user') . "]");
            my $esxname = $params{'Server'};
            unless ($retc) {                                                                                                       # -x <esxi version>
               $scriptcall = "$scriptcall -x $esxiver";
            }
            unless ($retc) {                                                                                                       # -E <esxi hostname>, <dns-suffix>, <mac>, <lic>
               my $srvdnssuffix;
               if ( $params{'ServerSuffix'} eq '' ) {
                  if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'esxisuffix'} ne "" ) {
                     $srvdnssuffix = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'esxisuffix'};
                  } else {
                     $errmsg = "no dns suffix found";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 40;
                  }
               } else {
                  $srvdnssuffix = $params{'ServerSuffix'};
               }
               $logger->trace("$ll  dns suffix: $srvdnssuffix  [" . session('user') . "]");
               my $esxilic;
               if ( $params{'license'} eq '' ) {
                  if ( $params{'esxlic'} eq '' ) {
                     $errmsg = "no esxi lic found";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 41;
                  } else {
                     $esxilic = $params{'esxlic'};
                  }
               } else {
                  $esxilic = $params{'license'};
               }
               $scriptcall = "$scriptcall -E $esxname,$srvdnssuffix,$mac,$esxilic";
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -P <root password>
               my $rootpw;
               if ( $params{'rootpw'} eq '' ) {
                  if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'rootpw'} ne "" ) {
                     $rootpw = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'rootpw'};
                  } else {
                     $errmsg = "no esxi root password found in rzenv.xml";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 42;
                  }
               } else {
                  $rootpw = $params{'rootpw'};
               }
               $scriptcall = "$scriptcall -P $rootpw";
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -e <true/false> - enable local shell
               my $shell;
               if ( defined $params{'EnableShell'} ) {                                                                             # häckchen drin
                  $shell = "true";
               } else {
                  $shell = "false";
               }
               $scriptcall = "$scriptcall -e $shell";
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -G <true/false> - enable ssh login
               my $ssh;
               if ( defined $params{'EnableSSH'} ) {
                  $ssh = "true";
               } else {
                  $ssh = "false";
               }
               $scriptcall = "$scriptcall -G $ssh";
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -A - enable maintenance mode
               if ( defined $params{'EnableMaintenance'} ) {
                  $scriptcall = "$scriptcall -A";
               }
            }
            unless ($retc) {                                                                                                       # -M <ip>,<netmask>,<gateway>,<vlan>, <flags>, <mtu>, <nics>, <comment>
               my $ip = "";
               if ( $params{'SrvIP'} ne "" ) {
                  if ( $params{'SrvIP'} =~ /^($ipre\.){3}$ipre$/ ) {
                     $ip = $params{'SrvIP'};
                     if ( check_srvonline($ip) ) {
                        $errmsg = "ESXi Server Mgmt ip [$ip] is already online";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 44;
                     }
                  } else {
                     $errmsg = "no correct mgmt ip given";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 44;
                  }
               } else {
                  $errmsg = "no ip given";
                  $logger->error("$errmsg  [" . session('user') . "]");
                  $retc = 45;
               }
               my $nm = "255.255.255.0";
               unless ($retc) {
                  if ( $params{'nm_manuel'} ne "" ) {
                     if ( $params{'nm_manuel'} =~ /^($ipre\.){3}$ipre$/ ) {
                        $nm = $params{'nm_manuel'};
                     } else {
                        $errmsg = "no correct mgmt netmask given";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 46;
                     }
                  } else {
                     if ( defined $params{'Netmask'} ) {
                        $nm = "$params{'Netmask'}";
                     } else {
                        $logger->trace("$ll  no netmask found or given in rzenv.xml - take default 255.255.255.0  [" . session('user') . "]");
                     }
                  } ## end else [ if ( $params{'nm_manuel'} ne "" ) ]
               } ## end unless ($retc)
               my $gw = "";
               unless ($retc) {
                  if ( $params{'gw_manuel'} ne "" ) {
                     if ( $params{'gw_manuel'} =~ /^($ipre\.){3}$ipre$/ ) {
                        $gw = $params{'gw_manuel'};
                     } else {
                        $errmsg = "no correct mgmt gateway ip given";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 47;
                     }
                  } else {
                     if ( defined $params{'Gateway'} ) {
                        $gw = "$params{'Gateway'}";
                     } else {
                        $errmsg = "no mgmt gateway ip given";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 48;
                     }
                  } ## end else [ if ( $params{'gw_manuel'} ne "" ) ]
               } ## end unless ($retc)
               my $vlan = "";
               $logger->trace("$ll  vlan: $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmm'}{$mgmtnet}{'vlan'}  [" . session('user') . "]");
               unless ($retc) {
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmm'}{$mgmtnet}{'vlan'} ) {
                     $vlan = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmm'}{$mgmtnet}{'vlan'};
                  }
               }
               my $flags = "";
               $logger->trace("$ll  flags: $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmm'}{$mgmtnet}{'flags'}  [" . session('user') . "]");
               unless ($retc) {
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmm'}{$mgmtnet}{'flags'} ) {
                     $flags = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmm'}{$mgmtnet}{'flags'};
                  }
               }
               my $mtu = "";
               unless ($retc) {
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmm'}{$mgmtnet}{'mtu'} ) {
                     $mtu = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmm'}{$mgmtnet}{'mtu'};
                  }
               }
               my $nics = "";
               unless ($retc) {
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmm'}{$mgmtnet}{'nics'} ) {
                     $nics = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmm'}{$mgmtnet}{'nics'};
                  }
               }
               my $comment = "";
               unless ($retc) {
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmm'}{$mgmtnet}{'cflags'} ) {
                     $comment = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmm'}{$mgmtnet}{'cflags'};
                  }
               }
               unless ($retc) {
                  $scriptcall = "$scriptcall -M $ip,$nm,$gw,$vlan,\"$flags\",$mtu,\"$nics\",\"$comment\" ";
               }
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -L [esxi4: <log location datastore>,<path>] / [esxi5: <log location path>, <rotate number to keep>, <size KiB>, <optional: unique dir>]
               if ( $params{'ll_manual'} ne "" ) {
                  $scriptcall = "$scriptcall -L $params{'ll_manual'}";
               } else {
                  my $logloc = $params{'logloc'};
                  my $logdest="";
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'logloc'}{$logloc}{'dest'} ) {
                     $logdest = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'logloc'}{$logloc}{'dest'};
                     $logger->info("$ll  log destination: $logdest  [" . session('user') . "]");
                     
                     if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'logloc'}{$logloc}{'disable'} ) {
                        $logger->debug("$ll  no log location choosen  [" . session('user') . "]");
                     } else {
                        if ( "$esxicore" eq "4" ) {
                           $logdest =~ s/%SRVNAME%/$esxname/g;
                           $scriptcall = "$scriptcall -L $logdest";
                        } elsif ( ( "$esxicore" eq "5" ) || ( "$esxicore" eq "6" ) ) {
                           my $logrot  = "";
                           my $logsize = "";
                           my $logdir  = "true";
                           if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'logloc'}{$logloc}{'logrot'} ) {
                              $logrot = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'logloc'}{$logloc}{'logrot'};
                           }
                           if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'logloc'}{$logloc}{'logsize'} ) {
                              $logsize = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'logloc'}{$logloc}{'logsize'};
                           }
                           if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'logloc'}{$logloc}{'logdir'} ) {
                              $logdir = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'logloc'}{$logloc}{'logdir'};
                           }
                           $logdest =~ s/%SRVNAME%/$esxname/g;
                           $scriptcall = "$scriptcall -L $logdest,$logrot,$logsize,$logdir";
                        }
                     } 
                  } else {
                     $logger->error("cannot find log location destination for $logloc - abort  [" . session('user') . "]");
                     $retc=99;
                  }
               } 
            }
            unless ($retc) {                                                                                                       # -S </vmfs/volumes/scratch location path>
               if ( $params{'scratchloc'} ne "" ) {
                  $scriptcall = "$scriptcall -S $params{'scratchloc'}";
               } else {
                  my $scratch = $params{'scratch'};
                  $logger->trace("$ll  scratch: $scratch  [" . session('user') . "]");
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'scratch'}{$scratch}{'disable'} ) {
                     $logger->debug("$ll  no scratch location choosen  [" . session('user') . "]");
                  } else {
                     if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'scratch'}{$scratch}{'dest'} ) {
                        my $scratchdest=$rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'scratch'}{$scratch}{'dest'};
                        $logger->debug("$ll  found scratch destination: $scratchdest  [" . session('user') . "]");
                        $scratchdest =~ s/%SRVNAME%/$esxname/g;
                        $scriptcall = "$scriptcall -S $scratchdest";
                     } else {
                        $logger->error("cannot find scratch destination for $scratch - abort  [" . session('user') . "]");
                        $retc=99;
                     }
                  }
               } 
            } 
            unless ($retc) {                                                                                                       # -R <syslog server>, <optional: port>, <optional: tcp/udp - only esxi 5.x> - esxi4 only one syslog srv
               my $port = "514";
               my $prot = "udp";
               if ( $params{'syslogsrv'} ne "" ) {
                  if ( $params{'syslogport'} ne "" ) {
                     $port = $params{'syslogport'};
                  }
                  $scriptcall = "$scriptcall -R $params{'syslogsrv'},$port";
               } else {
                  if ( "$esxicore" eq "4" ) {
                     if ( ref $params{'syslogserver'} eq 'ARRAY' ) {
                        $errmsg = "only one syslog server can choosen for esxi 4.x";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 50;
                     } else {
                        my $syslog = $params{'syslogserver'};
                        if ( $syslog ne "" ) {
                           if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'ip'} ) {
                              if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'port'} ) {
                                 $port = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'port'};
                              }
                              $scriptcall = "$scriptcall -R $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'syslog'}{$syslog}{'ip'},$port";
                           } else {
                              $errmsg = "choosen syslog server [$syslog] has no ip config in rzenv.xml";
                              $logger->error("$errmsg  [" . session('user') . "]");
                              $retc = 50;
                           }
                        } else {
                           $logger->debug("$ll  no syslog server define  [" . session('user') . "]");
                        }
                     } ## end else [ if ( ref $params{'syslogserver'} eq 'ARRAY' ) ]
                  } elsif ( ( "$esxicore" eq "5" ) || ( "$esxicore" eq "6" ) ) {
                     if ( ref $params{'syslogserver'} eq 'ARRAY' ) {
                        foreach my $syslog ( @{ $params{'syslogserver'} } ) {
                           $logger->trace("$ll  syslog server: $srv  [" . session('user') . "]");
                           $port = "514";
                           $prot = "udp";
                           if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'ip'} ) {
                              if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'port'} ) {
                                 $port = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'port'};
                              }
                              if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'prot'} ) {
                                 $prot = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'prot'};
                              }
                              $scriptcall = "$scriptcall -R $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'syslog'}{$syslog}{'ip'},$port,$prot";
                           } else {
                              $errmsg = "choosen syslog server [$syslog] has no ip config in rzenv.xml";
                              $logger->error("$errmsg  [" . session('user') . "]");
                              $retc = 50;

                              #   break;
                           } ## end else [ if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'ip'} ) ]
                        } ## end foreach my $syslog ( @{ $params{'syslogserver'} } )
                     } else {
                        my $syslog = $params{'syslogserver'};
                        if ( $syslog ne "" ) {
                           if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'ip'} ) {
                              if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'port'} ) {
                                 $port = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'port'};
                              }
                              if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'prot'} ) {
                                 $prot = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syslog'}{$syslog}{'prot'};
                              }
                              $scriptcall = "$scriptcall -R $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'syslog'}{$syslog}{'ip'},$port,$prot";
                           } else {
                              $errmsg = "choosen syslog server has no ip config in rzenv.xml";
                              $logger->error("$errmsg  [" . session('user') . "]");
                              $retc = 50;
                           }
                        } else {
                           $logger->debug("$ll  no syslog server define  [" . session('user') . "]");
                        }
                     } ## end else [ if ( ref $params{'syslogserver'} eq 'ARRAY' ) ]
                  } else {
                     $errmsg = "unknown core esxi version";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 51;
                  }
               } ## end else [ if ( $params{'syslogsrv'} ne "" ) ]
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -V <virtual center>, <vc user>, <vc password>, <datacenter>
               my $vcsrv = "none";
               my $vcusr;
               my $vcdom = "none";
               my $vcpw;
               my $vcdc;
               if ( $params{'vcserver'} ne '' ) {
                  $vcsrv = $params{'vcserver'};
                  $logger->debug("$ll  use vc from manuel input: $vcsrv  [" . session('user') . "]");
                  if ( $params{'datacenter'} ne '' ) {
                     $vcdc = "\"$params{'datacenter'}\"";
                     $logger->debug("$ll  use dc: $vcdc  [" . session('user') . "]");
                  } else {
                     $logger->debug("$ll  no dc entered  [" . session('user') . "]");
                  }
                  if ( $params{'vcusr'} ne '' ) {
                     $vcusr = $params{'vcusr'};
                     $logger->debug("$ll  use user: $vcusr  [" . session('user') . "]");
                  } else {
                     $logger->debug("$ll  no user entered - ignore vc config  [" . session('user') . "]");
                     $vcsrv = "none";
                  }
                  if ( $params{'vcdom'} ne '' ) {
                     $vcdom = $params{'vcdom'};
                     $logger->debug("$ll  use domain: $vcdom  [" . session('user') . "]");
                  } else {
                     $logger->debug("$ll  no domain entered  [" . session('user') . "]");
                  }
                  if ( $params{'vcpw'} ne '' ) {
                     $vcpw = $params{'vcpw'};
                     $logger->debug("$ll  join user password found  [" . session('user') . "]");
                  } else {
                     $logger->debug("$ll  no user password entered  [" . session('user') . "]");
                  }
               } else {
                  if ( $params{'virtualcenter'} ne '' ) {
                     $vcsrv = $params{'virtualcenter'};
                     if ( "$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vc'}{$vcsrv}{'disable'}" eq "true" ) {
                        $logger->debug("$ll  do not join vc  [" . session('user') . "]");
                     } else {
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vc'}{$vcsrv}{'vcusr'} ne '' ) {
                           $vcusr = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vc'}{$vcsrv}{'vcusr'};
                        } else {
                           $errmsg = "no join vc user found";
                           $logger->error("$errmsg  [" . session('user') . "]");
                           $retc = 52;
                        }
                        unless ($retc) {
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vc'}{$vcsrv}{'vcdom'} ne '' ) {
                              $vcdom = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vc'}{$vcsrv}{'vcdom'};
                           } else {
                              $logger->debug("$ll  no domain given  [" . session('user') . "]");
                           }
                        } ## end unless ($retc)
                        unless ($retc) {
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vc'}{$vcsrv}{'vcpass'} ne '' ) {
                              $vcpw = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vc'}{$vcsrv}{'vcpass'};
                           } else {
                              $errmsg = "no join vc user password found";
                              $logger->error("$errmsg  [" . session('user') . "]");
                              $retc = 53;
                           }
                        } ## end unless ($retc)
                        unless ($retc) {
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vc'}{$vcsrv}{'dc'} ne '' ) {
                              $vcdc = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vc'}{$vcsrv}{'dc'}\"";
                           } else {
                              $errmsg = "no datacenter to join found";
                              $logger->error("$errmsg  [" . session('user') . "]");
                              $retc = 54;
                           }
                        } ## end unless ($retc)
                     } ## end else [ if ( "$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vc'}{$vcsrv}{'disable'}" eq "true" ) ]
                  } else {
                     $logger->debug("$ll  no virtual center given  [" . session('user') . "]");
                  }
               } ## end else [ if ( $params{'vcserver'} ne '' ) ]
               unless ($retc) {
                  if ( "$vcsrv" ne "none" ) {
                     if ( "$vcdom" eq "none" ) {
                        $scriptcall = "$scriptcall -V $vcsrv,$vcusr,,$vcpw,$vcdc";
                     } else {
                        $scriptcall = "$scriptcall -V $vcsrv,$vcusr,$vcdom,$vcpw,$vcdc";
                     }
                  } else {
                     $logger->info("$ll  no vc to join needed  [" . session('user') . "]");
                  }
               } ## end unless ($retc)
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # ToDo: -B <size> - block size local storage e.g. 2m
            }
            unless ($retc) {                                                                                                       # -n <switch>, <vlan>, <nics>, <mtu>, <loadbalance>, <comment flag to portgroup> - vmnetwork port
               if ( $params{'vmn'} eq '' ) {
                  $logger->trace("$ll  no virtual network for vm define  [" . session('user') . "]");
               } else {
                  if ( ref $params{'vmn'} eq 'ARRAY' ) {
                     $logger->trace("$ll  more than one virtual network define  [" . session('user') . "]");
                     foreach my $vmnet ( @{ $params{'vmn'} } ) {
                        my $switch = "0";
                        my $vlan   = "0";
                        my $nics   = "";
                        my $mtu    = "";
                        my $lb     = "";
                        my $cflags = "";
                        $logger->trace("$ll   found net: $vmnet  [" . session('user') . "]");
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'sw'} ne '' ) {
                           $switch = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'sw'};
                           $logger->trace("$ll    switch: $switch  [" . session('user') . "]");
                        }
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'cf'} ne '' ) {
                           $cflags = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'cf'}\"";
                           $logger->trace("$ll    comment flags: $cflags  [" . session('user') . "]");
                        }
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'nics'} ne '' ) {
                           $nics = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'nics'}\"";
                           $logger->trace("$ll    nics: $nics  [" . session('user') . "]");
                        }
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'lb'} ne '' ) {
                           $lb = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'lb'};
                           $logger->trace("$ll    loadbalance: $lb  [" . session('user') . "]");
                        }
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'vlan'} ne '' ) {
                           $vlan = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'vlan'};
                           $logger->trace("$ll    vlan: $vlan  [" . session('user') . "]");
                        }
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'mtu'} ne '' ) {
                           $mtu = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'mtu'};
                           $logger->trace("$ll    mtu: $mtu  [" . session('user') . "]");
                        }
                        $scriptcall = "$scriptcall -n $switch,$vlan,$nics,$mtu,$lb,$cflags";
                     } ## end foreach my $vmnet ( @{ $params{'vmn'} } )
                  } else {
                     $logger->trace("$ll  only one virtual network define  [" . session('user') . "]");
                     my $vmnet  = $params{'vmn'};
                     my $switch = "0";
                     my $vlan   = "0";
                     my $nics   = "";
                     my $mtu    = "";
                     my $lb     = "";
                     my $cflags = "";
                     $logger->trace("$ll   found net: $vmnet  [" . session('user') . "]");

                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'sw'} ne '' ) {
                        $switch = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'sw'};
                        $logger->trace("$ll    switch: $switch  [" . session('user') . "]");
                     }
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'cf'} ne '' ) {
                        $cflags = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'cf'}\"";
                        $logger->trace("$ll    comment flags: $cflags  [" . session('user') . "]");
                     }
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'nics'} ne '' ) {
                        $nics = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'nics'}\"";
                        $logger->trace("$ll    nics: $nics  [" . session('user') . "]");
                     }
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'lb'} ne '' ) {
                        $lb = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'lb'};
                        $logger->trace("$ll    loadbalance: $lb  [" . session('user') . "]");
                     }
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'vlan'} ne '' ) {
                        $vlan = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'vlan'};
                        $logger->trace("$ll    vlan: $vlan  [" . session('user') . "]");
                     }
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'mtu'} ne '' ) {
                        $mtu = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmn'}{$vmnet}{'mtu'};
                        $logger->trace("$ll    mtu: $mtu  [" . session('user') . "]");
                     }
                     $scriptcall = "$scriptcall -n $switch,$vlan,$nics,$mtu,$lb,$cflags";
                  } ## end else [ if ( ref $params{'vmn'} eq 'ARRAY' ) ]
               } ## end else [ if ( $params{'vmn'} eq '' ) ]
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -o <logfile>, <rotation>, <size>
               if ( $params{'logparam'} eq '' ) {
                  $logger->trace("$ll  no log parameter choosen - ignore  [" . session('user') . "]");
               } else {
                  if ( ref $params{'logparam'} eq 'ARRAY' ) {
                     $logger->trace("$ll  more than one log parameter choosen  [" . session('user') . "]");
                     foreach my $logpar_name ( @{ $params{'logparam'} } ) {
                        my $logpar_rot   = $logpar_name . "_rot";
                        my $logpar_size  = $logpar_name . "_size";
                        my $logrotparam  = "";
                        my $logsizeparam = "";
                        $logger->trace("$ll   found log name: $logpar_name  [" . session('user') . "]");
                        if ( $params{$logpar_rot} eq '' ) {
                           $logger->trace("$ll   no rotation for $logpar_name enter - try if default in rzenv.xml  [" . session('user') . "]");
                           if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syspar'}{$logpar_name}{'rot'} ) {
                              $logrotparam = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syspar'}{$logpar_name}{'rot'};
                              $logger->trace("$ll   found log parameter for rotation in rzenv.xml: [$logrotparam]  [" . session('user') . "]");
                           } else {
                              $logger->trace("$ll   do not found log parameter for rotation in rzenv.xml - ignore  [" . session('user') . "]");
                           }
                        } else {
                           $logger->trace("$ll   rotation parameter $params{$logpar_rot} for $logpar_name  [" . session('user') . "]");
                           $logrotparam = $params{$logpar_name};
                        }
                        if ( $params{$logpar_size} eq '' ) {
                           $logger->trace("$ll   no size for $logpar_name enter - try if default in rzenv.xml  [" . session('user') . "]");
                           if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syspar'}{$logpar_name}{'size'} ) {
                              $logsizeparam = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syspar'}{$logpar_name}{'size'};
                              $logger->trace("$ll   found log parameter for size in rzenv.xml: [$logsizeparam]  [" . session('user') . "]");
                           } else {
                              $logger->trace("$ll   do not found log parameter for size in rzenv.xml - ignore  [" . session('user') . "]");
                           }
                        } else {
                           $logger->trace("$ll   rotation parameter $params{$logpar_rot} for $logpar_size  [" . session('user') . "]");
                           $logsizeparam = $params{$logpar_size};
                        }
                        $logger->trace("$ll    name: [$logpar_name]  [" . session('user') . "]");
                        $logger->trace("$ll    rot: [$logrotparam]  [" . session('user') . "]");
                        $logger->trace("$ll    size: [$logsizeparam]  [" . session('user') . "]");
                        if ( ( $logpar_rot eq '' ) && ( $logpar_size eq '' ) ) {
                           $logger->debug("$ll   wether log rotation nor size entered or found in rzenv.xml for $logpar_name - ignore parameter  [" . session('user') . "]");
                        } else {
                           $logger->debug("$ll   found one of size or rotation - set config  [" . session('user') . "]");
                           $scriptcall = "$scriptcall -o $logpar_name,$logrotparam,$logsizeparam";
                        }
                     } ## end foreach my $logpar_name ( @{ $params{'logparam'} } )
                  } else {
                     $logger->trace("$ll  only one log parameter choosen  [" . session('user') . "]");
                     my $logpar_name  = $params{'logparam'};
                     my $logpar_rot   = $logpar_name . "_rot";
                     my $logpar_size  = $logpar_name . "_size";
                     my $logrotparam  = "";
                     my $logsizeparam = "";
                     $logger->trace("$ll   found log name: $logpar_name  [" . session('user') . "]");
                     if ( $params{$logpar_rot} eq '' ) {
                        $logger->trace("$ll   no rotation for $logpar_name enter - try if default in rzenv.xml  [" . session('user') . "]");
                        if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syspar'}{$logpar_name}{'rot'} ) {
                           $logrotparam = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syspar'}{$logpar_name}{'rot'};
                           $logger->trace("$ll   found log parameter for rotation in rzenv.xml: [$logrotparam]  [" . session('user') . "]");
                        } else {
                           $logger->trace("$ll   do not found log parameter for rotation in rzenv.xml - ignore  [" . session('user') . "]");
                        }
                     } else {
                        $logger->trace("$ll   rotation parameter $params{$logpar_rot} for $logpar_name  [" . session('user') . "]");
                        $logrotparam = $params{$logpar_name};
                     }
                     if ( $params{$logpar_size} eq '' ) {
                        $logger->trace("$ll   no size for $logpar_name enter - try if default in rzenv.xml  [" . session('user') . "]");
                        if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syspar'}{$logpar_name}{'size'} ) {
                           $logsizeparam = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'syspar'}{$logpar_name}{'size'};
                           $logger->trace("$ll   found log parameter for size in rzenv.xml: [$logsizeparam]  [" . session('user') . "]");
                        } else {
                           $logger->trace("$ll   do not found log parameter for size in rzenv.xml - ignore  [" . session('user') . "]");
                        }
                     } else {
                        $logger->trace("$ll   rotation parameter $params{$logpar_rot} for $logpar_size  [" . session('user') . "]");
                        $logsizeparam = $params{$logpar_size};
                     }
                     $logger->trace("$ll    name: [$logpar_name]  [" . session('user') . "]");
                     $logger->trace("$ll    rot: [$logrotparam]  [" . session('user') . "]");
                     $logger->trace("$ll    size: [$logsizeparam]  [" . session('user') . "]");
                     if ( ( $logpar_rot eq '' ) && ( $logpar_size eq '' ) ) {
                        $logger->debug("$ll   wether log rotation nor size entered or found in rzenv.xml for $logpar_name - ignore parameter  [" . session('user') . "]");
                     } else {
                        $logger->debug("$ll   found one of size or rotation - set config  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -o $logpar_name,$logrotparam,$logsizeparam";
                     }
                  } ## end else [ if ( ref $params{'logparam'} eq 'ARRAY' ) ]
               } ## end else [ if ( $params{'logparam'} eq '' ) ]
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -k <ip>, <switch>, <vlan>, <netmask>, <gateway>, <flags>, <mtu>, <nics>, <loadbalance>, <comment flag to portgroup> - vmkernel port
               foreach my $vmk ( keys %{ $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'} } ) {
                  $logger->trace("$ll  Found vmk: $vmk  [" . session('user') . "]");
                  if ( $params{$vmk} eq '' ) {
                     $logger->trace("$ll   no ip enter - ignore  [" . session('user') . "]");
                  } else {
                     $logger->trace("$ll   ip $params{$vmk} for $vmk  [" . session('user') . "]");

                     if ( $params{$vmk} =~ /^($ipre\.){3}$ipre$/ ) {
                        if ( check_srvonline( $params{$vmk} ) ) {
                           $errmsg = "ESXi VMKernel ip [$params{$vmk}] is already online";
                           $logger->error("$errmsg  [" . session('user') . "]");
                           $retc = 44;
                        } else {
                           my $flags  = "";
                           my $gw     = "";
                           my $nics   = "";
                           my $cflags = "";
                           my $sw     = "0";
                           my $vlan   = "0";
                           my $descr  = "";
                           my $nm     = "255.255.255.0";
                           my $mtu    = "";

                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'flags'} ne '' ) {
                              $flags = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmk'}{$vmk}{'flags'}\"";
                              $logger->trace("$ll    flags: $flags  [" . session('user') . "]");
                           }
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'gw'} ne '' ) {
                              $gw = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'gw'};
                              $logger->trace("$ll    gateway: $gw  [" . session('user') . "]");
                           }
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'nics'} ne '' ) {
                              $nics = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmk'}{$vmk}{'nics'}\"";
                              $logger->trace("$ll    nics: $nics  [" . session('user') . "]");
                           }
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'cf'} ne '' ) {
                              $cflags = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmk'}{$vmk}{'cf'}\"";
                              $logger->trace("$ll    comment flags: $cflags  [" . session('user') . "]");
                           }
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'sw'} ne '' ) {
                              $sw = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'sw'};
                              $logger->trace("$ll    switch: $sw  [" . session('user') . "]");
                           }
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'descr'} ne '' ) {
                              $descr = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmk'}{$vmk}{'descr'}\"";
                              $logger->trace("$ll    description: $descr  [" . session('user') . "]");
                           }
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'vlan'} ne '' ) {
                              $vlan = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'vlan'};
                              $logger->trace("$ll    vlan: $vlan  [" . session('user') . "]");
                           }
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'nm'} ne '' ) {
                              $nm = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'nm'};
                              $logger->trace("$ll    netmask: $nm  [" . session('user') . "]");
                           }
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'lb'} ne '' ) {
                              $lb = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'lb'};
                              $logger->trace("$ll    loadbalance: $lb  [" . session('user') . "]");
                           }
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'mtu'} ne '' ) {
                              $mtu = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'}{$vmk}{'mtu'};
                              $logger->trace("$ll    mtu: $mtu  [" . session('user') . "]");
                           }
                           $scriptcall = "$scriptcall -k $params{$vmk},$sw,$vlan,$nm,$gw,$flags,$mtu,$nics,$lb,$cflags";
                        } ## end else [ if ( check_srvonline( $params{$vmk} ) ) ]
                     } else {
                        $errmsg = "no correct vmk ip [$params{$vmk}] given";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 44;
                     }


                  } ## end else [ if ( $params{$vmk} eq '' ) ]
               } ## end foreach my $vmk ( keys %{ $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vmk'} } )
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -s <typ: nfs>, <storeage name>, <server>, <path> - datastore
               if ( $params{'nfs'} eq '' ) {
                  $logger->trace("$ll   no nfs storage define  [" . session('user') . "]");
               } else {
                  if ( ref $params{'nfs'} eq 'ARRAY' ) {
                     $logger->trace("$ll  more than one nfs storages define  [" . session('user') . "]");
                     foreach my $store ( @{ $params{'nfs'} } ) {
                        my $ip;
                        my $pfad;
                        $logger->trace("$ll   found storage: $store  [" . session('user') . "]");
                        $logger->trace("$ll    typ: nfs  [" . session('user') . "]");
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'nfs'}{$store}{'srv'} ne '' ) {
                           $ip = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'nfs'}{$store}{'srv'};
                           $logger->trace("$ll    srv ip: $ip  [" . session('user') . "]");
                        } else {
                           $errmsg = "no ip for nfs store $store define";
                           $logger->error("$errmsg  [" . session('user') . "]");
                           $retc = 56;
                        }
                        unless ($retc) {
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'nfs'}{$store}{'path'} ne '' ) {
                              $pfad = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'nfs'}{$store}{'path'};
                              $logger->trace("$ll    srv export path: $pfad  [" . session('user') . "]");
                           } else {
                              $errmsg = "no path for nfs store $store on $ip define";
                              $logger->error("$errmsg  [" . session('user') . "]");
                              $retc = 57;
                           }
                        } ## end unless ($retc)
                        unless ($retc) {
                           $scriptcall = "$scriptcall -s nfs,$store,$ip,$pfad";
                        }
                     } ## end foreach my $store ( @{ $params{'nfs'} } )
                  } else {
                     $logger->trace("$ll  only one nfs storage define  [" . session('user') . "]");
                     my $store = $params{'nfs'};
                     my $ip;
                     my $pfad;
                     $logger->trace("$ll   found storage: $store  [" . session('user') . "]");
                     $logger->trace("$ll    typ: nfs  [" . session('user') . "]");
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'nfs'}{$store}{'srv'} ne '' ) {
                        $ip = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'nfs'}{$store}{'srv'};
                        $logger->trace("$ll    srv ip: $ip  [" . session('user') . "]");
                     } else {
                        $errmsg = "no ip for nfs store $store define";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 56;
                     }
                     unless ($retc) {
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'nfs'}{$store}{'path'} ne '' ) {
                           $pfad = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'nfs'}{$store}{'path'};
                           $logger->trace("$ll    srv export path: $pfad  [" . session('user') . "]");
                        } else {
                           $errmsg = "no path for nfs store $store on $ip define";
                           $logger->error("$errmsg  [" . session('user') . "]");
                           $retc = 57;
                        }
                     } ## end unless ($retc)
                     unless ($retc) {
                        $scriptcall = "$scriptcall -s nfs,$store,$ip,$pfad";
                     }
                  } ## end else [ if ( ref $params{'nfs'} eq 'ARRAY' ) ]
               } ## end else [ if ( $params{'nfs'} eq '' ) ]
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -w <switch>, <nics>, <loadbalance>, <mtu> - virtual switch
               if ( $params{'vsw'} eq '' ) {
                  $errmsg = "no virtual switch define";
                  $logger->error("$errmsg  [" . session('user') . "]");
                  $retc = 55;
               } else {
                  if ( ref $params{'vsw'} eq 'ARRAY' ) {
                     $logger->trace("$ll  more than one virtual switch define  [" . session('user') . "]");
                     foreach my $vsw ( @{ $params{'vsw'} } ) {
                        my $swnr = "0";
                        my $nics = "";
                        my $mtu  = "";
                        my $lb   = "";
                        $logger->trace("$ll   found switch: $vsw  [" . session('user') . "]");
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'vs'} ne '' ) {
                           $swnr = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'vs'};
                           $logger->trace("$ll    switch number: $swnr  [" . session('user') . "]");
                        }
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'nics'} ne '' ) {
                           $nics = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'nics'}\"";
                           $logger->trace("$ll    nics: $nics  [" . session('user') . "]");
                        }
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'lb'} ne '' ) {
                           $lb = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'lb'};
                           $logger->trace("$ll    loadbalance: $lb  [" . session('user') . "]");
                        }
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'mtu'} ne '' ) {
                           $mtu = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'mtu'};
                           $logger->trace("$ll    mtu: $mtu  [" . session('user') . "]");
                        }
                        $scriptcall = "$scriptcall -w $swnr,$nics,$lb,$mtu";
                     } ## end foreach my $vsw ( @{ $params{'vsw'} } )
                  } else {
                     $logger->trace("$ll  only one virtual switch define  [" . session('user') . "]");
                     my $vsw  = $params{'vsw'};
                     my $swnr = "0";
                     my $nics = "";
                     my $mtu  = "";
                     my $lb   = "";
                     $logger->trace("$ll   found switch: $vsw  [" . session('user') . "]");
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'vs'} ne '' ) {
                        $swnr = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'vs'};
                        $logger->trace("$ll    switch number: $swnr  [" . session('user') . "]");
                     }
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'nics'} ne '' ) {
                        $nics = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'nics'}\"";
                        $logger->trace("$ll    nics: $nics  [" . session('user') . "]");
                     }
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'lb'} ne '' ) {
                        $lb = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'lb'};
                        $logger->trace("$ll    loadbalance: $lb  [" . session('user') . "]");
                     }
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'mtu'} ne '' ) {
                        $mtu = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'vsw'}{$vsw}{'mtu'};
                        $logger->trace("$ll    mtu: $mtu  [" . session('user') . "]");
                     }
                     $scriptcall = "$scriptcall -w $swnr,$nics,$lb,$mtu";
                  } ## end else [ if ( ref $params{'vsw'} eq 'ARRAY' ) ]
               } ## end else [ if ( $params{'vsw'} eq '' ) ]
            } ## end unless ($retc)

            unless ($retc) {                                                                                                       # -r <remote control>
               unless ( defined $params{'remoteboard'} ) {
                  $logger->trace("$ll  no remote control type found - ignore rc config  [" . session('user') . "]");
               } else {
                  if ( $params{'remoteboard'} eq "none" ) {
                     $logger->trace("$ll  remote control type = none - ignore rc config  [" . session('user') . "]");
                  } else {
                     $logger->trace("$ll  remote control type found [$params{'remoteboard'}]  [" . session('user') . "]");
                     my $scriptadd = "-r $params{'remoteboard'},'";

                     foreach my $rcparm ( keys %params ) {
                        if ( $rcparm =~ m/^remoteboard_/ ) {
                           $logger->trace("$ll  rcparm: $rcparm / value: $params{$rcparm}  [" . session('user') . "]");
                           my @fields = split /_\|_/, $rcparm;
                           my ( $rctype, $parameter, $paramname ) = @fields[ 1, 2, 3 ];
                           $logger->trace("$ll  rc type: $rctype / param: $parameter / param name: $paramname / value: $params{$rcparm}  [" . session('user') . "]");
                           if ( "$rctype" eq "$params{'remoteboard'}" ) {
                              if ( $global{'logprod'} < 10000 ) {
                                 my $dump = Dumper( \@fields );
                                 $logger->trace("$ll  Parameter Dump: [$dump]  [" . session('user') . "]");
                              }
                              if ( "$params{$rcparm}" ne "" ) {
                                 $logger->trace("$ll  found parameter [$parameter] with value [$params{$rcparm}]  [" . session('user') . "]");
                                 $scriptadd = "$scriptadd $parameter $params{$rcparm}";
                              } else {
                                 $logger->trace("$ll  empty value - search for default  [" . session('user') . "]");
                                 if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'remote'}{'ctrl'}{$rctype}{'ask'}{$paramname}{'default'} ) {
                                    $scriptadd = "$scriptadd $parameter $rzconfig{'rz'}{$global{'vienv'}}{'remote'}{'ctrl'}{$rctype}{'ask'}{$paramname}{'default'}";
                                 } else {
                                    $logger->debug("$ll  no value for $paramname - leave it empty  [" . session('user') . "]");
                                    $scriptadd = "$scriptadd $parameter";
                                 }
                              } ## end else [ if ( "$params{$rcparm}" ne "" ) ]
                           } ## end if ( "$rctype" eq "$params{'remoteboard'}" )
                        } ## end if ( $rcparm =~ m/^remoteboard_/ )
                     } ## end foreach my $rcparm ( keys %params )
                     $scriptadd = "$scriptadd'";
                     $logger->debug("$ll rc script call [$scriptadd]  [" . session('user') . "]");
                     $scriptcall = "$scriptcall $scriptadd";
                  } ## end else [ if ( $params{'remoteboard'} eq "none" ) ]
               } ## end else
            } ## end unless ($retc)

            unless ($retc) {                                                                                                       # -T <ntp server>
               if ( $params{'ntpsrv'} ne '' ) {
                  $logger->trace("$ll  manual ntp server input $params{'ntpsrv'}  [" . session('user') . "]");
                  ## ToDo: split in Array with , max 3

                  $scriptcall = "$scriptcall -T $params{'ntpsrv'}";



               } ## end if ( $params{'ntpsrv'} ne '' )
               if ( $params{'ntpserver'} eq '' ) {
                  $logger->trace("$ll  no ntp server choosen  [" . session('user') . "]");
               } else {
                  if ( ref $params{'ntpserver'} eq 'ARRAY' ) {
                     $logger->trace("$ll  more than one ntp server define  [" . session('user') . "]");
                     foreach my $ntpsrv ( @{ $params{'ntpserver'} } ) {
                        $logger->trace("$ll   found ntp server: $ntpsrv  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -T $ntpsrv";
                     }
                  } else {
                     $logger->trace("$ll  only one ntp server define  [" . session('user') . "]");
                     $logger->trace("$ll   found ntp server: $params{'ntpserver'}  [" . session('user') . "]");
                     $scriptcall = "$scriptcall -T $params{'ntpserver'}";
                  }
               } ## end else [ if ( $params{'ntpserver'} eq '' ) ]
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -d <dns server>
               if ( $params{'dnssrv'} ne '' ) {
                  $logger->trace("$ll  manual dns server input $params{'dnssrv'}  [" . session('user') . "]");

                  ## Todo: Split in Array with , max 3


                  if ( $params{'dnssrv'} =~ /^($ipre\.){3}$ipre$/ ) {
                     $scriptcall = "$scriptcall -d $params{'dnssrv'}";
                  } else {
                     $errmsg = "no correct dns server ip given";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 56;
                  }
               } ## end if ( $params{'dnssrv'} ne '' )
               if ( $params{'dnsserver'} eq '' ) {
                  $logger->trace("$ll  no dns server choosen  [" . session('user') . "]");
               } else {
                  if ( ref $params{'dnsserver'} eq 'ARRAY' ) {
                     $logger->trace("$ll  more than one dns server define  [" . session('user') . "]");
                     foreach my $dnssrv ( @{ $params{'dnsserver'} } ) {
                        $logger->trace("$ll   found dns server: $dnssrv  [" . session('user') . "]");
                        if ( $dnssrv =~ /^($ipre\.){3}$ipre$/ ) {
                           $scriptcall = "$scriptcall -d $dnssrv";
                        } else {
                           $errmsg = "no correct dns server ip given";
                           $logger->error("$errmsg  [" . session('user') . "]");
                           $retc = 56;

                           # break;
                        } ## end else [ if ( $dnssrv =~ /^($ipre\.){3}$ipre$/ ) ]
                     } ## end foreach my $dnssrv ( @{ $params{'dnsserver'} } )
                  } else {
                     $logger->trace("$ll  only one dns server define  [" . session('user') . "]");
                     $logger->trace("$ll   found dns server: $params{'dnsserver'}  [" . session('user') . "]");
                     if ( $params{'dnsserver'} =~ /^($ipre\.){3}$ipre$/ ) {
                        $scriptcall = "$scriptcall -d $params{'dnsserver'}";
                     } else {
                        $errmsg = "no correct dns server ip given";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 56;
                     }
                  } ## end else [ if ( ref $params{'dnsserver'} eq 'ARRAY' ) ]
               } ## end else [ if ( $params{'dnsserver'} eq '' ) ]
            } ## end unless ($retc)
            my @addroles;
            unless ($retc) {                                                                                                       # -u <user>, <password>, <group>, [optional: <description>, <login: yes/no>, <permission role>        - local user
               if ( $params{'AddLocalUser'} eq '' ) {
                  $logger->trace("$ll  no local user choosen  [" . session('user') . "]");
               } elsif ( ref $params{'AddLocalUser'} eq 'ARRAY' ) {
                  $logger->trace("$ll  add more than one local user  [" . session('user') . "]");
                  foreach my $user ( @{ $params{'AddLocalUser'} } ) {
                     $logger->trace("$ll   found local user: $user  [" . session('user') . "]");
                     my $adduser  = "";
                     my $addpw    = "";
                     my $addgroup = "";
                     my $adddescr = "";
                     my $addlogin;
                     my $addrole = "";
                     $adduser = ${ $params{$user} }[ 0 ];
                     $logger->trace("$ll    username: $adduser   [" . session('user') . "]");

                     if ( ${ $params{$user} }[ 1 ] eq "" ) {
                        $logger->trace("$ll    no new password enter - try to get it from rzenv.xml  [" . session('user') . "]");
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'user'}{$adduser}{'pw'} eq "" ) {
                           $logger->error("$ll    no password found in rzenv.xml - abort  [" . session('user') . "]");
                           $errmsg = "no password found in rzenv.xml or entered for user $adduser";
                           $retc   = 88;
                           last;
                        } else {
                           $logger->debug("$ll    take password from rzenv.xml for user $adduser  [" . session('user') . "]");
                           $addpw = "\"$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'user'}{$adduser}{'pw'}\"";
                           $logger->trace("$ll    user password: $addpw   [" . session('user') . "]");
                        }
                     } else {
                        $logger->debug("$ll    new password enter - take this one  [" . session('user') . "]");
                        $addpw = "\"${$params{$user}}[1]\"";
                        $logger->trace("$ll    user password: $addpw   [" . session('user') . "]");
                     }
                     unless ($retc) {
                        if ( ${ $params{$user} }[ 2 ] eq "" ) {
                           $logger->trace("$ll    no new description enter - try to get it from rzenv.xml  [" . session('user') . "]");
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'user'}{$adduser}{'descr'} eq "" ) {
                              $logger->error("$ll    no description found in rzenv.xml - empty  [" . session('user') . "]");
                           } else {
                              $logger->debug("$ll    take description from rzenv.xml for user $adduser  [" . session('user') . "]");
                              $adddescr = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'user'}{$adduser}{'descr'};
                              $logger->trace("$ll    user description: $adddescr   [" . session('user') . "]");
                           }
                        } else {
                           $logger->debug("$ll    new description enter - take this one  [" . session('user') . "]");
                           $adddescr = ${ $params{$user} }[ 2 ];
                           $logger->trace("$ll    user description: $adddescr   [" . session('user') . "]");
                        }
                     } ## end unless ($retc)
                     unless ($retc) {
                        if ( ${ $params{$user} }[ 3 ] eq "" ) {
                           $logger->trace("$ll    no new group enter - try to get it from rzenv.xml  [" . session('user') . "]");
                           if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'user'}{$adduser}{'group'} eq "" ) {
                              $logger->error("$ll    no group found in rzenv.xml - empty  [" . session('user') . "]");
                           } else {
                              $logger->debug("$ll    take group from rzenv.xml for user $adduser  [" . session('user') . "]");
                              $addgroup = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'user'}{$adduser}{'group'};
                              $logger->trace("$ll    user group: $addgroup   [" . session('user') . "]");
                           }
                        } else {
                           $logger->debug("$ll    new group enter - take this one  [" . session('user') . "]");
                           $addgroup = ${ $params{$user} }[ 3 ];
                           $logger->trace("$ll    user group: $addgroup   [" . session('user') . "]");
                        }
                     } ## end unless ($retc)
                     unless ($retc) {
                        if ( ${ $params{$user} }[ 4 ] eq "none" ) {
                           $logger->trace("$ll    no role define - empty  [" . session('user') . "]");
                        } else {
                           $addrole = ${ $params{$user} }[ 4 ];
                           $logger->trace("$ll    user role: $addrole   [" . session('user') . "]");
                           push @addroles, $addrole;
                        }
                     } ## end unless ($retc)
                     unless ($retc) {
                        $addlogin = ${ $params{$user} }[ 5 ];
                        $logger->trace("$ll    user login: $addlogin   [" . session('user') . "]");
                     }
                     unless ($retc) {
                        $scriptcall = "$scriptcall -u $adduser,$addpw,$addgroup,\"$adddescr\",$addlogin,$addrole";
                     }
                  } ## end foreach my $user ( @{ $params{'AddLocalUser'} } )
               } else {
                  $logger->trace("$ll  add one local user  [" . session('user') . "]");
                  my $user     = $params{'AddLocalUser'};
                  my $adduser  = "";
                  my $addpw    = "";
                  my $addgroup = "";
                  my $adddescr = "";
                  my $addlogin;
                  my $addrole = "";
                  $adduser = ${ $params{$user} }[ 0 ];
                  $logger->trace("$ll    username: $adduser   [" . session('user') . "]");

                  if ( ${ $params{$user} }[ 1 ] eq "" ) {
                     $logger->trace("$ll    no new password enter - try to get it from rzenv.xml  [" . session('user') . "]");
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'user'}{$adduser}{'pw'} eq "" ) {
                        $logger->error("$ll    no password found in rzenv.xml - abort  [" . session('user') . "]");
                        $errmsg = "no password found in rzenv.xml or entered for user $adduser";
                        $retc   = 88;
                     } else {
                        $logger->debug("$ll    take password from rzenv.xml for user $adduser  [" . session('user') . "]");
                        $addpw = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'user'}{$adduser}{'pw'};
                        $logger->trace("$ll    user password: $addpw   [" . session('user') . "]");
                     }
                  } else {
                     $logger->debug("$ll    new password enter - take this one  [" . session('user') . "]");
                     $addpw = ${ $params{$user} }[ 1 ];
                     $logger->trace("$ll    user password: $addpw   [" . session('user') . "]");
                  }
                  unless ($retc) {
                     if ( ${ $params{$user} }[ 2 ] eq "" ) {
                        $logger->trace("$ll    no new description enter - try to get it from rzenv.xml  [" . session('user') . "]");
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'user'}{$adduser}{'descr'} eq "" ) {
                           $logger->error("$ll    no description found in rzenv.xml - empty  [" . session('user') . "]");
                        } else {
                           $logger->debug("$ll    take description from rzenv.xml for user $adduser  [" . session('user') . "]");
                           $adddescr = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'user'}{$adduser}{'descr'};
                           $logger->trace("$ll    user description: $adddescr   [" . session('user') . "]");
                        }
                     } else {
                        $logger->debug("$ll    new description enter - take this one  [" . session('user') . "]");
                        $adddescr = ${ $params{$user} }[ 2 ];
                        $logger->trace("$ll    user description: $adddescr   [" . session('user') . "]");
                     }
                  } ## end unless ($retc)
                  unless ($retc) {
                     if ( ${ $params{$user} }[ 3 ] eq "" ) {
                        $logger->trace("$ll    no new group enter - try to get it from rzenv.xml  [" . session('user') . "]");
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'user'}{$adduser}{'group'} eq "" ) {
                           $logger->error("$ll    no group found in rzenv.xml - empty  [" . session('user') . "]");
                        } else {
                           $logger->debug("$ll    take group from rzenv.xml for user $adduser  [" . session('user') . "]");
                           $addgroup = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'user'}{$adduser}{'group'};
                           $logger->trace("$ll    user group: $addgroup   [" . session('user') . "]");
                        }
                     } else {
                        $logger->debug("$ll    new group enter - take this one  [" . session('user') . "]");
                        $addgroup = ${ $params{$user} }[ 3 ];
                        $logger->trace("$ll    user group: $addgroup   [" . session('user') . "]");
                     }
                  } ## end unless ($retc)
                  unless ($retc) {
                     if ( ${ $params{$user} }[ 4 ] eq "none" ) {
                        $logger->trace("$ll    no role define - empty  [" . session('user') . "]");
                     } else {
                        $addrole = ${ $params{$user} }[ 4 ];
                        $logger->trace("$ll    user role: $addrole   [" . session('user') . "]");
                        push @addroles, $addrole;
                     }
                  } ## end unless ($retc)
                  unless ($retc) {
                     $addlogin = ${ $params{$user} }[ 5 ];
                     $logger->trace("$ll    user login: $addlogin   [" . session('user') . "]");
                  }
                  unless ($retc) {
                     $scriptcall = "$scriptcall -u $adduser,$addpw,$addgroup,\"$adddescr\",$addlogin,$addrole";
                  }
               } ## end else [ if ( $params{'AddLocalUser'} eq '' ) ]
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -p <role name>, [<privileges> <...>]
               $logger->trace("$ll  first add all additional roles to array from added user roles  [" . session('user') . "]");
               if ( $params{'AddLocalRole'} eq '' ) {
                  $logger->trace("$ll  no additional local roles choosen  [" . session('user') . "]");
               } elsif ( ref $params{'AddLocalRole'} eq 'ARRAY' ) {
                  $logger->trace("$ll  add more than one role  [" . session('user') . "]");
                  push @addroles, @{ $params{'AddLocalRole'} };
               } else {
                  $logger->trace("$ll  one additional role choosen  [" . session('user') . "]");
                  push @addroles, $params{'AddLocalRole'};
               }
               $logger->trace("$ll  delete dopple role entries  [" . session('user') . "]");
               my %temprolehash = map { $_ => 1 } @addroles;
               my @addallroles = keys %temprolehash;
               $logger->trace("$ll  delete standard vmware roles  [" . session('user') . "]");
               my @vmwareroles = qw(NoAccess Anonymous View ReadOnly Admin);
               my %temphash;
               @temphash{@vmwareroles} = undef;                                                                                    # Initialise the hash using a slice
               @addallroles = grep { not exists $temphash{$_} } @addallroles;                                                      # delete if exist in @vmwareroles

               foreach my $addrolename (@addallroles) {
                  $logger->trace("$ll   role: $addrolename  [" . session('user') . "]");
                  my $addroleprivs = "";
                  foreach my $priv ( keys %{ $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'role'}{$addrolename}{'priv'} } ) {
                     $logger->trace("$ll    add priv: $priv  [" . session('user') . "]");
                     $addroleprivs = "$addroleprivs $priv";
                  }
                  unless ($retc) {
                     $addroleprivs =~ s/^ //s;                                                                                     # first space delete
                     $scriptcall = "$scriptcall -p $addrolename,\"$addroleprivs\"";
                  }
               } ## end foreach my $addrolename (@addallroles)
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -a <advanced-option-key>,<typ>,<value>
               if ( $params{'advkey'} ne '' ) {
                  $logger->trace("$ll  manual advances key input: $params{'advkey'}  [" . session('user') . "]");
                  $scriptcall = "$scriptcall -a $params{'advkey'}";
               }
               if ( $params{'advkeys'} eq '' ) {
                  $logger->trace("$ll  no advanced keys choosen  [" . session('user') . "]");
               } else {
                  if ( ref $params{'advkeys'} eq 'ARRAY' ) {
                     $logger->trace("$ll  more than one advanced keys define  [" . session('user') . "]");
                     foreach my $advkey ( @{ $params{'advkeys'} } ) {
                        $logger->trace("$ll   found key: $advkey  [" . session('user') . "]");
                        my $typ;
                        my $value;
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'advopt'}{$advkey}{'type'} ne '' ) {
                           $typ = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'advopt'}{$advkey}{'type'};
                           $logger->trace("$ll   typ: $typ  [" . session('user') . "]");
                        }
                        if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'advopt'}{$advkey}{'opt'} ne '' ) {
                           $value = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'advopt'}{$advkey}{'opt'};
                           $logger->trace("$ll   value: $value  [" . session('user') . "]");
                        }
                        $scriptcall = "$scriptcall -a $advkey,$typ,$value";
                     } ## end foreach my $advkey ( @{ $params{'advkeys'} } )
                  } else {
                     $logger->trace("$ll  only one advanced key define  [" . session('user') . "]");
                     my $advkey = $params{'advkeys'};
                     $logger->trace("$ll   found key: $key  [" . session('user') . "]");
                     my $typ;
                     my $value;
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'advopt'}{$advkey}{'type'} ne '' ) {
                        $typ = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'advopt'}{$advkey}{'type'};
                        $logger->trace("$ll   typ: $typ  [" . session('user') . "]");
                     }
                     if ( $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'advopt'}{$advkey}{'opt'} ne '' ) {
                        $value = $rzconfig{'rz'}{ $global{'vienv'} }{'esxi'}{'advopt'}{$advkey}{'opt'};
                        $logger->trace("$ll   value: $value  [" . session('user') . "]");
                     }
                     $scriptcall = "$scriptcall -a $advkey,$typ,$value";
                  } ## end else [ if ( ref $params{'advkeys'} eq 'ARRAY' ) ]
               } ## end else [ if ( $params{'advkeys'} eq '' ) ]
            } ## end unless ($retc)
            unless ($retc) {                                                                                                       # -m <vm> - not supported at moment
            }
            $logger->trace("$ll  script: $scriptcall  [" . session('user') . "]");
            $retc = add_esxi( $scriptcall, $params{'Server'} );
            unless ($retc) {
               set_flash("!S:Add esxi server $params{'Server'} ok!");
            } else {
               set_flash("!E:Error adding server $params{'Server'} - [$errmsg]");
            }
            return redirect "/$back";
         } elsif ( params->{'Back'} ) {
            $logger->trace("$ll  params back = $back  [" . session('user') . "]");
            return redirect "$back";
         } elsif ( params->{'Abort'} ) {
            set_flash("!W:User abort ESXi add server!");
            return redirect "$back";
         }
      } elsif ( request->method() eq "GET" ) {
         $logger->trace("$ll  show esxi input site  [" . session('user') . "]");
         $flvl--;
         if ( $global{'logprod'} < 10000 ) {
            my $dump = Dumper( \%rzconfig );
            $logger->trace("$ll  Parameter Dump: [$dump]");
         }
         my $sess_reload = $weburl;
         $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
         $retc = backurl_add("$sess_reload");
         template 'addesxi.tt',
           {
             'msg'      => get_flash(),
             'version'  => $ver,
             'vitemp'   => $host,
             'rzlist'   => \@rzlist,
             'rzconfig' => \%rzconfig,
             'vienv'    => $global{'vienv'}, };
      } else {
         template 'error',
           {
             'msg'     => "unknown method in /admin",
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'}, };
      } ## end else [ if ( request->method() eq "POST" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};

sub add_esxi {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $scriptcall = shift();
   my $server     = shift();
   my $file;
   my $fh;

   if ( "$server" eq "" ) {
      $server = "import";
   }
   unless ($retc) {
      $logger->debug("$ll  call $scriptcall  [" . session('user') . "]");
      unless ($retc) {
         $file = "$global{'toolsdir'}/create/esxi/c_" . $server . "_" . TimeStamp(13) . ".sh";
         open $fh, '>', $file or $retc = 88;
         if ($retc) {
            $errmsg = "Cannot open $file";
         }
      } ## end unless ($retc)
      unless ($retc) {
         print $fh "# Create esxi config in RZ: $global{'vienv'}\r\n";
         print $fh "#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------\r\n";
         print $fh "$scriptcall \r\n";
      }
      close($fh);
   } ## end unless ($retc)
   unless ($retc) {
      $logger->trace("$ll  chmod script  [" . session('user') . "]");
      my $rencount = chmod 0755, $file;
      unless ($rencount) {                                                                                                         # = 0 failed
         $retc   = 44;
         $errmsg = "Cannot chmod $file";
      }
   } ## end unless ($retc)
   unless ($retc) {
      $logger->info("$ll  Create Server now ...  [" . session('user') . "]");
      $logger->trace("$ll  cmd: [$file]  [" . session('user') . "]");
      my $eo = qx($file  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok  [" . session('user') . "]");
      } else {
         $logger->error("failed cmd   [" . session('user') . "]");
         $errmsg = "Cannot create config";
      }
   } ## end unless ($retc)
   unless ($retc) {
      $logger->debug("$ll add server to db  [" . session('user') . "]");
      $db = db_connect();
      if ( "$db" eq "undef" ) {
         $retc = 99;
         $logger->error("cannot reload db  [" . session('user') . "]");
         set_flash("!E:cannot reload db");
      } else {
         $retc = db_update($db);
         unless ($retc) {
            $logger->trace("$ll  ok  [" . session('user') . "]");
         } else {
            $logger->error("failed cmd  [" . session('user') . "]");
            $errmsg = "Cannot update db";
         }
      } ## end else [ if ( "$db" eq "undef" ) ]
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub add_esxi
