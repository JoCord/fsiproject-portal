sub db_reload {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $pool = shift;
   
   my $db   = db_connect();
   my $sql  = 'select id, db_srv, db_typ, db_mac, db_control, db_controltyp, mgmt_ip, mgmt_user, mgmt_pwc, mgmt_pw, rc_type, rc_icon, rc_desc, rc_http, rc_ssh, srv_type, srv_cmd, j_inst, j_logshow, s_online, s_inststart, s_instrun, s_block, block_user,s_insterr, s_msg, s_instwait, s_xenmaster, s_xenha, s_patchlevel, s_patchlevels, x_poolcount from entries order by id desc';
   my $sth  = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   $serverhash_p = $sth->fetchall_hashref('id');
   $retc=db_disconnect($db);

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub db_reload

sub db_disconnect {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc  = 0;
   my $dbh = shift;
   $logger->trace("$ll  db handle: $dbh");
   $dbh->disconnect or $rc = 99;

   if ($rc) {
      $global{'errmsg'} = $dbh->errstr;
      $logger->error("DB Meldung: [$global{'errmsg'}]");
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub db_disconnect

sub db_connect {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $port = shift();
   if ( defined $port ) {

      if ( "$port" eq "" ) {
         $port = $global{'port'};
         $logger->trace("$ll   take default db port: $port");
      } else {
         $logger->trace("$ll   take new db port: $port");
      }
   } else {
      $port = $global{'port'};
      $logger->trace("$ll   take default db port: $port");
   }
   my $dbh;
   if ( ( defined $global{'fsidb'} ) && ( defined $global{'fsihost'} ) && ( defined $global{'fsiusr'} ) && ( defined $global{'fsipw'} ) ) {
      $dbh = DBI->connect( "dbi:Pg:dbname=$global{'fsidb'};host=$global{'fsihost'};port=$port", $global{'fsiusr'}, $global{'fsipw'}, { AutoCommit => 1, RaiseError => 0, PrintError => 1 } ) or $retc = 99;
      if ($retc) {
         $global{'errmsg'} = $DBI::errstr;
         $dbh = "";
      } else {
         $logger->trace("$ll  db connect ok");
         $logger->trace("$ll  db handle: $dbh");
      }
   } else {
      $logger->error("one or more db parameter missing - abort");
      $dbh = "undef";
   }
   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $dbh;
} ## end sub db_connect

sub db_get_mac {   
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $retmac = "";
   
   my $server = shift();
   my $dbh    = db_connect;
   my $sql    = "SELECT db_mac FROM entries WHERE db_srv = \'$server\'";
   $logger->trace("$ll  sql: $sql");
   my $sth = $dbh->prepare($sql) or die $dbh->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid = $sth->rows;

   if ( $lastid > 1 ) {
      $logger->error("$ll  find more than one server entry - do not know which one I must use - abort");
      $rc = 99;
   } elsif ( $lastid == 1 ) {
      my @macs = $sth->fetchrow_array;

#      foreach my $mac (@macs) {
      my $mac = $macs[ 0 ];
      $logger->trace("$ll  found mac: $mac");
      if ( $mac =~ /^([0-9A-Fa-f]{1,2}[\.:-]){5}([0-9A-Fa-f]{1,2})$/ ) {
         $mac =~ s/[:|.]/-/g;
         $mac    = lc($mac);
         $retmac = $mac;
      } else {
         $errmsg = "mac not correkt formated - [$mac]";
         $logger->error("$errmsg");
         $retc = 77;
      }

#      }
   } else {
      $logger->error("$ll  server $server not found in db - abort");
   }
   $sth->finish();
   $rc = db_disconnect($dbh);
   $logger->trace("$ll func end: [$fc] - rc=$rc");
   $flvl--;
   $logger->level($llback);
   return $retmac;
} ## end sub db_get_mac

sub db_get_typ_pool {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $rettyp = "";
   
   my $pool   = shift();

   my $dbh    = db_connect;
   my $sql    = "SELECT db_typ FROM entries WHERE db_control = \'$pool\'";
   $logger->trace("$ll  sql: $sql");
   my $sth = $dbh->prepare($sql) or die $dbh->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid = $sth->rows;

   if ( $lastid > 0 ) {
      my @typ = $sth->fetchrow_array;
      $rettyp = $typ[ 0 ];
      $logger->trace("$ll Typ: $rettyp");
   } else {
      $logger->error("$ll  server found in pool [$pool] in db - abort");
   }
   
   $sth->finish();
   $rc = db_disconnect($dbh);
   $logger->trace("$ll func end: [$fc] - rc=$rc");
   $flvl--;
   $logger->level($llback);
   return $rettyp;
} 

sub db_get_typ_srv {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $rettyp = "";
   my $server = shift();
   
   my $dbh    = db_connect;
   my $sql    = "SELECT db_typ FROM entries WHERE db_srv = \'$server\'";
   $logger->trace("$ll  sql: $sql");
   my $sth = $dbh->prepare($sql) or die $dbh->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid = $sth->rows;

   if ( $lastid > 1 ) {
      $logger->error("$ll  find more than one server entry - do not know which one I must use - abort");
      $rc = 99;
   } elsif ( $lastid == 1 ) {
      my @typ = $sth->fetchrow_array;
      $logger->trace("$ll Typ: $typ[0]");
      $rettyp = $typ[ 0 ];
   } else {
      $logger->error("$ll  server $server not found in db - abort");
   }

   $sth->finish();
   $rc = db_disconnect($dbh);

   $logger->trace("$ll func end: [$fc] - rc=$rc");
   $flvl--;
   $logger->level($llback);
   return $rettyp;
}

sub db_set_info {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc=0;         # default reading - check if not
   my $typ=shift();
   my $who=shift();
   my $status=shift();
   my $info=shift();

   my $dbh    = db_connect;

   my $sql = "SELECT who FROM $global{'dbt_worker'} WHERE who = \'$who\'";
   my $sth = $dbh->prepare($sql) or die $dbh->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   if ( $lastid == 0 ) {
      $logger->trace("$ll add new $who in work stat table");
      
      my $sqladd = 'INSERT INTO ' . $global{'dbt_worker'} . ' (typ, who, status, info ) values (?,?,?,?)';
      my $sthadd = $dbh->prepare($sqladd) or die $dbh->errstr;
      $sthadd->execute( $typ, $who, $status, $info );
      my $fehler = $sthadd->errstr;
      if ($fehler) {
         $logger->error("DB message: $fehler");
         $retc = 99;
      } else {
         $sthadd->finish();
      }
   } else {
      $logger->trace("$ll change $who in work stat table");

      my $updatecmd = "UPDATE $global{'dbt_worker'} SET info = '$info', status = '$status'  WHERE who = '$who' ";
      my $updsth = $dbh->prepare($updatecmd) or die $dbh->errstr;
      $logger->trace("$ll  $updatecmd");
      $updsth->execute();
      my $fehler = $sth->errstr;
      if ($fehler) {
         $logger->error("DB Meldung: $fehler");
      } else {
         $updsth->finish();
      }
   }

   $retc = db_disconnect($dbh);

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
}



sub db_get_control {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $rettyp = "";
   my $server = shift();
   my $dbh    = db_connect;
   my $sql    = "SELECT db_control FROM entries WHERE db_srv = \'$server\'";
   $logger->trace("$ll  sql: $sql");
   my $sth = $dbh->prepare($sql) or die $dbh->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid = $sth->rows;

   if ( $lastid > 1 ) {
      $logger->error("$ll  find more than one server entry - do not know which one I must use - abort");
      $rc = 99;
   } elsif ( $lastid == 1 ) {
      my @control = $sth->fetchrow_array;
      $logger->trace("$ll Control (pool, vc, model): $control[0]");
      $rettyp = $control[ 0 ];
   } else {
      $logger->error("$ll  server $server not found in db - abort");
   }
   $sth->finish();
   $rc = db_disconnect($dbh);
   $logger->trace("$ll func end: [$fc] - rc=$rc");
   $flvl--;
   $logger->level($llback);
   return $rettyp;
} ## end sub db_get_control


sub db_addconfigs {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc      = 0;
   my $db      = shift();
   my $counter = 0;
   $logger->trace("$ll   load db");
   my $sql = 'select id, db_srv,db_typ, mgmt_ip, db_mac, db_control, db_controltyp from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   
   my @files = < $global{'pxedir'} >;
   foreach my $file (@files) {
      $logger->trace("$ll  Dir found: $file");
      my ( $volume, $dirs, $macdir ) = File::Spec->splitpath($file);
      $logger->trace("$ll  MAC found: $macdir");
      if ( $macdir =~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i ) {
         my $mac = Net::MAC->new( 'mac' => $macdir, 'die' => 0 );
         my $base = $mac->get_base();
         if ( $base == 16 ) {
            my $nmac = $mac->convert(
                                      'base'      => 16,                                                                           # convert from base 16 to base 10
                                      'bit_group' => 8,                                                                            # octet grouping
                                      'delimiter' => ':'                                                                           # dot-delimited
                                      );
            $logger->trace("$ll  MAC: $nmac ");
            my $nsrv        = "none";                                                                                              # nsrv = hostname
            my $ntyp        = " - ";                                                                                               # ntyp = server type, e.g. xen650
            my $nip         = " - ";                                                                                               # nip = server mgmt ip
            my $ncontrol    = " - ";                                                                                               # ncontrol = poolname, vcname, linux model name
            my $ncontroltyp = "";                                                                                                  # ncontroltyp = xp,vc,srv
            my $j_inst      = "";
            my $addit       = 0;

            my $nmgmtuser = "root";
            my $nmgmtpwc  = 0;
            my $nmgmtpw   = "none";
            my $nrctype   = "none";
            my $nrcicon   = "none";
            my $nrcdesc   = "no remote control configure";
            my $nrchttp   = "";
            my $nrcssh    = "";
            my $nsrvtype  = "none";
            my $nsrvcmd   = 'ssh://<% entries.$id.mgmt_ip %>';

            opendir DIR, "$global{'pxesysdir'}/$mac/";
            my @pxefiles = grep { $_ =~ m/.pxe$/ } readdir DIR;
            closedir DIR;
            $logger->trace("$ll  found config file: $files[0]");
            my ($filename) = $pxefiles[ 0 ] =~ /(.*)?\./;
            $logger->trace("$ll  filename: $filename");

            my %srvcfg_h  = ();
            my $rccfgfile = "";

            if ( $filename =~ m/^ks-esxi/ ) {
               $logger->debug("$ll  found esxi config");
               my $esxicfg = "$global{'pxesysdir'}/$mac/$filename.cfg";
               $ntyp = gettaginfile( "/inst/",      "/ks", $esxicfg );
               $nsrv = gettaginfile( "--hostname=", "",    $esxicfg );
               $logger->debug("$ll => srv: $nsrv \t typ: esxi");
               $nip = gettaginfile( "--ip=", "--netmask", $esxicfg );
               my $vc = gettaginfile( "\#vc:", "", $esxicfg );
               unless ($vc) {
                  $ncontrol = "stand-alone";
               } else {
                  $ncontrol = "$vc";
               }
               $ncontroltyp = "vc";
               if ( "$nip" eq "" ) {
                  $logger->warn("$ll  no ip found - cannot add server");
               } else {
                  $addit = 1;
               }
            } elsif ( $filename =~ m/^xen/ ) {
               $logger->debug("$ll  found xen config");
               my $xenxmlcfg  = "$global{'pxesysdir'}/$mac/$filename.xml";
               my $xenconfcfg = "$global{'pxesysdir'}/$mac/$filename.conf";
               my $xenextcfg  = "$global{'pxesysdir'}/$mac/$filename.ext";
               $nsrv = gettaginfile( "hostname>", "<\/hostname", $xenxmlcfg );
               $logger->debug("$ll => srv: $nsrv \t typ: xenserver");
               $ntyp = gettaginfile( "/inst/", "/ks/create-customize.sh", $xenxmlcfg );
               $nip = gettaginfile( "ip>", "<\/ip", $xenxmlcfg );
               my $pool = gettaginfile( "pool=", "", $xenconfcfg );
               $pool =~ s/#.*//;                                                                                                   # no comments
               $pool =~ s/^\s+//;                                                                                                  # no leading white
               $pool =~ s/\s+$//;                                                                                                  # no trailing white
               $pool =~ s/^'//;
               $pool =~ s/'$//;
               $pool =~ s/^"//;
               $pool =~ s/"$//;

               unless ($pool) {
                  $ncontrol = "stand-alone";
               } else {
                  $ncontrol = "$pool";
               }
               $ncontroltyp = "xp";
               if ( "$nip" eq "" ) {
                  $logger->warn("$ll  no ip found - cannot add server");
               } else {
                  $addit = 1;
               }
            } elsif ( $filename =~ m/^co/ ) {
               $logger->debug("$ll  found centos config");
               my $cocfg = "$global{'pxesysdir'}/$mac/$filename.cfg";
               $logger->trace("$ll  cfg: $cocfg");
               my $copxe = "$global{'pxesysdir'}/$mac/$filename.pxe";
               $logger->trace("$ll  pxe: $copxe");
               $nsrv = gettaginfile( "--hostname", "--onboot",  $cocfg );
               $ntyp = gettaginfile( "img/",       "/vmlinuz",  $copxe );
               $nip  = gettaginfile( "--ip",       "--netmask", $cocfg );
               my $co_model = gettaginfile( "\#model:", "", $cocfg );

               if ( "$co_model" eq "" ) {
                  $ncontrol = "base";
               } else {
                  $ncontrol = $co_model;
               }
               $ncontroltyp = "lx";
               if ( "$nip" eq "" ) {
                  $logger->warn("$ll  no ip found - cannot add server");
               } else {
                  $addit = 1;
               }
            } elsif ( $filename =~ m/^rh/ ) {
               $logger->debug("$ll  found redhat config");
               my $rhcfg = "$global{'pxesysdir'}/$mac/$filename.cfg";
               $logger->trace("$ll  cfg: $rhcfg");
               my $rhpxe = "$global{'pxesysdir'}/$mac/$filename.pxe";
               $logger->trace("$ll  pxe: $rhpxe");
               $nsrv = gettaginfile( "--hostname", "--onboot",  $rhcfg );
               $ntyp = gettaginfile( "img/",       "/vmlinuz",  $rhpxe );
               $nip  = gettaginfile( "--ip",       "--netmask", $rhcfg );
               my $rh_model = gettaginfile( "\#model:", "", $rhcfg );

               if ( "$rh_model" eq "" ) {
                  $ncontrol = "base";
               } else {
                  $ncontrol = $rh_model;
               }
               $ncontroltyp = "lx";
               if ( "$nip" eq "" ) {
                  $logger->warn("$ll  no ip found - cannot add server");
               } else {
                  $addit = 1;
               }
            } else {
               $logger->debug("$ll  unknown config typ: [$files[0]");
            }
            if ($addit) {
               $logger->trace("$ll search if server is in db ...");
               my $sqlsearch = 'select id, db_srv, db_mac from entries order by id desc';
               my $sth = $db->prepare($sqlsearch) or die $db->errstr;
               $sth->execute or die $sth->errstr;
               my $lastid = $sth->rows;
               $logger->trace("$ll  get $lastid records");
               my $serverhash = $sth->fetchall_hashref('id');
               my $addid      = 1;

               for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
                  if ( "$serverhash->{$srvid}{'db_srv'}" eq "$nsrv" ) {
                     $logger->debug("$ll -> [$nsrv] already exist");
                     $addid = 0;
                  } elsif ( "$serverhash->{$srvid}{'db_srv'}" eq "$nmac" ) {
                     $logger->debug("$ll -> [$nmac] already exist");
                     $addid = 0;
                  }
               } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )

               # $server=$serverhash->{$srvid}{'db_srv'}; # auslesen hash eintrag aus hash referenz
               if ($addid) {
                  $logger->trace("$ll  search for remote control configs");
                  $rccfgfile = "$global{'rcsysdir'}/$mac/rc.ini";
                  if ( -f $rccfgfile ) {
                     $logger->trace("$ll  read rc.ini $rccfgfile] now ...");
                     $retc = read_config( $rccfgfile, \%srvcfg_h );
                     unless ($retc) {
                        if ( defined $srvcfg_h{'mgmt_pw'} ) {
                           if ( defined $srvcfg_h{'mgmt_pwc'} ) {
                              $nmgmtpwc = $srvcfg_h{'mgmt_pwc'};
                              $nmgmtpw  = $srvcfg_h{'mgmt_pw'};
                           }
                        } ## end if ( defined $srvcfg_h{'mgmt_pw'} )
                        if ( defined $srvcfg_h{'mgmt_user'} ) {
                           $nmgmtuser = $srvcfg_h{'mgmt_user'};
                        }

                        if ( defined $srvcfg_h{'rc_type'} ) {
                           if ( "$srvcfg_h{'rc_type'}" eq "none" ) {
                              $logger->info("$ll no remote control type found - ignore all other rc settings");
                              $nrctype = "none";
                              $nrcicon = "none.png";
                              $nrcdesc = "No remote control supported";
                           } else {
                              $nrctype = $srvcfg_h{'rc_type'};
                              if ( defined $srvcfg_h{'rc_icon'} ) {
                                 $nrcicon = $srvcfg_h{'rc_icon'};
                              }
                              if ( defined $srvcfg_h{'rc_desc'} ) {
                                 $nrcdesc = $srvcfg_h{'rc_desc'};
                              }
                              if ( defined $srvcfg_h{'rc_http'} ) {
                                 $nrchttp = $srvcfg_h{'rc_http'};
                              }
                              if ( defined $srvcfg_h{'rc_ssh'} ) {
                                 $nrcssh = $srvcfg_h{'rc_ssh'};
                              }
                              if ( defined $srvcfg_h{'srv_type'} ) {
                                 $nsrvtype = $srvcfg_h{'srv_type'};
                              }
                              if ( defined $srvcfg_h{'srv_cmd'} ) {
                                 $nsrvcmd = $srvcfg_h{'srv_cmd'};
                              }
                           } ## end else [ if ( "$srvcfg_h{'rc_type'}" eq "none" ) ]
                        } ## end if ( defined $srvcfg_h{'rc_type'} )
                     } else {
                        $logger->warn("$ls ==> cannot read rc.ini - ignore");
                     }
                  } else {
                     $logger->warn("$ll  cannot find remote control config file - no rc and os support");
                     $nrctype = "unavailable";
                     $nrcicon = "unavail.png";
                     $nrcdesc = "Sorry - fsi cannot find a rc.ini for this server";
                  } ## end else [ if ( -f $rccfgfile ) ]

                  unless ($retc) {
                     $logger->info("$ll  add server $nsrv now ...");
                     $lastid++;
                     $j_inst = sym_exist($mac);

                     my $sqladd = 'insert into entries (id, db_srv, db_typ, db_mac, db_control, db_controltyp, mgmt_ip, mgmt_user, mgmt_pwc, mgmt_pw, rc_type, rc_icon, rc_desc, rc_http, rc_ssh, srv_type, srv_cmd, j_inst ) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)';
                     my $sthadd = $db->prepare($sqladd) or die $db->errstr;
                     $sthadd->execute( $lastid, $nsrv, $ntyp, $nmac, $ncontrol, $ncontroltyp, $nip, $nmgmtuser, $nmgmtpwc, $nmgmtpw, $nrctype, $nrcicon, $nrcdesc, $nrchttp, $nrcssh, $nsrvtype, $nsrvcmd, $j_inst );
                     my $fehler = $sthadd->errstr;
                     if ($fehler) {
                        if ( $fehler eq "Unique-Constraint 'entries_pkey'" ) {
                           $logger->error("ID doppelt");
                           $rc = 99;
                        } elsif ( $fehler eq "Unique-Constraint 'entries_db_mac_key'" ) {
                           $logger->error("MAC Adresse ist schon mal vergeben");
                           $rc = 99;
                        } else {
                           $logger->error("DB Meldung: $fehler");
                           $rc = 99;
                        }
                        last;
                     } ## end if ($fehler)
                  } ## end unless ($retc)
               } else {
                  $logger->trace("$ll  -> not add");
               }
            } ## end if ($addit)
         } else {
            $logger->error("something wrong with the mac name of the config dir $macdir");
            last;
         }
      } else {
         $logger->trace("$ll  macdir: [$macdir] no server config dir");
      }
   } ## end foreach my $file (@files)
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub db_addconfigs

sub db_update {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;
   my $db = shift();
   unless ($rc) {
      $rc = db_addconfigs($db);
   }
   unless ($rc) {
      $rc = set_poolcounter($db);
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub db_update


sub db_create {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $dbh    = shift();
   my $schema = read_file( $global{'dbschema'} );
   $dbh->do($schema) or $rc = 99;

   if ($retc) {
      $global{'errmsg'} = $dbh->errstr;
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub db_create


sub db_drop {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc         = 0;
   my $table_name = shift();
   my $dbh        = shift();
   $logger->trace("$ll table to drop: [$table_name]");
   my $quoted_name = $dbh->quote_identifier($table_name);
   $logger->trace("$ll prepare command");
   $dbh->do("DROP TABLE IF EXISTS $quoted_name") or $rc = 99;
   $logger->trace("$ll rc=$rc");

   unless ($rc) {
      $logger->info("$ll drop table $table_name successful");
   } else {
      $global{'errmsg'} = "$DBI::errstr";
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub db_drop

sub db_new {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;
   my $db = shift();
   unless ($rc) {
      $rc = db_drop( $global{'dbt_ov'}, $db );
   }
   unless ($rc) {
      $rc = db_drop( $global{'dbt_stat'}, $db );
   }
   unless ($rc) {
      $rc = db_drop( $global{'dbt_worker'}, $db );
   }
   unless ($rc) {
      $rc = db_drop( $global{'dbt_daemon'}, $db );
   }
   unless ($rc) {
      $rc = db_create($db);
   }
   unless ($rc) {
      $rc = db_addconfigs($db);
   }
   unless ($rc) {
      $rc = sort_srvid($db);
   }
   unless ($rc) {
      $rc = set_poolcounter($db);
   }
   unless ($rc) {
      $rc = check_log($db);
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub db_new


return 1;
