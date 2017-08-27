any [ 'get', 'post' ] => '/addxen' => sub {
   my $weburl = '/addxen';
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
         $logger->trace("$ll  start input from xen input site  [" . session('user') . "]");
         my %params;
         %params = params;
         my $reload = session('reload');
         my $back   = backurl_getlast("$reload");
         if ( params->{'OK'} ) {
            my $retc = 0;
            if ( $global{'logprod'} < 10000 ) {
               my $dump = Dumper( \%params );
               $logger->trace("$ll  Parameter Dump: [$dump]  [" . session('user') . "]");
            }
            $logger->trace("$ll  params = OK  [" . session('user') . "]");
            my $dompw;
            $logger->trace("$ll  xen server name: $params{'Server'}  [" . session('user') . "]");
            my $scriptcall = "$global{'toolsdir'}/mkx6 -l $global{'logfile'}.log";
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
            if ( check_srvonline( $params{'SrvIP'} ) ) {
               $errmsg = "$params{'Server'} with $params{'SrvIP'} is already online";
               $logger->error("$errmsg - abort  [" . session('user') . "]");
               $retc = 99;
            }

            unless ($retc) {
               my $tmpnm = "255.255.255.0";
               if ( $params{'srvnm'} ne '' ) {
                  $logger->debug("$ll  manually server ip netmask input $params{'srvnm'}  [" . session('user') . "]");
                  $tmpnm = $params{'srvnm'};
               } else {
                  if ( $params{'srvnetmask'} eq '' ) {
                     $logger->trace("$ll  no server netmask choosen in select box - take default  [" . session('user') . "]");
                  } else {
                     if ( ref $params{'srvnetmask'} eq 'ARRAY' ) {
                        $errmsg = "more than one server netmask define in select box - abort";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 99;
                     } else {
                        $logger->trace("$ll  server netmask define in select box  [" . session('user') . "]");
                        $logger->debug("$ll   found server netmask: $params{'srvnetmask'}  [" . session('user') . "]");
                        $tempnm = "$params{'srvnetmask'}";
                     }
                  } ## end else [ if ( $params{'srvnetmask'} eq '' ) ]
               } ## end else [ if ( $params{'srvnm'} ne '' ) ]

               unless ($retc) {
                  if ( $params{'Server'} eq '' ) {
                     $errmsg = "no server name given - abort";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 99;
                  } else {
                     $logger->debug("$ll  use xen server name: $params{'Server'}  [" . session('user') . "]");
                  }
               } ## end unless ($retc)

               unless ($retc) {
                  if ( $params{'SrvIP'} eq '' ) {
                     $errmsg = "no server ip given - abort";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 99;
                  } else {
                     $logger->debug("$ll  use xen server ip: $params{'SrvIP'}  [" . session('user') . "]");
                  }
               } ## end unless ($retc)

               unless ($retc) {
                  if ( $params{'GateIP'} eq '' ) {
                     $errmsg = "no server gateway ip given - abort";
                     $logger->error("$errmsg  [" . session('user') . "]");
                     $retc = 99;
                  } else {
                     $logger->debug("$ll  use xen server gateway ip: $params{'GateIP'}  [" . session('user') . "]");
                  }
               } ## end unless ($retc)

               unless ($retc) {
                  $scriptcall = "$scriptcall -c $mac,$params{'Server'},$params{'SrvIP'},$params{'GateIP'},$tmpnm";
               }
            } ## end unless ($retc)

            unless ($retc) {
               if ( $params{'xenver'} eq '' ) {
                  $errmsg = "no xen version given - abort";
                  $logger->error("$errmsg  [" . session('user') . "]");
                  $retc = 99;
               } else {
                  $logger->debug("$ll  use xen version: $params{'xenver'}  [" . session('user') . "]");
                  $scriptcall = "$scriptcall -x $params{'xenver'}";
               }
            } ## end unless ($retc)

            unless ($retc) {
               if ( $params{'pool'} eq '' ) {
                  $errmsg = "no xen pool given - abort";
                  $logger->error("$errmsg  [" . session('user') . "]");
                  $retc = 99;
               } else {
                  $logger->debug("$ll  use xen pool: $params{'pool'}  [" . session('user') . "]");
                  $scriptcall = "$scriptcall -p $params{'pool'}";
               }
            } ## end unless ($retc)

            unless ($retc) {
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

            unless ($retc) {
               if ( $params{'xentemplate'} eq '' ) {
                  $errmsg = "no xen template given - abort";
                  $logger->error("$errmsg  [" . session('user') . "]");
                  $retc = 99;
               } else {
                  $logger->debug("$ll  use xen template: $params{'xentemplate'}  [" . session('user') . "]");
                  $scriptcall = "$scriptcall -t $params{'xentemplate'}";
               }
            } ## end unless ($retc)

            unless ($retc) {
               if ( $params{'multihandle'} eq '' ) {
                  $logger->trace("$ll no multihandle given  [" . session('user') . "]");
               } else {
                  $logger->debug("$ll  use multipath handle: $params{'multihandle'}  [" . session('user') . "]");
                  $scriptcall = "$scriptcall -M $params{'multihandle'}";
               }
            } ## end unless ($retc)

            unless ($retc) {
               if ( ref $params{'VLAN'} eq 'ARRAY' ) {                                                                             # more than one vlan choosen
                  foreach my $netname ( @{ $params{'VLAN'} } ) {
                     $logger->debug("$ll  Found network: $netname  [" . session('user') . "]");
                     if ( "$netname" ne "NONE" ) {
                        $logger->trace("$ll    vlan: $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'vlan'}  [" . session('user') . "]");
                        $logger->trace("$ll    descr.: $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'descr'}  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -n $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'assign'},$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'vlan'},$netname,\"$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'descr'}\"";
                     } else {
                        $logger->info("$ll  no VLAN choosen  [" . session('user') . "]");
                     }
                  } ## end foreach my $netname ( @{ $params{'VLAN'} } )
               } else {
                  $logger->trace("$ll   only one vlan choosen?  [" . session('user') . "]");
                  if ( $params{'VLAN'} ) {
                     my $netname = $params{'VLAN'};
                     $logger->debug("$ll  Found network: $netname  [" . session('user') . "]");
                     if ( "$netname" ne "NONE" ) {
                        $logger->trace("$ll    vlan: $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'vlan'}  [" . session('user') . "]");
                        $logger->trace("$ll    descr.: $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'descr'}  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -n $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'assign'},$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'vlan'},$netname,\"$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'descr'}\"";
                     } else {
                        $logger->info("$ll  no VLAN choosen  [" . session('user') . "]");
                     }
                  } else {
                     $logger->info("$ll  no VLAN choosen  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'VLAN'} eq 'ARRAY' ) ]
               foreach my $ipnetname ( keys %{ $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'ipnet'} } ) {
                  $logger->debug("$ll  Found network: $ipnetname  [" . session('user') . "]");
                  if ( $params{$ipnetname} eq '' ) {
                     $logger->debug("$ll  no ip enter - ignore  [" . session('user') . "]");
                  } else {
                     if ( $params{$ipnetname} =~ /^($ipre\.){3}$ipre$/ ) {
                        $logger->trace("$ll  ip $params{$ipnetname} for $ipnetname  [" . session('user') . "]");
                        if ( check_srvonline( $params{$ipnetname} ) ) {
                           $errmsg = "$params{$ipnetname} is a online ip config";
                           $logger->error("$ll $errmsg - abort  [" . session('user') . "]");
                           $retc = 99;
                           last;
                        } else {
                           my $temptyp = $params{ $ipnetname . "_typ" };
                           $scriptcall = "$scriptcall -n $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'ipnet'}{$ipnetname}{'assign'},$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'ipnet'}{$ipnetname}{'vlan'},$ipnetname,\"$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'ipnet'}{$ipnetname}{'descr'}\"";
                           if ( $temptyp eq '' ) {
                              $logger->trace("$ll  default typ = storage  [" . session('user') . "]");
                              $scriptcall = "$scriptcall -i $ipnetname,$params{$ipnetname},storage";
                           } else {
                              $logger->trace("$ll  default typ = $temptyp  [" . session('user') . "]");
                              $scriptcall = "$scriptcall -i $ipnetname,$params{$ipnetname},$temptyp";
                           }
                        } ## end else [ if ( check_srvonline( $params{$ipnetname} ) ) ]
                     } else {
                        $errmsg = "ip for $ipnetname is not correct formated $params{$ipnetname} - abort";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 99;
                     }
                  } ## end else [ if ( $params{$ipnetname} eq '' ) ]
               } ## end foreach my $ipnetname ( keys %{ $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'ipnet'} } )
            } ## end unless ($retc)
            unless ($retc) {
               if ( ref $params{'SR'} eq 'ARRAY' ) {                                                                               # more than one sr choosen
                  foreach my $sr ( @{ $params{'SR'} } ) {
                     $logger->debug("$ll  Found SR: $sr  [" . session('user') . "]");
                     if ( "$sr" ne "NONE" ) {
                        $scriptcall = "$scriptcall -s $sr,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'ip'},$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'path'},$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'typ'}";
                        if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'sr'}{$sr}{'do'} ) {                               # defined geht ???
                           $logger->trace("$ll   create setting found: $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'do'}  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'do'}";
                        } else {
                           $logger->trace("$ll   take default create type = new  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,new";
                        }
                        if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'sr'}{$sr}{'shared'} ) {
                           $logger->trace("$ll   shared typ found = $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'shared'}  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'shared'}";
                           if ( $params{'mhf'} eq '' ) {
                              $logger->trace("$ll   no new mhf entered - search default  [" . session('user') . "]");
                              if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'sr'}{$sr}{'mhf'} ) {
                                 $logger->trace("$ll   ha mhf found = $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'mhf'}  [" . session('user') . "]");
                                 $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'mhf'}";
                              } else {
                                 $logger->trace("$ll   no mhf found - leave empty  [" . session('user') . "]");
                              }
                           } else {
                              $scriptcall = "$scriptcall,$params{'mhf'}";
                              $logger->trace("$ll   new mhf entered!  [" . session('user') . "]");
                           }
                        } else {
                           $logger->trace("$ll   take default shared typ true  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,true";
                        }
                        if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'sr'}{$sr}{'default'} ) {
                           $logger->trace("$ll   default sr setting found = $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'default'}  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'default'}";
                        } else {
                           $logger->trace("$ll   take default sr setting = false  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,false";
                        }
                        if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'sr'}{$sr}{'tag'} ) {
                           $logger->trace("$ll   tag setting for sr found = $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'tag'}  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,\"$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'tag'}\"";
                        } else {
                           $logger->trace("$ll   no tag found - leave it empty  [" . session('user') . "]");
                        }
                     } else {
                        $logger->info("$ll   no storage choosen  [" . session('user') . "]");
                     }
                  } ## end foreach my $sr ( @{ $params{'SR'} } )
               } else {
                  $logger->trace("$ll   only one sr choosen ?  [" . session('user') . "]");
                  if ( $params{'SR'} ) {
                     my $sr = $params{'SR'};
                     $logger->debug("$ll  Found SR: $sr  [" . session('user') . "]");
                     if ( "$sr" ne "NONE" ) {
                        $scriptcall = "$scriptcall -s $sr,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'ip'},$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'path'},$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'typ'}";
                        if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'sr'}{$sr}{'do'} ) {                                  # defined geht ???
                           $logger->trace("$ll   create setting found: $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'do'}  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'do'}";
                        } else {
                           $logger->trace("$ll   take default create type = new  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,new";
                        }
                        if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'sr'}{$sr}{'shared'} ) {
                           $logger->trace("$ll   shared typ found = $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'shared'}  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'shared'}";
                           if ( $params{'mhf'} eq '' ) {
                              $logger->trace("$ll   no new mhf entered - search default  [" . session('user') . "]");
                              if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'sr'}{$sr}{'mhf'} ) {
                                 $logger->trace("$ll   ha mhf found = $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'mhf'}  [" . session('user') . "]");
                                 $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'mhf'}";
                              } else {
                                 $logger->trace("$ll   no mhf found - leave empty  [" . session('user') . "]");
                              }
                           } else {
                              $scriptcall = "$scriptcall,$params{'mhf'}";
                              $logger->trace("$ll   new mhf entered!  [" . session('user') . "]");
                           }
                        } else {
                           $logger->trace("$ll   take default shared typ true  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,true";
                        }
                        if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'sr'}{$sr}{'default'} ) {
                           $logger->trace("$ll   default sr setting found = $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'default'}  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'default'}";
                        } else {
                           $logger->trace("$ll   take default sr setting = false  [" . session('user') . "]");
                           $scriptcall = "$scriptcall,false";
                        }
                     } else {
                     $logger->info("$ll   no storage choosen  [" . session('user') . "]");
                     }
                  } else {
                     $logger->info("$ll   no storage choosen  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'SR'} eq 'ARRAY' ) ]
            } ## end unless ($retc)
            unless ($retc) {
               if ( params->{'joindomain'} ) {
                  $logger->debug("$ll  join domain configure  [" . session('user') . "]");

                  #   -j <short dom>,<dns dom>,<ou>,<dom usr>,<dom pw>[,<_icmp_/tcp>]"
                  $scriptcall = "$scriptcall -j";
                  if ( $params{'shortdom'} eq '' ) {
                     $logger->trace("$ll   no new domain enter - take default  [" . session('user') . "]");
                     $scriptcall = "$scriptcall $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'dom_join'}";
                  } else {
                     $scriptcall = "$scriptcall $params{'shortdom'}";
                     $logger->trace("$ll   new domain entered!  [" . session('user') . "]");
                  }
                  if ( $params{'longdom'} eq '' ) {
                     $logger->trace("$ll   no new dns domain enter - take default  [" . session('user') . "]");
                     $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'dom_dns'}";
                  } else {
                     $scriptcall = "$scriptcall,$params{'longdom'}";
                     $logger->trace("$ll   new domain entered!  [" . session('user') . "]");
                  }
                  if ( $params{'dom_ou'} eq '' ) {
                     $logger->trace("$ll   no new ou for join domain enter - test if default exist  [" . session('user') . "]");
                     if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'dom_ou'} ) {
                        $logger->trace("$ll   default found  [" . session('user') . "]");
                        $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'dom_ou'}";
                     } else {
                        $logger->trace("$ll   no ou default - take empty  [" . session('user') . "]");
                        $scriptcall = ",";
                     }
                  } else {
                     $scriptcall = "$scriptcall,$params{'dom_ou'}";
                     $logger->trace("$ll   new ou entered!  [" . session('user') . "]");
                  }
                  if ( $params{'domuser'} eq '' ) {
                     $logger->trace("$ll   no new domain user enter - take default  [" . session('user') . "]");
                     $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'dom_user'}";
                  } else {
                     $scriptcall = "$scriptcall,$params{'domuser'}";
                     $logger->trace("$ll   new domain user entered!  [" . session('user') . "]");
                  }
                  if ( $params{'dompw'} eq '' ) {
                     $logger->trace("$ll   no pw enter - take default  [" . session('user') . "]");
                     $scriptcall = "$scriptcall,\'$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'dom_pw'}\'";
                  } else {
                     $scriptcall = "$scriptcall,$params{'dompw'}";
                     $logger->trace("$ll   pw enter!  [" . session('user') . "]");
                  }
                  if ( $params{'domconnect'} eq '' ) {
                     $logger->trace("$ll   no new domain connect typ enter - take default  [" . session('user') . "]");
                     $scriptcall = "$scriptcall,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'dom_contyp'}";
                  } else {
                     $scriptcall = "$scriptcall,$params{'domconnect'}";
                     $logger->trace("$ll   new domain connect typ entered!  [" . session('user') . "]");
                  }

                  #   -g <domain group>,<xen rolle>"
                  if ( $params{'xg-pooladmin'} eq '' ) {
                     $logger->trace("$ll   no new role group for pool-admin enter - test if default exist  [" . session('user') . "]");
                     if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'xenrole'}{'pool_admin'}{'domgroup'} ) {
                        $logger->trace("$ll   found default  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -g $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'xenrole'}{'pool_admin'}{'domgroup'},pool-admin";
                     } else {
                        $logger->trace("$ll   no pool-admin group found  [" . session('user') . "]");
                     }
                  } else {
                     $scriptcall = "$scriptcall -g $params{'xg-pooladmin'},pool-admin";
                     $logger->trace("$ll   new role group for pool-admin entered!  [" . session('user') . "]");
                  }
                  if ( $params{'xg-readonly'} eq '' ) {
                     $logger->trace("$ll   no new role group for read-only enter - test if default exist  [" . session('user') . "]");
                     if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'xenrole'}{'read_only'}{'domgroup'} ) {
                        $logger->trace("$ll   found default  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -g $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'xenrole'}{'read_only'}{'domgroup'},read-only";
                     } else {
                        $logger->trace("$ll   no read-only group found  [" . session('user') . "]");
                     }
                  } else {
                     $scriptcall = "$scriptcall -g $params{'xg-readonly'},read-only";
                     $logger->trace("$ll   new role group for read-only entered!  [" . session('user') . "]");
                  }
                  if ( $params{'xg-vmoperator'} eq '' ) {
                     $logger->trace("$ll   no new role group for vm-operator enter - test if default exist  [" . session('user') . "]");
                     if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'xenrole'}{'vm_operator'}{'domgroup'} ) {
                        $logger->trace("$ll   found default  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -g $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'xenrole'}{'vm_operator'}{'domgroup'},vm-operator";
                     } else {
                        $logger->trace("$ll   no vm-operator group found  [" . session('user') . "]");
                     }
                  } else {
                     $scriptcall = "$scriptcall -g $params{'xg-vmoperator'},vm-operator";
                     $logger->trace("$ll   new role group for vm-operator entered!  [" . session('user') . "]");
                  }
                  if ( $params{'xg-vmpoweradmin'} eq '' ) {
                     $logger->trace("$ll   no new role group for vm-poweradmin enter - test if default exist  [" . session('user') . "]");
                     if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'xenrole'}{'vm_power_admin'}{'domgroup'} ) {
                        $logger->trace("$ll   found default  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -g $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'xenrole'}{'vm_power_admin'}{'domgroup'},vm-power-admin";
                     } else {
                        $logger->trace("$ll   no vm-power-admin group found  [" . session('user') . "]");
                     }
                  } else {
                     $scriptcall = "$scriptcall -g $params{'xg-vmpoweradmin'},vm-power-admin";
                     $logger->trace("$ll   new role group for vm-power-admin entered!  [" . session('user') . "]");
                  }
                  if ( $params{'xg-pooloperator'} eq '' ) {
                     $logger->trace("$ll   no new role group for pool-operator enter - test if default exist  [" . session('user') . "]");
                     if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'xenrole'}{'pool_operator'}{'domgroup'} ) {
                        $logger->trace("$ll   found default  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -g $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'xenrole'}{'pool_operator'}{'domgroup'},pool-operator";
                     } else {
                        $logger->trace("$ll   no pool-operator group found  [" . session('user') . "]");
                     }
                  } else {
                     $scriptcall = "$scriptcall -g $params{'xg-pooloperator'},pool-operator";
                     $logger->trace("$ll   new role group for pool-operator entered!  [" . session('user') . "]");
                  }
                  if ( $params{'xg-vmadmin'} eq '' ) {
                     $logger->trace("$ll   no new role group for vm-admin enter - test if default exist  [" . session('user') . "]");
                     if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'xenrole'}{'vm_admin'}{'domgroup'} ) {
                        $logger->trace("$ll   found default  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -g $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'xenrole'}{'vm_admin'}{'domgroup'},vm-admin";
                     } else {
                        $logger->trace("$ll   no vm-admin group found  [" . session('user') . "]");
                     }
                  } else {
                     $scriptcall = "$scriptcall -g $params{'xg-vmadmin'},vm-admin";
                     $logger->trace("$ll   new role group for vm-admin entered!  [" . session('user') . "]");
                  }
               } else {
                  $logger->trace("$ll  no join domain configure  [" . session('user') . "]");
               }
            } ## end unless ($retc)

            unless ($retc) {
               if ( $params{'dnsdom'} ne '' ) {
                  $logger->debug("$ll  manually dns domain input $params{'dnsdom'}  [" . session('user') . "]");
                  $scriptcall = "$scriptcall -o $params{'dnsdom'}";
               } else {
                  if ( $params{'dnsdomain'} eq '' ) {
                     $logger->trace("$ll  no dns domain choosen in select box - no dns configure  [" . session('user') . "]");
                  } else {
                     if ( ref $params{'dnsdomain'} eq 'ARRAY' ) {
                        $errmsg = "more than one dns domain define in select box - abort";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 99;
                     } else {
                        $logger->trace("$ll  dns domain define in select box  [" . session('user') . "]");
                        $logger->debug("$ll   found dns domain: $params{'dnsdomain'}  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -o $params{'dnsdomain'}";
                     }
                  } ## end else [ if ( $params{'dnsdomain'} eq '' ) ]
               } ## end else [ if ( $params{'dnsdom'} ne '' ) ]
            } ## end unless ($retc)

            unless ($retc) {
               my $tempdnssearch = "";
               if ( $params{'dnssearchdom'} ne '' ) {
                  $logger->debug("$ll  manually dns search domain input $params{'dnssearchdom'}  [" . session('user') . "]");
                  $tempdnssearch = "$params{'dnssearchdom'}";
               }
               if ( $params{'dnssearchdomains'} eq '' ) {
                  $logger->trace("$ll  no dns search domain choosen in select box  [" . session('user') . "]");
               } else {
                  if ( ref $params{'dnssearchdomains'} eq 'ARRAY' ) {
                     $logger->trace("$ll  more than one dns search domains define in select box  [" . session('user') . "]");
                     foreach my $dnssearchs ( @{ $params{'dnssearchdomains'} } ) {
                        $logger->debug("$ll   found dns search domain: $dnssearchs  [" . session('user') . "]");
                        $tempdnssearch = "$tempdnssearch,$dnssearchs";
                     }
                  } else {
                     $logger->trace("$ll  only one dns search domain define in select box  [" . session('user') . "]");
                     $logger->debug("$ll   found dns search domain: $params{'dnssearchdomains'}  [" . session('user') . "]");
                     $tempdnssearch = "$tempdnssearch,$params{'dnssearchdomains'}";
                  }
               } ## end else [ if ( $params{'dnssearchdomains'} eq '' ) ]
               if ( "$tempdnssearch" ne "" ) {
                  $tempdnssearch =~ s/^,//;                                                                                        # remove starting ,
                  $scriptcall = "$scriptcall -d $tempdnssearch";
               } else {
                  $errmsg = "wrong ip adr for dns server [$tempdnssrv]";
                  $logger->error("$errmsg  [" . session('user') . "]");
                  $retc = 99;
               }
            } ## end unless ($retc)

            unless ($retc) {
               my $tempdnssearch = "";
               if ( $params{'dnssrv'} ne '' ) {
                  $logger->debug("$ll  manually dns server input $params{'dnssrv'}  [" . session('user') . "]");
                  my @tmpdnsserver = split /,/, $params{'dnssrv'};
                  foreach $tempdnssrv (@tmpdnsserver) {
                     if ( $tempdnssrv =~ /^($ipre\.){3}$ipre$/ ) {
                        $scriptcall = "$scriptcall -a $tempdnssrv";
                     } else {
                        $errmsg = "wrong ip adr for dns server [$tempdnssrv]";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 99;
                     }
                  } ## end foreach $tempdnssrv (@tmpdnsserver)
               } ## end if ( $params{'dnssrv'} ne '' )
               if ( $params{'dnsserver'} eq '' ) {
                  $logger->trace("$ll  no dns server choosen in select box  [" . session('user') . "]");
               } else {
                  if ( ref $params{'dnsserver'} eq 'ARRAY' ) {
                     $logger->trace("$ll  more than one dns server define in select box  [" . session('user') . "]");
                     foreach my $dnsserver ( @{ $params{'dnsserver'} } ) {
                        $logger->debug("$ll   found dns server: $dnsserver  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -a $dnsserver";
                     }
                  } else {
                     $logger->trace("$ll  only one dns server define in select box  [" . session('user') . "]");
                     $logger->debug("$ll   found dns server: $params{'dnsserver'}  [" . session('user') . "]");
                     $scriptcall = "$scriptcall -a $params{'dnsserver'}";
                  }
               } ## end else [ if ( $params{'dnsserver'} eq '' ) ]
            } ## end unless ($retc)




            unless ($retc) {
               if ( $params{'syslogsrv'} ne '' ) {
                  $logger->debug("$ll  manually syslog server input $params{'syslogsrv'}  [" . session('user') . "]");
                  $scriptcall = "$scriptcall -y $params{'syslogsrv'}";
               } else {
                  if ( $params{'syslogserver'} eq '' ) {
                     $logger->trace("$ll  no syslog server choosen in select box - no syslog server configure  [" . session('user') . "]");
                  } else {
                     if ( ref $params{'syslogserver'} eq 'ARRAY' ) {
                        $errmsg = "more than one syslog server define in select box - abort";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 99;
                     } else {
                        $logger->trace("$ll  syslog server define in select box  [" . session('user') . "]");
                        $logger->debug("$ll   found syslog server: $params{'syslogserver'}  [" . session('user') . "]");
                        if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'syslog'}{ $params{'syslogserver'} }{'ip'} ) {
                           $logger->trace("$ll  found syslog ip in rzenv.xml  [" . session('user') . "]");
                           $scriptcall = "$scriptcall -y $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'syslog'}{$params{'syslogserver'}}{'ip'}";
                        } else {
                           $errmsg = "cannot find syslog ip parameter in rzenv.xml - abort";
                           $logger->error("$errmsg  [" . session('user') . "]");
                           $retc = 99;
                        }
                     } ## end else [ if ( ref $params{'syslogserver'} eq 'ARRAY' ) ]
                  } ## end else [ if ( $params{'syslogserver'} eq '' ) ]
               } ## end else [ if ( $params{'syslogsrv'} ne '' ) ]
            } ## end unless ($retc)


            unless ($retc) {
               my $templic = "";
               if ( $params{'lictyp'} ne '' ) {
                  $logger->debug("$ll  manual lic type input $params{'lictyp'}  [" . session('user') . "]");
                  $templic = "$params{'lictyp'}";
               } else {
                  if ( $params{'lictype'} eq '' ) {
                     $logger->trace("$ll  no license type choosen in select box - take default  [" . session('user') . "]");
                     $templic = "free";
                  } else {
                     if ( ref $params{'lictype'} eq 'ARRAY' ) {
                        $errmsg = "more than one license type define in select box - abort";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        $retc = 99;
                     } else {
                        $logger->trace("$ll  license type define in select box  [" . session('user') . "]");
                        $logger->debug("$ll   found license type: $params{'lictype'}  [" . session('user') . "]");
                        $templic = "$params{'lictype'}";
                     }
                  } ## end else [ if ( $params{'lictype'} eq '' ) ]
               } ## end else [ if ( $params{'lictyp'} ne '' ) ]
               unless ($retc) {
                  if ( "$templic" ne "free" ) {
                     if ( $params{'licsrv'} ne '' ) {
                        $logger->debug("$ll  manually license server input $params{'licsrv'}  [" . session('user') . "]");
                        $scriptcall = "$scriptcall -b $templic,$params{'licsrv'}";
                     } else {
                        if ( $params{'licserver'} eq '' ) {
                           $errmsg = "no license server choosen in select box - abort";
                           $logger->error("$errmsg  [" . session('user') . "]");
                           $logger->trace("$ll  license type other than free need lic server  [" . session('user') . "]");
                           $retc = 99;
                        } else {
                           if ( ref $params{'licserver'} eq 'ARRAY' ) {
                              $errmsg = "more than one license server define in select box - abort";
                              $logger->error("$errmsg  [" . session('user') . "]");
                              $retc = 99;
                           } else {
                              $logger->trace("$ll  license server define in select box  [" . session('user') . "]");
                              $logger->debug("$ll   found license server: $params{'licserver'}  [" . session('user') . "]");
                              if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'licip'}{ $params{'licserver'} }{'ip'} ) {
                                 $logger->trace("$ll  found license ip in rzenv.xml  [" . session('user') . "]");
                                 $scriptcall = "$scriptcall -b $templic,$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'licip'}{$params{'licserver'}}{'ip'},$rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'licip'}{$params{'licserver'}}{'port'}";
                              } else {
                                 $errmsg = "cannot find license ip parameter in rzenv.xml - abort";
                                 $logger->error("$errmsg  [" . session('user') . "]");
                                 $retc = 99;
                              }
                           } ## end else [ if ( ref $params{'licserver'} eq 'ARRAY' ) ]
                        } ## end else [ if ( $params{'licserver'} eq '' ) ]
                     } ## end else [ if ( $params{'licsrv'} ne '' ) ]
                  } ## end if ( "$templic" ne "free" )
               } else {
                  $logger->debug("$ll xen lic type free need no lic server config  [" . session('user') . "]");
                  $scriptcall = "$scriptcall -b $templic";
               }
            } ## end unless ($retc)


            unless ($retc) {
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
                  $scriptcall = "$scriptcall -e $newntpserver";
               }
            }


            unless ($retc) {
               if ( $params{'rootpw'} eq '' ) {
                  $logger->trace("$ll   no new root password enter - take default  [" . session('user') . "]");
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'xensrv'}{'pw'} ) {
                     $logger->trace("$ll   found default  [" . session('user') . "]");
                     $scriptcall = "$scriptcall -w '" . $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'pw'} . "'";
                  } else {
                     $logger->trace("$ll   no default root password found - abort  [" . session('user') . "]");
                     $retc = 99;
                  }
               } else {
                  $scriptcall = "$scriptcall -w '" . $params{'rootpw'} . "'";
                  $logger->trace("$ll   new root password entered!  [" . session('user') . "]");
               }
            } ## end unless ($retc)
            unless ($retc) {
               if ( "$params{'Maintain'}" eq "yes" ) {
                  $logger->trace("$ll   set maintenance mode after install  [" . session('user') . "]");
                  $scriptcall = "$scriptcall -m";
               } else {
                  $logger->trace("$ll   do not set maintenance mode after install  [" . session('user') . "]");
               }
            } ## end unless ($retc)
            unless ($retc) {
               if ( "$params{'mc'}" eq "yes" ) {
                  $logger->trace("$ll   install mc  [" . session('user') . "]");
                  $scriptcall = "$scriptcall -I mc";
               } else {
                  $logger->trace("$ll   do not install mc  [" . session('user') . "]");
               }
            } ## end unless ($retc)


            $logger->debug("$ll  call $scriptcall  [" . session('user') . "]");
            $retc = add_xen( $scriptcall, $params{'Server'}, $params{'pool'}, $params{'Deploy'} );
            unless ($retc) {
               set_flash("!S:Add server $params{'Server'} ok!");
            } else {
               set_flash("!E:Error adding server $params{'Server'} - [$errmsg]");
            }
            $flvl--;
            return redirect $back;
         } elsif ( params->{'Back'} ) {
            $flvl--;
            return redirect $back;
         } elsif ( params->{'Abort'} ) {
            $flvl--;
            set_flash("!W:User abort input to create xen server configuration add server!");
            return redirect $back;
         }
      } elsif ( request->method() eq "GET" ) {
         $logger->trace("$ll  show xen input site  [" . session('user') . "]");
         my $sess_reload = '/addxen';
         $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
         $retc = backurl_add("$sess_reload");
         $flvl--;
         template 'addxen.tt',
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

sub add_xen {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $scriptcall = shift();
   my $server     = shift();
   my $pool       = shift();
   my $deploy     = shift();
   if ( "$deploy" eq "" ) {
      $deploy = "no";
   }
   $logger->trace("$ll  cmd: $cmd  [" . session('user') . "]");
   my $fh;
   my $file;
   unless ($retc) {
      $file = "$global{'toolsdir'}/create/xen/c_" . $server . "_" . TimeStamp(13) . ".sh";
      open $fh, '>', $file or $retc = 88;
      if ($retc) {
         $errmsg = "Cannot open $file";
      }
   } ## end unless ($retc)
   unless ($retc) {
      print $fh "# Create xenserver config in RZ: $global{'vienv'}\r\n";
      print $fh "#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------\r\n";
      print $fh "$scriptcall \r\n";
   }
   close($fh);
   unless ($retc) {
      $logger->trace("$ll  chmod script  [" . session('user') . "]");
      my $rencount = chmod 0755, $file;
      unless ($rencount) {                                                                                                         # = 0 failed
         $retc   = 44;
         $errmsg = "Cannot chmod $file";
      }
   } ## end unless ($retc)
   unless ($retc) {                                                                                                                # clean ssh pool files
      $logger->debug("$ll create pool [$pool] ssh files  [" . session('user') . "]");
      my $command = "$global{'toolsdir'}/cssh2pool -p $pool -l $global{'logfile'}.log";
      $logger->trace("$ll  cmd: [$command]  [" . session('user') . "]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok  [" . session('user') . "]");
      } else {
         $logger->error("failed cmd   [" . session('user') . "]");
         $errmsg = "Cannot create ssh pool files";
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
      my $command = $global{'progdir'} . "/fsic.pl -q --update $pool -l $global{'logdir'}/fsi";
      $logger->trace("$ll  cmd: [$command]  [" . session('user') . "]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok  [" . session('user') . "]");
      } else {
         $logger->error("failed cmd   [" . session('user') . "]");
         $errmsg = "Cannot update db";
      }
   } ## end unless ($retc)
   unless ($retc) {
      $logger->debug("$ll check pool count  [" . session('user') . "]");
      my $command = $global{'progdir'} . "/fsic.pl -q --xpc -l $global{'logdir'}/fsi";
      $logger->trace("$ll  cmd: [$command]  [" . session('user') . "]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok  [" . session('user') . "]");
      } else {
         $logger->error("failed cmd   [" . session('user') . "]");
         $errmsg = "Cannot update db";
      }
   } ## end unless ($retc)
   unless ($retc) {
      if ( "$deploy" eq "yes" ) {
         $logger->debug("$ll deploy new ssh files to all server in pool [$pool]  [" . session('user') . "]");
         unless ($retc) {
            my $command = "$global{'toolsdir'}/sshkeyclean -l $global{'logdir'}/fsi.log -p $pool";
            $logger->trace("$ll  cmd: [$command]  [" . session('user') . "]");
            my $eo = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            unless ($retc) {
               $logger->trace("$ll  ok  [" . session('user') . "]");
            } else {
               $logger->error("failed cmd [$eo]  [" . session('user') . "]");
               $errmsg = "Error during cleaning ssh keys in pool";
               set_flash("!E:$errmsg");
            }
         } ## end unless ($retc)
         unless ($retc) {
            my $command = "$global{'toolsdir'}/cssh2server -l $global{'logdir'}/fsi.log -p $pool";
            $logger->trace("$ll  cmd: [$command]  [" . session('user') . "]");
            my $eo = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            unless ($retc) {
               $logger->trace("$ll  ok  [" . session('user') . "]");
            } else {
               $logger->error("failed cmd   [" . session('user') . "]");
               $errmsg = "Cannot deploy ssh files to xenserver in pool";
            }
         } ## end unless ($retc)
      } else {
         $logger->debug("$ll do not deploy ssh files  [" . session('user') . "]");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub add_xen
