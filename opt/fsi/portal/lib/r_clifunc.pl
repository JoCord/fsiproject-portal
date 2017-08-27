sub set_poolcounter {
   my $fc     = ( caller(0) )[ 3 ];
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my %pools;
   my $db    = shift();
   my @files = < $global{'pxedir'} >;

   foreach my $file (@files) {
      my ( $volume, $dirs, $macdir ) = File::Spec->splitpath($file);

      # $logger->trace("$ll  MAC found: $macdir");
      if ( $macdir =~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i ) {
         my $xenconfcfg = "";
         if ( -f "$file/xen6.conf" ) {
            $logger->trace("$ll  xenserver 6 Config dir found: $file");
            $xenconfcfg = "$file/xen6.conf";
         } elsif ( -f "$file/xen7.conf" ) {
            $logger->trace("$ll  xenserver 7 Config dir found: $file");
            $xenconfcfg = "$file/xen7.conf";
         }
            
         if ( "$xenconfcfg" ne "" ) {
            $logger->trace("$ll  found xenserver config");
            my $pool = gettaginfile( "pool=", "", $xenconfcfg );
            $pool =~ s/#.*//;                                                                                                      # no comments
            $pool =~ s/^\s+//;                                                                                                     # no leading white
            $pool =~ s/\s+$//;                                                                                                     # no trailing white
            $pool =~ s/^'//;
            $pool =~ s/'$//;
            $pool =~ s/^"//;
            $pool =~ s/"$//;
            $logger->debug("$ll  XenPool: $pool");

            if ( defined $pools{$pool} ) {
               $pools{$pool}++;
               $logger->trace("$ll   $pool already exist - add one [$pools{$pool}]");
            } else {
               $logger->trace("$ll   $pool is new - set to 1");
               $pools{$pool} = 1;
            }
         } ## end if ( -f "$xenconfcfg" )
      } ## end if ( $macdir =~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i )
   } ## end foreach my $file (@files)
   $logger->debug("$ll   add xen pools counter to db");
   $logger->trace("$ll   load db");
   my $sql = 'select id, db_srv, db_control, db_controltyp, db_typ, x_poolcount from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');
   $logger->trace("$ll  get $lastid records");

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ ) {
         $logger->trace("$ll  found xen pool server: [$serverhash->{$srvid}{'db_srv'}]  ");
         foreach my $poolname ( keys %pools ) {
            if ( "$serverhash->{$srvid}{'db_control'}" eq "$poolname" ) {
               $logger->trace("$ll  set pool count for $poolname");
               my $updatecmd = "UPDATE entries SET x_poolcount = '$pools{$poolname}' WHERE id = '$srvid' ";
               my $updsth = $db->prepare($updatecmd) or die $db->errstr;
               $logger->trace("$ll  $updatecmd");
               $updsth->execute();
               my $fehler = $sth->errstr;
               if ($fehler) {
                  $logger->error("DB Meldung: $fehler");
               } else {
                  $updsth->finish();
               }
            } ## end if ( "$serverhash->{$srvid}{'db_control'}" eq "$poolname" )
         } ## end foreach my $poolname ( keys %pools )
      } ## end if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ )
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   $logger->trace("$ll func end: [$fc] - rc = $retc");
   $logger->level($llback);
   $flvl--;
   return $retc;
} ## end sub set_poolcounter

sub getparm {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;

#   $logger->trace("$ll func start: [$fc]");
   my $retc    = 0;
   my $left    = shift();
   my $right   = shift();
   my $line    = shift();
   my $orgline = $line;

#   $logger->trace("$ll  left : $left");
#   $logger->trace("$ll  right: $right");
#   $logger->trace("$ll  line: $orgline");
   $line =~ s/.*$left(.*)$right.*/$1/sg;
   if ( $orgline eq $line ) {
      $line = "";
   }
   $line =~ s/^\s+//;
   $line =~ s/\s+$//;
   $line =~ s/\n//;

#   $logger->trace("$ll func end: [$fc] - rc = $line");
   $flvl--;
   return $line;
} ## end sub getparm

sub gettaginfile {
   my $fc     = ( caller(0) )[ 3 ];
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $tag1 = shift();
   my $tag2 = shift();
   my $file = shift();

#   $logger->trace("$ll  front tag: $tag1");
#   $logger->trace("$ll  behind tag: $tag2");
#   $logger->trace("$ll  file: $file");
   my $name;
   my $retname = "";
   if ( -e $file ) {
      open( MYFILE, $file ) or $retc = 99;
      unless ($retc) {
         while (<MYFILE>) {
            chomp;
            $name = getparm( $tag1, $tag2, $_ );

#            $logger->trace("$ll  line: $_");
            if ($name) {
               $retname = $name;

               # $logger->trace("$ll  get [$retname] for [$tag1][$tag2]");
               last;
            } ## end if ($name)
         } ## end while (<MYFILE>)
         close(MYFILE);
      } else {
         $logger->error("cannot open file $file - error: $!");
         $retc = 99;
      }
   } else {
      $logger->error("cannot find file $file");
      $retc = 99;
   }
   if ($retname) {
      $logger->trace("$ll  found: [$retname]");
   } else {
      $logger->warn("$ll  cannot find something between [$tag1] and [$tag2]");
   }
   if ($retc) {
      $logger->error("cannot detect string between [$tag1] and [$tag2]");
      $retname = "";
   }
   $logger->trace("$ll func end: [$fc]");
   $logger->level($llback);
   $flvl--;
   return $retname;
} ## end sub gettaginfile

sub sort_srvid {
   my $fc     = ( caller(0) )[ 3 ];
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc  = 0;
   my $dbh = shift();
   $logger->trace("$ll  sort server id");

   unless ($rc) {
      my $sql = 'select db_srv from entries order by db_srv desc';
      my $sth = $dbh->prepare($sql) or die $db->errstr;
      $sth->execute or die $sth->errstr;
      my $count = 10000;
      while ( my @row = $sth->fetchrow_array ) {
         my $updatecmd = "UPDATE entries SET id = $count WHERE db_srv = '$row[0]' ";
         my $updsth = $dbh->prepare($updatecmd) or die $db->errstr;
         $logger->trace("$ll  $updatecmd");
         $updsth->execute();
         my $fehler = $sth->errstr;
         if ($fehler) {
            $logger->error("DB Meldung: $fehler");
            $rc = 99;
         } else {
            $updsth->finish();
            $count++;
         }
      } ## end while ( my @row = $sth->fetchrow_array )
   } ## end unless ($rc)
   unless ($rc) {
      my $sql = "SELECT db_srv FROM entries ORDER BY db_srv DESC";
      my $sth = $dbh->prepare($sql) or die $db->errstr;
      $sth->execute or die $sth->errstr;
      my $count = 1;
      while ( my @row = $sth->fetchrow_array ) {
         my $updatecmd = "UPDATE entries SET id = $count WHERE db_srv = '$row[0]' ";
         my $updsth = $dbh->prepare($updatecmd) or die $db->errstr;
         $logger->trace("$ll  $updatecmd");
         $updsth->execute();
         my $fehler = $sth->errstr;
         if ($fehler) {
            $logger->error("DB Meldung: $fehler");
            $rc = 99;
         } else {
            $updsth->finish();
            $count++;
         }
      } ## end while ( my @row = $sth->fetchrow_array )
   } ## end unless ($rc)
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub sort_srvid

sub del_srv {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $server = shift();
   my $dbh    = shift();
   $logger->debug("$ll  delete $server from db");
   my $sql = "SELECT id FROM entries WHERE db_srv = \'$server\'";
   $logger->trace("$ll  sql: $sql");
   my $sth = $dbh->prepare($sql) or die $dbh->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid = $sth->rows;

   if ( $lastid > 1 ) {
      $logger->error("find more than one server entry - don´t know which one I must delete - abort");
      $rc = 99;
   } elsif ( $lastid == 1 ) {
      my $serverhash = $sth->fetchall_hashref('id');
      foreach my $id ( keys %{$serverhash} ) {
         $logger->trace("$ll  delete server id: $id");
         $retc = del_srvid( $id, $dbh );
      }
   } else {
      $logger->info("$ll  server $server not found in db - abort");
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub del_srv

sub del_srvid {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc    = 0;
   my $srvid = shift();
   my $dbh   = shift();
   $logger->trace("$ll  delete server with id : [$srvid]");
   my $quoted_name = $dbh->quote_identifier( $global{'dbt_ov'} );
   my $quoted_id   = $dbh->quote_identifier($srvid);
   my $updatecmd   = "DELETE FROM $quoted_name WHERE id = $srvid ";

#   my $updatecmd   = "DELETE FROM $quoted_name WHERE id = $quoted_id ";
   my $updsth = $dbh->prepare($updatecmd) or die $dbh->errstr;
   $logger->trace("$ll  $updatecmd");
   $updsth->execute();
   my $fehler = $updsth->errstr;
   if ($fehler) {
      $logger->error("DB Meldung: $fehler");
      $retc = 88;
   } else {
      $logger->debug("$ll  ok");
      $updsth->finish();
   }
   unless ($rc) {
      $logger->debug("$ll  sort id new, so no holes exist");
      $rc = sort_srvid($dbh);
   }
   unless ($rc) {
      $logger->debug("$ll  set xen pool counter new - if xen server deleted");
      $retc = set_poolcounter($dbh);
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub del_srvid

sub show_server {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $db     = shift();
   my $server = shift();
   $logger->trace("$ll   server: $server");

   if ( "$server" eq "all" ) {
      $logger->trace("$ll   load db");
      my $sql = 'select id, db_srv,db_typ, mgmt_ip, db_mac, db_control, db_controltyp, rc_type from entries order by id desc';
      my $sth = $db->prepare($sql) or die $db->errstr;
      $sth->execute or die $sth->errstr;
      my $lastid     = $sth->rows;
      my $serverhash = $sth->fetchall_hashref('id');
      $logger->trace("$ll   get $lastid records");
      printf " %-5s %-30s %-19s %-15s %-15s %-40s \n", "ID", "Servername", "MAC", "RC", "Mgmt IP", "Control";

      for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
         printf " %-5s %-30s %-19s %-15s %-15s %-2s : %-40s \n", $srvid, $serverhash->{$srvid}{'db_srv'}, $serverhash->{$srvid}{'db_mac'}, $serverhash->{$srvid}{'rc_type'}, $serverhash->{$srvid}{'mgmt_ip'}, $serverhash->{$srvid}{'db_controltyp'}, $serverhash->{$srvid}{'db_control'};
      }
   } else {
      $logger->debug("$ll   show info for $server");
   }

#   use Data::Dumper;
#   print Dumper(\%$sthash);
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub show_server

sub cmdget {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc    = 0;
   my $command = shift();
   $logger->trace("$ll  cmd: [$command]");
   my $eo = qx($command  2>&1);
   $retc = $?;
   $retc = $retc >> 8 unless ( $retc == -1 );

   unless ($retc) {
      $logger->trace("$ll  ok");
      $eo =~ s/^\s+//;
      $eo =~ s/\s+$//;
      $eo =~ s/\n//;
      if ( $eo ne "" ) {
         $logger->trace("$ll  [$eo]");
      } else {
         $logger->warn("$ll  empty return");
      }
   } else {
      $logger->error("failed cmd [$eo]");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($eo);
} ## end sub cmdget

sub cmd_remote {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc    = "";
   my $srvip = shift();
   my $pw    = shift();
   my $cmd   = shift();
   my $p     = Net::Ping->new( $global{'pingprot'} );
   if ( $p->ping($srvip) ) {
      $logger->trace("$ll ip $srvip connected");
      $rc = cmdget("sshpass -p $pw ssh -o StrictHostKeyChecking=no $srvip $cmd");
      $rc =~ s/.*\n//g;
      $rc =~ s/^\s+//;
      $rc =~ s/\s+$//;
      $rc =~ s/\n//;
      $logger->trace("$ll  rc=$rc");
   } else {
      $logger->error("cannot connect $srvip - offline");
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub cmd_remote

sub get_pw {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = "";
   my $db_mac = shift();
   my $db_typ = shift();
   my $mac    = Net::MAC->new( 'mac' => $db_mac, 'die' => 0 );
   my $nmac   = $mac->convert( 'base' => 16, 'bit_group' => 8, 'delimiter' => '-' );
   $logger->trace("$ll  mac: $nmac");

   if ( $db_typ =~ m/^xen/ ) {
      my $xmlconf = "";
      if ( -f "$global{'pxesysdir'}/$nmac/xen6.xml" ) {
         $logger->trace("$ll  xenserver 6");
         $xmlconf = "$global{'pxesysdir'}/$nmac/xen6.xml";
      } elsif ( -f "$global{'pxesysdir'}/$nmac/xen7.xml" ) {
         $logger->trace("$ll  xenserver 7");
         $xmlconf = "$global{'pxesysdir'}/$nmac/xen7.xml";
      }

      if ( "$xmlconf" ne "" ) {
         $logger->debug("$ll  get xenserver password");
         $logger->trace("$ll config file: $xmlconf");
         $rc = gettaginfile( "<root-password>", "</root-password>", $xmlconf );
      } else {
         $logger->error("cannot find xenserver config file");
      }
   } elsif ( $db_typ =~ m/^esxi/ ) {
      $logger->debug("$ll  standard esxi password");
      my $ksconf = "$global{'pxesysdir'}/$nmac/ks-$db_typ.cfg";
      if ( -e $ksconf ) {
         $rc = gettaginfile( "#cpw: ", "", $ksconf );
      } else {
         $logger->error("cannot find esxi ks config file : [$ksconf]");
      }
   } elsif ( $db_typ =~ m/^co/ ) {
      $logger->debug("$ll  CentOS Password");
   } elsif ( $db_typ =~ m/^rh/ ) {
      $logger->debug("$ll  RedHat Password");
   } else {
      $logger->error("unknown server typ - cannot get pw");
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub get_pw

sub set_pm_cfg {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc    = 0;
   my $pool  = shift();
   my $mpool = shift();
   ##### pool master setzen
   ### file change
   ### pool.apply ?
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub set_pm_cfg

sub check_iallend {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;
   my $db = shift();
   $logger->info("$ll  test if all server installation finished ?");
   $logger->trace("$ll   load db");
   my $sql = 'select id, db_srv,db_typ from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      my $db_srv = $serverhash->{$srvid}{'db_srv'};
      unless ( check_instend( $db_srv, $db ) ) {
         $logger->info("$ll   server [$db_srv] is still in installation mode or error");
      } else {
         $logger->info("$ll   server [$db_srv] installation is finish");
      }
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_iallend

sub check_all {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $db   = shift();
   $retc = check_master($db);

   # unless ($retc) { $retc = check_on($db); }
   unless ($retc) { $retc = check_iallend($db); }
   unless ($retc) { $retc = check_syms($db); }
   unless ($retc) { $retc = set_poolcounter($db); }
   unless ($retc) { $retc = check_log($db); }
   unless ($retc) { $retc = check_patch_all($db); }
   unless ($retc) { $retc = check_ha_pool_all($db); }
   unless ($retc) { $retc = check_poolrun_dir($db); }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub check_all

sub check_poolrun_dir {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;
   my $db = shift();
   my @poolchecked;
   $logger->trace("$ll  load db");
   my $sql = "select id, db_srv, db_typ, db_mac, db_control, db_controltyp, s_xenha FROM entries ORDER BY id desc";
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ ) {
         my $pool = $serverhash->{$srvid}{'db_control'};

         # $logger->trace("$ll  found xen pool: [$pool]");
         unless ( grep { /$pool/ } @poolchecked ) {

            # $logger->trace("$ll   delete flag for $pool");
            $rc = del_flag_dbcontrol( $db, "s_instrun", $pool );
            unless ($rc) {

               # $logger->trace("$ll  check pool.run dir");
               my $pooldir = "$global{'fsiinstdir'}/$serverhash->{$srvid}{'db_typ'}/ks/pool/$pool/pool.run";

               # $logger->trace("$ll  dir: $pooldir");
               if ( -d $pooldir ) {
                  $logger->trace("$ll  pool run exist");
                  my $xenfile = $pooldir . "/xenserver";
                  $logger->trace("$ll  file: $xenfile");
                  if ( -f $xenfile ) {
                     $logger->trace("$ll  xenserver file exist");
                     open( my $file, $xenfile );
                     my $xensrv = <$file>;
                     close($file);
                     $rc = set_flag( $db, "s_instrun", $xensrv, "R" );
                  } ## end if ( -f $xenfile )
               } ## end if ( -d $pooldir )
            } ## end unless ($rc)
            unless ($rc) {
               push( @poolchecked, $pool );
            }
         } ## end unless ( grep { /$pool/ } @poolchecked )
      } ## end if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ )
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_poolrun_dir

sub check_in_file {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc   = 0;
   my $file = shift();
   my $test = shift();
   if ( -e $file ) {
      $logger->debug("$ll   found server log");
      my $retc = open( my $in, $file );
      if ($retc) {
         $global{'errmsg'} = "Can't open file $file";
         $rc = 33;
         $logger->error( $global{'errmsg'} );
      } else {
         my @lines;
         while (<$in>) {
            next unless m/$test/;
            @lines = <$in>;
         }
         close($in);
         if (@lines) {
            $logger->trace("$ll   found $test in $file");
         } else {
            $global{'errmsg'} = "cannot find $test in $file";
            $logger->trace("$ll   $global{'errmsg'}");
            $rc = 1;
         }
      } ## end else [ if ($retc) ]
   } else {
      $global{'errmsg'} = "cannot find file $file";
      $logger->trace("$ll   $global{'errmsg'}");
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_in_file

sub check_instend {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $ended          = 0;                                                                                                         # not ended
   my $retc           = 0;
   my $server         = shift();
   my $db             = shift();
   my $flag_inststart = "none";
   my $flag_instrun   = "none";
   my $errflag        = 'none';
   my @command        = ( "$global{'toolsdir'}/chkinst", "-q", "-l", "$global{'logfile'}.log", "-s", "$server" );
   $logger->trace("$ll  cmd: [@command]");
   $retc = system(@command);
   $retc = $?;
   $retc = $retc >> 8 unless ( $retc == -1 );

   if ( $retc == 0 ) {
      $logger->debug("$ll  find start and end time without errors during install");
      $flag_inststart = '';
      $flag_instrun   = '';
      $errflag        = '';
      $ended          = 1;
   } elsif ( $retc == 1 ) {
      $logger->debug("$ll  find start time but no end time and no errors - install still running ?");
      $flag_inststart = '';
      $flag_instrun   = 'R';
      $errflag        = '';
   } elsif ( $retc == 2 ) {
      $logger->debug("$ll  find start time, no end but errors - install aborted ?");
      $flag_inststart = '';
      $flag_instrun   = 'R';
      $errflag        = 'E';
   } elsif ( $retc == 3 ) {
      $logger->debug("$ll  find start time and end time but errors during installation");
      $flag_inststart = '';
      $flag_instrun   = '';
      $errflag        = 'E';
      $ended          = 1;
   } elsif ( $retc == 4 ) {
      $logger->debug("$ll  find start time, no end time, no errors but waiting for xen pool inst opening");
      $flag_inststart = '';
      $flag_instrun   = 'W';
      $errflag        = '';
      $ended          = 1;
   } elsif ( $retc == 5 ) {
      $logger->debug("$ll  cannot find start time");
   } elsif ( $retc == 7 ) {
      $logger->debug("$ll  cannot find start time but errors - how does this come ?");
      $errflag = 'E';
   } elsif ( $retc == 10 ) {
      $logger->debug("$ll  no server $server found");
   } elsif ( $retc == 12 ) {
      $logger->debug("$ll  unsupported server typ");
   } elsif ( $retc == 13 ) {
      $logger->debug("$ll  no server log exist");
      $flag_inststart = '';
      $flag_instrun   = '';
      $errflag        = '';
      $errflag        = '';
      $retc           = 0;
   } else {
      $logger->error("error getting status of installation from $server");
   }
   if ( "$flag_inststart" ne "none" ) {
      my $db        = db_connect();
      my $updatecmd = "UPDATE entries SET s_inststart = \'$flag_inststart\' WHERE db_srv = '$server' ";
      my $updsth    = $db->prepare($updatecmd) or die $db->errstr;
      $logger->trace("$ll  $updatecmd");
      $updsth->execute();
      my $fehler = $updsth->errstr;
      if ($fehler) {
         $logger->error("DB Meldung: $fehler");
         $retc  = 99;
         $ended = 0;
      } else {
         $logger->trace("$ll   finish update inststart flag");
         $updsth->finish();
      }
      db_disconnect($db);
   } ## end if ( "$flag_inststart" ne "none" )
   if ( "$flag_instrun" ne "none" ) {
      my $db        = db_connect();
      my $updatecmd = "UPDATE entries SET s_instrun = \'$flag_instrun\' WHERE db_srv = '$server' ";
      my $updsth    = $db->prepare($updatecmd) or die $db->errstr;
      $logger->trace("$ll  $updatecmd");
      $updsth->execute();
      my $fehler = $updsth->errstr;
      if ($fehler) {
         $logger->error("DB Meldung: $fehler");
         $retc  = 99;
         $ended = 0;
      } else {
         $logger->trace("$ll   finish update instrun flag");
         $updsth->finish();
      }
      db_disconnect($db);
   } ## end if ( "$flag_instrun" ne "none" )
   if ( $errflag ne "none" ) {
      my $db        = db_connect();
      my $updatecmd = "UPDATE entries SET s_insterr = \'$errflag\' WHERE db_srv = '$server' ";
      my $updsth    = $db->prepare($updatecmd) or die $db->errstr;
      $logger->trace("$ll  $updatecmd");
      $updsth->execute();
      my $fehler = $updsth->errstr;
      if ($fehler) {
         $logger->error("DB Meldung: $fehler");
         $retc  = 99;
         $ended = 0;
      } else {
         $logger->trace("$ll   finish update");
         $updsth->finish();
      }
      db_disconnect($db);
   } ## end if ( $errflag ne "none" )
   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $ended;
} ## end sub check_instend

sub check_master {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc        = 0;
   my $db        = shift();
   my $ignoresrv = 0;
   my @poolchecked;
   $logger->trace("$ll  load db");
   my $sql = 'select id, db_srv, db_typ, db_mac, mgmt_ip, db_control, db_controltyp, s_xenmaster from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ ) {
         my $found = 1;
         my $pool  = $serverhash->{$srvid}{'db_control'};
         $logger->debug("$ll  found xen pool: [$pool]");
         unless ( grep { /$pool/ } @poolchecked ) {
            $rc = check_master_pool( $db, $pool );
            push( @poolchecked, $pool );
         } else {
            $logger->trace("$ll   $pool still checked on this run for master - ignore");
         }
      } else {
         $logger->trace("$ll  only XenServer needs Masterflag");
      }
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_master

sub del_pool_cfg_dir {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc      = 0;
   my $db      = shift();
   my $delpool = shift();
   my $found   = 0;
   $logger->trace("$ll  pool: $delpool");
   $logger->trace("$ll  load db");
   my $sql = 'select id, db_srv, db_typ, db_mac, mgmt_ip, db_control, db_controltyp, s_xenmaster from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      my $db_typ = $serverhash->{$srvid}{'db_typ'};
      if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ ) {
         my $pool = $serverhash->{$srvid}{'db_control'};
         $logger->trace("$ll  found xen pool: [$pool]");
         if ( "$delpool" eq "$pool" ) {
            $found = 1;
            $logger->info("$ll  found pool - detect xen type");
            my $rubbishdir = "$global{'progdir'}/../rubbish";
            local $File::Copy::Recursive::RMTrgDir = 2;
            my $orig = "$global{'fsiinstdir'}/$db_typ/ks/pool/$delpool";
            my $dest = "$global{'progdir'}../rubbish/$delpool" . "-" . TimeStamp(13);
            if ( -d $orig ) {
               $logger->debug("$ll  move: $orig -> $dest");
               my $movret = dirmove( $orig, $dest );
               unless ($movret) {
                  my $errmsg = $!;
                  $logger->error("err moving pool config dir to rubbish");
                  $logger->error("$errmsg");
                  $rc = 99;
               } else {
                  $logger->info("$ll  pool config dir moved to rubbish");
               }
            } else {
               $logger->error("Dir $orig does not exist");
               $rc = 6;
            }
            $logger->trace("$ll  end searching pool");
            last;
         } ## end if ( "$delpool" eq "$pool" )
      } else {
         $logger->debug("$ll  only XenServer can delete pool config dir");
      }
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   unless ($found) {
      $logger->error("cannot find pool $delpool in db");
      $rc = 99;
   }
   $logger->trace("$ll func end: [$fc] - rc=$rc");
   $flvl--;
   return $rc;
} ## end sub del_pool_cfg_dir

sub del_pool_run_dir {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc      = 0;
   my $db      = shift();
   my $delpool = shift();
   my $found   = 0;
   $logger->trace("$ll  pool: $delpool");
   $logger->trace("$ll  load db");
   my $sql = 'select id, db_srv, db_typ, db_mac, mgmt_ip, db_control, db_controltyp, s_xenmaster from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      my $db_typ = $serverhash->{$srvid}{'db_typ'};

      if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ ) {
         my $pool = $serverhash->{$srvid}{'db_control'};
         $logger->trace("$ll  found xen pool: [$pool]");
         if ( "$delpool" eq "$pool" ) {
            $found = 1;
            $logger->info("$ll  found pool - detect xen type");
            my $rubbishdir = "$global{'progdir'}/../rubbish";
            local $File::Copy::Recursive::RMTrgDir = 2;
            my $orig = "$global{'fsiinstdir'}/$db_typ/ks/pool/$delpool/pool.run";
            my $dest = "$global{'progdir'}../rubbish/$delpool" . "-poolrun-" . TimeStamp(13);
            if ( -d $orig ) {
               $logger->debug("$ll  move: $orig -> $dest");
               my $movret = dirmove( $orig, $dest );
               unless ($movret) {
                  my $errmsg = $!;
                  $logger->error("err moving pool run dir to rubbish");
                  $logger->error("$errmsg");
                  $rc = 99;
               } else {
                  $logger->info("$ll  pool run dir moved to rubbish");
               }
            } else {
               $logger->error("Dir $orig does not exist");
               $rc = 6;
            }
            $logger->trace("$ll  end searching pool");
            last;
         } ## end if ( "$delpool" eq "$pool" )
      } else {
         $logger->debug("$ll  only XenServer can delete pool config dir");
      }
      
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   unless ($found) {
      $logger->error("cannot find pool $delpool in db");
      $rc = 99;
   }
   $logger->trace("$ll func end: [$fc] - rc=$rc");
   $flvl--;
   return $rc;
} ## end sub del_pool_run_dir

sub check_master_pool {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc      = 0;
   my $db      = shift();
   my $chkpool = shift();
   $logger->trace("$ll  load db");
   my $sql = 'select id, db_srv, db_typ, db_mac, mgmt_ip, db_control, db_controltyp, s_xenmaster from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');
   $logger->trace("$ll  delete master flags on all pool server");

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ ) {
         my $pool = $serverhash->{$srvid}{'db_control'};
         if ( "$chkpool" eq "$pool" ) {
            $logger->trace("$ll   delete master flag on $serverhash->{$srvid}{'db_srv'} in pool [$pool]");
            $rc = del_flag_srv( $db, 's_xenmaster', $serverhash->{$srvid}{'db_srv'} );
            if ($rc) {
               $logger->error("deleting master flag on $serverhash->{$srvid}{'db_srv'}");
               last;
            }
         } ## end if ( "$chkpool" eq "$pool" )
      } ## end if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ )
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   unless ($rc) {
      my $poolmaster = get_master($chkpool);
      if ( "$poolmaster" ne "" ) {
         $logger->trace("$ll  found master [$poolmaster]");
         $logger->debug("$ll   found master $poolmaster for pool $chkpool");
         $logger->debug("$ll   update db with master flag for $chkpool at srv $poolmaster");
         my $updatecmd = "UPDATE entries SET s_xenmaster = 'M' WHERE db_srv = '$poolmaster' ";
         my $updsth = $db->prepare($updatecmd) or die $db->errstr;
         $logger->trace("$ll  $updatecmd");
         $updsth->execute();
         my $fehler = $sth->errstr;

         if ($fehler) {
            $logger->error("DB Meldung: $fehler");
            $rc = 99;
            last;
         } else {
            $updsth->finish();
         }
      } else {
         $logger->warn("$ll   failed find master in [$chkpool]- ignore pool");
      }
   } ## end unless ($rc)
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_master_pool

sub check_pool_exist {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc       = 0;
   my $poolexist= 0; 
   my $db       = shift();
   my $chkpool  = shift();

   $logger->trace("$ll  load db");
   my $sql = "select id, db_srv FROM entries WHERE ( db_control = '$chkpool' ) ORDER BY id DESC ";
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid = $sth->rows;
   $logger->trace("$ll  server found: $lastid");

   if ( $lastid > 1 ) {
      $poolexist=1;
   }

   $logger->trace("$ll func end: [$fc] - rc:$rc");
   $flvl--;
   return $poolexist;
} ## end sub check_ha_enable

sub check_ha_enable {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc       = 0;
   my $haenable = 0;
   my $db       = shift();
   my $chkpool  = shift();
   $logger->trace("$ll  load db");
   my $sql = "select id, db_srv, s_xenmaster FROM entries WHERE ( db_control = '$chkpool' AND s_xenmaster = 'M' ) ORDER BY id DESC ";
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid = $sth->rows;
   $logger->trace("$ll  server found: $lastid");

   if ( $lastid == 1 ) {
      my $serverhash = $sth->fetchall_hashref('id');
      my $srvid;
      foreach my $i ( keys %$serverhash ) {
         $srvid = $i;
      }
      $logger->info("$ll  Found master in pool: $serverhash->{$srvid}{'db_srv'} ");
      $logger->debug("$ll call chkha");
      my $command = "$global{'toolsdir'}/xenha -q -l $global{'logfile'}.log -c -s $serverhash->{$srvid}{'db_srv'} ";
      $logger->trace("$ll  cmd: [$command]");
      my $poolmaster = qx($command  2>&1);
      $rc = $?;
      $rc = $rc >> 8 unless ( $rc == -1 );
      $poolmaster =~ s/^\s+//;
      $poolmaster =~ s/\s+$//;
      $poolmaster =~ s/\n//;

      if ( $rc == 0 ) {
         $logger->info("$ll  pool ha on");
         $haenable = 1;
      } elsif ( $rc == 1 ) {
         $logger->info("$ll  pool ha off");
      } else {
         $logger->error("error getting status of ha in pool");                                                                     # ToDo: return error code
      }
   } elsif ( $lastid > 1 ) {
      $logger->warn("$ll  two master in pool $chkpool - abort");                                                                   # ToDo: return error code
   } else {
      $logger->warn("$ll  cannot find master in pool $chkpool");                                                                   # ToDo: return error code or run findmaster
   }
   $logger->trace("$ll func end: [$fc] - rc:$rc");
   $flvl--;
   return $haenable;
} ## end sub check_ha_enable

sub check_ha_pool_all {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;
   my $db = shift();
   my @poolchecked;
   $logger->trace("$ll  load db");
   my $sql = "select id, db_srv, db_typ, db_mac, db_control, db_controltyp, s_xenha FROM entries ORDER BY id desc";
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ ) {
         my $pool = $serverhash->{$srvid}{'db_control'};
         $logger->info("$ll  found xen pool: [$pool]");
         unless ( grep { /$pool/ } @poolchecked ) {
            $rc = del_flag_dbcontrol( $db, "s_xenha", $pool );
            unless ($rc) {
               $rc = check_ha_pool( $db, $pool );
               push( @poolchecked, $pool );
            }
         } ## end unless ( grep { /$pool/ } @poolchecked )
      } ## end if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ )
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   $logger->trace("$ll func end: [$fc] - rc:$rc");
   $flvl--;
   return $rc;
} ## end sub check_ha_pool_all


sub hafile {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $db     = shift();
   my $pool   = shift();
   my $what   = shift();
   my $db_typ = "";

   my $poolmaster = get_master($pool);
   unless ( -z $poolmaster ) {
      $logger->trace("$ll  master: $poolmaster");

      my $sql = "select id,db_typ from entries where db_srv = \'$poolmaster\'";
      $logger->trace("$ll  sql: $sql");
      my $sth = $db->prepare($sql) or die $db->errstr;
      $sth->execute or die $sth->errstr;
      my $lastid = $sth->rows;
      if ( $lastid > 1 ) {
         $logger->error("find more than one server entry - abort");
         $rc = 99;
      } elsif ( $lastid == 1 ) {
         $logger->trace("$ll  found 1 master server ");
         my $serverhash = $sth->fetchall_hashref('id');
         foreach my $srvid ( keys %{$serverhash} ) {
            $db_typ = $serverhash->{$srvid}{'db_typ'};
         }
      } ## end elsif ( $lastid == 1 )

      if ( $db_typ ne "" ) {
         $logger->trace("$ll pool xen version: $db_typ");
         my $pooldir = $global{'fsiinstdir'} . "/" . $db_typ . "/ks/pool/" . $pool;
         my $source;
         my $target;

         if ( $what eq "enable" ) {
            $target = $pooldir . "/pool.mhf";
            $source = $pooldir . "/pool.mhf_disabled";
         } elsif ( $what eq "disable" ) {
            $target = $pooldir . "/pool.mhf_disabled";
            $source = $pooldir . "/pool.mhf";
         }
         $logger->trace("$ll  source: $source");
         $logger->trace("$ll  target: $target");

         $logger->debug("$ll  check if source $source exist");
         if ( -e $source ) {
            my $movret = fmove( $source, $target );
            unless ($movret) {
               my $errmsg = $!;
               $logger->error("cannot rename $source to $target");
               $logger->error("$errmsg");
               $rc = 43;
            } else {
               $logger->info("$ll  pool ha file renamed to $target");
            }
         } else {
            $logger->warn("$ll cannot find source ha file");
            $logger->trace("$ll file [$source]");
            if ( -e $target ) {
               $logger->info("$ll pool ha target file already exist");
            } else {
               $logger->error("pool ha file $target also does not exist - abort");
               $rc = 45;
            }
         } ## end else [ if ( -e $source ) ]
      } else {
         $logger->error("cannot find xen typ for $pool");
         $rc = 66;
      }
   } else {
      $logger->error("cannot find master for pool [$pool]");
      $rc = 46;
   }

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub hafile

sub set_haon {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc   = 0;
   my $pool = shift();

   my $command = "$global{'toolsdir'}/xenha -q -l $global{'logfile'}.log -e -p $pool ";
   $logger->trace("$ll  cmd: [$command]");
   my $output = qx($command  2>&1);
   $rc = $?;
   $rc = $rc >> 8 unless ( $rc == -1 );
   unless ($rc) {
      $logger->trace("$ll  ha now enabled in pool [$pool]");
   } else {
      $logger->error("failed enabling ha in pool [$pool]");
   }

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub set_haon

sub set_haoff {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc   = 0;
   my $pool = shift();

   my $command = "$global{'toolsdir'}/xenha -q -l $global{'logfile'}.log -d -p $pool ";
   $logger->trace("$ll  cmd: [$command]");
   my $output = qx($command  2>&1);
   $rc = $?;
   $rc = $rc >> 8 unless ( $rc == -1 );
   unless ($rc) {
      $logger->trace("$ll  ha now disabeld in pool [$pool]");
   } else {
      $logger->error("cannot disable ha");
   }

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub set_haoff

sub check_ha_cfg {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $ha       = "";
   my $macparam = shift();
   my $nmac = Net::MAC->new( 'mac' => $macparam, 'die' => 0 );
   my $mac = $nmac->convert( 'base' => 16, 'bit_group' => 8, 'delimiter' => '-' );
   $logger->trace("$ll   mac: $mac");
   
   
   my $conffile = "";
   $logger->debug("$ll   check if config file exist");

   if ( -e "$global{'pxesysdir'}/$mac/xen6.pool" ) {
      $logger->trace("$ll  found xenserver 6 pool config");
      $conffile = "$global{'pxesysdir'}/$mac/xen6.pool";
   } elsif ( -e "$global{'pxesysdir'}/$mac/xen7.pool" ) {
      $logger->trace("$ll  found xenserver 7 pool config");
      $conffile = "$global{'pxesysdir'}/$mac/xen7.pool";
   }
   
   if ( "$conffile" ne "" ) {   
      $logger->info("$ll   found $conffile");
      $logger->trace("$ll   get all config from $conffile");
      $conf = new Config::General("$conffile");
      $logger->debug("$ll   Get all xenserver configurations ...");
      my %config = $conf->getall;
      foreach my $sr ( keys %{ $config{'storage'} } ) {
         if ( defined $config{'storage'}{$sr}{'shared'} ) {
            if ( $config{'storage'}{$sr}{'shared'} eq "ha" ) {
               $logger->info("$ll    found HA [$sr] config in config files");
               $ha = $sr;
               if ( defined $config{'storage'}{$sr}{'mhf'} ) {
                  $global{'mhf'} = $config{'storage'}{$sr}{'mhf'};
                  $logger->info("$ll    found MHF : $config{'storage'}{$sr}{'mhf'}");
               } else {
                  $global{'mhf'} = 2;
                  $logger->info("$ll    set default MHF to 2");
               }
               last;
            } ## end if ( $config{'storage'}{$sr}{'shared'} eq "ha" )
         } ## end if ( defined $config{'storage'}{$sr}{'shared'} )
      } ## end foreach my $sr ( keys %{ $config{'storage'} } )
   } else {
      $logger->error("cannot find config file xen[6/7].pool in [$global{'pxesysdir'}/$mac/] - cannot detect HA");
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $ha;
} ## end sub check_ha_cfg

sub check_ha_pool {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc      = 0;
   my $db      = shift();
   my $chkpool = shift();
   $logger->trace("$ll  load db");
   my $sql = "select id, db_srv, db_typ, db_mac, db_control, db_controltyp, s_xenha FROM entries ORDER BY id desc";
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');
   my $haconfig   = "";
   my $firstsrv   = "";
   my $pooltyp    = "";

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      my $db_typ = $serverhash->{$srvid}{'db_typ'};
      $logger->trace("$ll  ==> check - typ: $db_typ / srv: $serverhash->{$srvid}{'db_srv'} / pool: $chkpool");
      if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ ) {
         my $pool = $serverhash->{$srvid}{'db_control'};
         $logger->trace("$ll   found xen pool: [$pool]");
         if ( "$chkpool" eq "$pool" ) {
            if ( $firstsrv eq "" ) {
               $logger->info("$ll   first server in pool found $serverhash->{$srvid}{'db_srv'}");
               $firstsrv = "f";
            }
            my $mac = Net::MAC->new( 'mac' => $serverhash->{$srvid}{'db_mac'}, 'die' => 0 );
            my $nmac = $mac->convert( 'base' => 16, 'bit_group' => 8, 'delimiter' => '-' );
            $logger->trace("$ll   mac: $nmac");
            
            my $conffile = "";
            if ( -e "$global{'pxesysdir'}/$nmac/xen6.pool" ) {
               $logger->trace("$ll  found xenserver 6 pool config");
               $conffile = "$global{'pxesysdir'}/$nmac/xen6.pool";
            } elsif ( -e "$global{'pxesysdir'}/$nmac/xen7.pool" ) {
               $logger->trace("$ll  found xenserver 7 pool config");
               $conffile = "$global{'pxesysdir'}/$nmac/xen7.pool";
            }
            
            if ( "$conffile" ne "" ) {   
               $logger->info("$ll   found $conffile");
               $logger->trace("$ll   get all config from $conffile");
               $conf = new Config::General("$conffile");
               $logger->debug("$ll   Get all xenserver configurations ...");
               my %config = $conf->getall;
               $haconfig = "";
               foreach my $sr ( keys %{ $config{'storage'} } ) {
                  if ( defined $config{'storage'}{$sr}{'shared'} ) {
                     if ( $config{'storage'}{$sr}{'shared'} eq "ha" ) {
                        $logger->info("$ll    found HA config in config files");
                        $haconfig = "h";
                        $pooltyp  = $serverhash->{$srvid}{'db_typ'};
                        set_flag( $db, "s_xenha", $serverhash->{$srvid}{'db_srv'}, "h" );
                        if ( $firstsrv eq "f" ) {
                           $logger->debug("$ll    first server has ha enable");
                           $firstsrv = "h";
                        }
                        if ( $firstsrv ne "h" ) {
                           $logger->warn("$ll    different ha config in pool");
                           $retc = set_flag_pool( $db, "s_insterr", $chkpool, "E" );
                           unless ($rc) {
                              $rc = set_flag_pool( $db, "s_msg", $chkpool, "Pool has different HA configure ???" );
                           }
                        } ## end if ( $firstsrv ne "h" )
                        last;
                     } ## end if ( $config{'storage'}{$sr}{'shared'} eq "ha" )
                  } ## end if ( defined $config{'storage'}{$sr}{'shared'} )
               } ## end foreach my $sr ( keys %{ $config{'storage'} } )
            } else {
               $logger->error("cannot find config file xen[6/7].pool in [$global{'pxesysdir'}/$nmac/] - cannot detect HA in pool");
            }
            
            if ( $haconfig ne "h" ) {
               if ( $firstsrv eq "f" ) {
                  $logger->debug("$ll   first server has ha not enable");
                  $firstsrv = "n";
               } elsif ( $firstsrv eq "n" ) {
                  $logger->debug("$ll   first server has ha not enabled - this server also not");
               } else {
                  $logger->warn("$ll   first server has ha enable - server $serverhash->{$srvid}{'db_srv'} not ?");
                  $rc = set_flag_pool( $db, "s_insterr", $chkpool, "E" );
                  unless ($retc) {
                     $rc = set_flag_pool( $db, "s_msg", $chkpool, "Pool has different HA configure ???" );
                  }
               } ## end else [ if ( $firstsrv eq "f" ) ]
            } ## end if ( $haconfig ne "h" )
         } ## end if ( "$chkpool" eq "$pool" )
      } else {
         $logger->debug("$ll  only XenServer check HA");
      }
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )

   $logger->trace("$ll  pool with HA [$firstsrv]");
   if ( $firstsrv eq "h" ) {
      $logger->debug("$ll  at least one server in pool has ha config [$pooltyp]/[$chkpool]");                                                            # pool not installed or not finish installed

      if ( -e "$global{'fsiinstdir'}/$pooltyp/ks/pool/$chkpool/pool.ok" ) {

         $logger->debug("$ll  pool complete install - start test HA config");

         if ( -d "$global{'fsiinstdir'}/$pooltyp/ks/pool/$chkpool/pool.run" ) {
            $logger->debug("$ll  pool installation running - do not check ha config now");
         } else {
            $logger->debug("$ll  check ha config now");
            if ( -e "$global{'fsiinstdir'}/$pooltyp/ks/pool/$chkpool/pool.ha" ) {                                                  # nicht pool.mhf - kann bei update temp renamed sein
               $logger->debug("$ll  pool dir config has ha also configure");
               unless ($rc) {
                  if ( check_ha_enable( $db, $chkpool ) ) {
                     $logger->info("$ll  pool $chkpool has HA enabled !");
                     $rc = set_flag_pool( $db, "s_xenha", $chkpool, "H" );
                  }
               } ## end unless ($rc)
            } else {
               if ( -d "$global{'fsiinstdir'}/$pooltyp/ks/pool/$chkpool" ) {
                  $logger->trace("$ll  pooldir: $global{'fsiinstdir'}/$pooltyp/ks/pool/$chkpool");
                  $logger->warn("$ll  pool dir has ha not configure ???");
                  $retc = set_flag_pool( $db, "s_insterr", $chkpool, "E" );
                  $retc = set_flag_pool( $db, "s_msg",     $chkpool, "Pool has HA configure but is not in pool config dir activ ??" );
               } elsif ( -e "$global{'fsiinstdir'}/$pooltyp/ks/pool/$chkpool/pool.mhf_disabled" ) {
                  $logger->trace("$ll  pooldir: $global{'fsiinstdir'}/$pooltyp/ks/pool/$chkpool - ha temp disabled");
                  $retc = set_flag_pool( $db, "s_insterr", $chkpool, "W" );
                  $retc = set_flag_pool( $db, "s_msg",     $chkpool, "Pool has HA temporarily disabled (by portal) !" );
               } else {
                  $logger->debug("$ll  poold dir does not exist - pool is not installed yet - ignore");
               }
            } ## end else [ if ( -e "$global{'fsiinstdir'}/$pooltyp/ks/pool/$chkpool/pool.ha" ) ]
         } ## end else [ if ( -d "$global{'fsiinstdir'}/$pooltyp/ks/pool/$chkpool/pool.run" ) ]
      } else {
         $logger->debug("$ll  pool $chkpool is not complete installed yet");
      }
   } elsif ( $firstsrv eq "n" ) {
      $logger->debug("$ll  ha not configure");
   } else {
      $logger->error("Cannot find any status of pool $chkpool - maybe unknown pool");
      $rc = 99;
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_ha_pool

sub check_srvonline {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc  = 0;
   my $srv = shift();

   $logger->trace("$ll   test if server [$srv] online");
   my $p = Net::Ping->new( $global{'pingprot'} );
   if ( $p->ping($srv) ) {
      $logger->trace("$ll server $srv online");
      $rc = 1;
   } else {
      $logger->trace("$ll  server is offline");
   }
   $logger->trace("$ll func end: [$fc] rc=$rc");
   $flvl--;
   return $rc;
} ## end sub check_srvonline

sub check_mm {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc      = 0;                                                                                                                # 0 - not mm, 1 - in mm
   my $srv     = shift();
   my $command = "$global{'toolsdir'}/srvctrl -l $global{'logfile'}.log -s $srv -c";

   if ( check_srvonline($srv) ) {
      $logger->trace("$ll server $srv connected - test if mm enable");
      my $eo = qx($command  2>&1);
      $rc = $?;
      $rc = $rc >> 8 unless ( $rc == -1 );
      $logger->trace("$ll  rc=$retc");
      if ( $rc == 0 ) {
         $logger->trace("$ll  ok - no maintenance mode");
      } elsif ( $rc == 1 ) {
         $logger->trace("$ll  ok - in maintenance mode");
      } else {
         $logger->error("failed cmd [$eo]");
      }
   } else {
      $logger->warn("$ll  server is offline - cannot check mm ");
   }
   $logger->trace("$ll func end: [$fc] rc=$rc");
   $flvl--;
   return $rc;
} ## end sub check_mm

sub check_srvon {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $db     = shift();
   my $srv    = shift();
   my $status = "";
   my $p      = Net::Ping->new( $global{'pingprot'} );

   if ( $p->ping($srv) ) {
      $logger->info("$ll server $srv connected - srv online");
      $status = "O";
      if ( check_mm($srv) ) {
         $logger->debug("$ll server online but in maintenance mode");
         $status = "M";
      }
   } else {
      $logger->info("$ll server $srv not connected - srv offline");
      $status = "";
   }

   my $updatecmd = "UPDATE entries SET s_online = '$status' WHERE db_srv = '$srv' ";
   my $updsth = $db->prepare($updatecmd) or die $db->errstr;
   $logger->trace("$ll  $updatecmd");
   $updsth->execute();
   my $fehler = $db->errstr;
   if ($fehler) {
      $logger->error("DB Meldung: $fehler");
      $rc = 99;
   } else {
      $logger->trace("$ll  ok");
      $updsth->finish();
   }

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_srvon

sub check_on {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;
   my $db = shift();
   my $status;
   $logger->trace("$ll  load db");
   my $sql = 'select id, db_srv, mgmt_ip, s_online from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');
   $logger->trace("$ll  get $lastid records");

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      my $srvip = $serverhash->{$srvid}{'mgmt_ip'};
      my $p     = Net::Ping->new( $global{'pingprot'} );
      if ( $p->ping($srvip) ) {
         $logger->info("$ll ip $srvip connected - srv [$serverhash->{$srvid}{'db_srv'}] online");
         $status = "O";
         if ( check_mm( $serverhash->{$srvid}{'db_srv'} ) ) {
            $logger->debug("$ll server online but in maintenance mode");
            $status = "M";
         }
      } else {
         $logger->info("$ll ip $srvip not connected - srv offline");
         $status = "";
      }
      my $updatecmd = "UPDATE entries SET s_online = '$status' WHERE id = '$srvid' ";
      my $updsth = $db->prepare($updatecmd) or die $db->errstr;
      $logger->trace("$ll  $updatecmd");
      $updsth->execute();
      my $fehler = $db->errstr;
      if ($fehler) {
         $logger->error("DB Meldung: $fehler");
         $rc = 99;
      } else {
         $logger->trace("$ll  ok");
         $updsth->finish();
      }
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_on

sub check_syms {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;
   my $db = shift();
   $logger->trace("$ll  load db");
   my $sql = 'select id, db_srv,db_typ, mgmt_ip, db_mac, db_control, db_controltyp, j_inst from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');
   $logger->trace("$ll  get $lastid records");

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      my $j_inst;
      unless ($rc) {
         my $db_mac = $serverhash->{$srvid}{'db_mac'};
         my $mac    = Net::MAC->new( 'mac' => $db_mac, 'die' => 0 );
         my $nmac   = $mac->convert( 'base' => 16, 'bit_group' => 8, 'delimiter' => '-' );
         $j_inst = sym_exist($nmac);
         my $updatecmd = "UPDATE entries SET j_inst = '$j_inst' WHERE id = '$srvid' ";
         my $updsth = $db->prepare($updatecmd) or die $db->errstr;
         $logger->trace("$ll  $updatecmd");
         $updsth->execute();
         my $fehler = $sth->errstr;

         if ($fehler) {
            $logger->error("DB Meldung: $fehler");
            $rc = 99;
         } else {
            $updsth->finish();
            if ($j_inst) {
               $logger->debug("$ll  sym link for $nmac exist");
            } else {
               $logger->debug("$ll  no sym link for $nmac exist");
            }
         } ## end else [ if ($fehler) ]
      } ## end unless ($rc)
      unless ($rc) {
         if ($j_inst) {
            my $updatecmd = "UPDATE entries SET s_inststart = 'S' WHERE id = '$srvid' ";
            my $updsth = $db->prepare($updatecmd) or die $db->errstr;
            $logger->trace("$ll  $updatecmd");
            $updsth->execute();
            my $fehler = $updsth->errstr;
            if ($fehler) {
               $logger->error("DB Meldung: $fehler");
               $rc = 99;
            } else {
               $updsth->finish();
            }
         } ## end if ($j_inst)
      } ## end unless ($rc)
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_syms

sub set_sym {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $db     = shift();
   my $server = shift();
   $logger->trace("$ll  load db");
   my $sql = 'select id, db_srv, db_typ, db_mac from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');
   $logger->trace("$ll  get $lastid records");
   my $db_mac = "";
   my $typ    = "";

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      if ( "$server" eq "$serverhash->{$srvid}{'db_srv'}" ) {
         $logger->trace("$ll   found srv in db");
         $db_mac = $serverhash->{$srvid}{'db_mac'};
         $typ    = $serverhash->{$srvid}{'db_typ'};
         last;
      } ## end if ( "$server" eq "$serverhash->{$srvid}{'db_srv'}" )
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   if ($db_mac) {
      $logger->info("$ll   found server and create symlink");
      my $mac = Net::MAC->new( 'mac' => $db_mac, 'die' => 0 );
      my $nmac         = $mac->convert( 'base' => 16, 'bit_group' => 8, 'delimiter' => '-' );
      my $path_srvconf = $global{'pxeroot'} . "/sys/" . $nmac;
      my $sym_file     = $global{'pxeroot'} . "/pxelinux.cfg/01-" . $nmac;
      $logger->trace("$ll  symlink: $sym_file");
      if ( -f $sym_file ) {
         $logger->trace("$ll  symlink for $mac exist - do not need to set");
      } else {
         $logger->trace("$ll  symlink for $mac does not exist - create");
         my $sym_dest;
         my $sym_dest_link;
         my $sym_dest_fullpath;
         if ( $typ =~ m/^esxi/ ) {
            $sym_dest = "ks-$typ.pxe";
         } elsif ( $typ =~ m/^xen6/ ) {
            $sym_dest = "xen6.pxe";
         } elsif ( $typ =~ m/^xen7/ ) {
            $sym_dest = "xen7.pxe";
         } elsif ( $typ =~ m/^co/ ) {
            $sym_dest = "$typ.pxe";
         } elsif ( $typ =~ m/^rh/ ) {
            $sym_dest = "$typ.pxe";
         } else {
            $logger->error("Error create symlink - $server : unsupported srv typ found [$typ] !");
            $rc = 99;
         }
         unless ($rc) {
            $sym_dest_fullpath = $path_srvconf . "/" . $sym_dest;
            $sym_dest_link     = "../sys/" . $nmac . "/" . $sym_dest;
         }
         unless ($rc) {
            if ( -d $path_srvconf ) {
               if ( -e $sym_dest_fullpath ) {
                  my $ret = symlink( $sym_dest_link, $sym_file );
                  unless ($ret) {
                     $logger->error("cannot create symlink for $server / $nmac");
                     $rc = 99;
                  }
               } else {
                  $logger->error("Error create symlink - $server : server config dir exit - but no $sym_dest !");
                  $rc = 99;
               }
            } else {
               $logger->error("Error create symlink - $server : server config dir not found !");
               $rc = 99;
            }
         } ## end unless ($rc)
         unless ($rc) {
            my $updatecmd = "UPDATE entries SET j_inst = '1' WHERE db_mac = '$mac' ";
            my $updsth = $db->prepare($updatecmd) or die $db->errstr;
            $logger->trace("$ll  $updatecmd");
            $updsth->execute();
            my $fehler = $sth->errstr;
            if ($fehler) {
               $logger->error("DB Meldung: $fehler");
               $rc = 99;
            } else {
               $updsth->finish();
            }
         } ## end unless ($rc)
         unless ($rc) {
            my $updatecmd = "UPDATE entries SET s_inststart = 'S' WHERE db_mac = '$mac' ";
            my $updsth = $db->prepare($updatecmd) or die $db->errstr;
            $logger->trace("$ll  $updatecmd");
            $updsth->execute();
            my $fehler = $updsth->errstr;
            if ($fehler) {
               $logger->error("DB Meldung: $fehler");
               $rc = 99;
            } else {
               $updsth->finish();
            }
         } ## end unless ($rc)
      } ## end else [ if ( -f $sym_file ) ]
   } else {
      $logger->warn("$ll   cannot find $server in db");
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub set_sym

sub set_instdate {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my ( $db, $datum, $srv ) = @_;
   my $mac = "0:0";
   $logger->trace("$ll  search $srv in db for mac");
   my $sql = "SELECT db_mac,db_srv FROM entries WHERE db_srv = \'$srv\'";
   $logger->trace("$ll  sql: $sql");
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid = $sth->rows;

   if ( $lastid > 1 ) {
      $logger->error("find more than one server entry - don´t know which one I must use - abort");
      $retc = 99;
   } elsif ( $lastid == 1 ) {
      my $serverhash = $sth->fetchall_hashref('db_srv');
      $mac = ${$serverhash}{$srv}{'db_mac'};
      $logger->debug("$ll  mac found: $mac");
   } else {
      $logger->info("$ll  server $srv not found in db - abort");
   }
   unless ($retc) {
      unless ( $mac eq "0:0" ) {
         $logger->debug("$ll  found mac: $mac");
         $mac =~ s/:/-/g;
         $logger->trace("$ll  set inst date on system $mac with $datum");
         my $command = "echo $datum > $global{'pxesysdir'}/$mac/inst.start";
         $logger->trace("$ll  cmd: [$command]");
         my $eo = qx($command  2>&1);
         $retc = $?;
         $retc = $retc >> 8 unless ( $retc == -1 );
         $logger->trace("$ll  rc=$retc");

         if ( $retc == 0 ) {
            $logger->trace("$ll  set");
            my $instend = "$global{'pxesysdir'}/$mac/inst.end";
            unless ( -f $instend ) {
               $logger->trace("$ll  $instend does not exist - do not need to delete");
            } else {
               unless ( unlink($instend) ) {
                  $logger->error("deleting $instend [$!]");
                  $retc = 99;
               } else {
                  $logger->debug("$ll  $instend deleted");
               }
            } ## end else
         } else {
            $logger->error("failed cmd [$eo]");
         }
      } else {
         $logger->error("no mac found for $srv - abort");
         $retc = 44;
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub set_instdate

sub del_instdate {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my ( $db, $srv ) = @_;
   my $mac = "0:0";
   $logger->trace("$ll  search $srv in db for mac");
   my $sql = "SELECT db_mac,db_srv FROM entries WHERE db_srv = \'$srv\'";
   $logger->trace("$ll  sql: $sql");
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid = $sth->rows;

   if ( $lastid > 1 ) {
      $logger->error("find more than one server entry - don´t know which one I must use - abort");
      $retc = 99;
   } elsif ( $lastid == 1 ) {
      my $serverhash = $sth->fetchall_hashref('db_srv');
      $mac = ${$serverhash}{$srv}{'db_mac'};
      $logger->debug("$ll  mac found: $mac");
   } else {
      $logger->info("$ll  server $srv not found in db - abort");
   }
   unless ($retc) {
      unless ( $mac eq "0:0" ) {
         $logger->debug("$ll  found mac: $mac");
         $mac =~ s/:/-/g;
         $logger->trace("$ll  del inst date on system $mac");
         if ( -f "$global{'pxesysdir'}/$mac/inst.start" ) {
            $logger->trace("$ll  found $global{'pxesysdir'}/$mac/inst.start - delete it");
            unless ( unlink("$global{'pxesysdir'}/$mac/inst.start") ) {
               $logger->error("deleting: $global{'pxesysdir'}/$mac/inst.start");
               $retc = 99;
            } else {
               $logger->debug("deleted!");
            }
         } else {
            $logger->trace("$ll  do not find $global{'pxesysdir'}/$mac/inst.start - ok, do not need to delete");
         }
         if ( -f "$global{'pxesysdir'}/$mac/inst.end" ) {
            $logger->trace("$ll  found $global{'pxesysdir'}/$mac/inst.end - delete it");
            unless ( unlink("$global{'pxesysdir'}/$mac/inst.end") ) {
               $logger->error("deleting: $global{'pxesysdir'}/$mac/inst.end");
               $retc = 99;
            } else {
               $logger->debug("deleted!");
            }
         } else {
            $logger->trace("$ll  do not find $global{'pxesysdir'}/$mac/inst.end - ok, do not need to delete");
         }

      } else {
         $logger->error("no mac found for $srv - abort");
         $retc = 44;
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub del_instdate

sub del_sym {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $db     = shift();
   my $server = shift();
   $logger->trace("$ll  load db");
   my $sql = 'select id, db_srv, db_typ, db_mac from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');
   $logger->trace("$ll  get $lastid records");
   my $db_mac = "";
   my $typ    = "";

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      if ( "$server" eq "$serverhash->{$srvid}{'db_srv'}" ) {
         $logger->trace("$ll   found srv in db");
         $db_mac = $serverhash->{$srvid}{'db_mac'};
         $typ    = $serverhash->{$srvid}{'db_typ'};
         last;
      } ## end if ( "$server" eq "$serverhash->{$srvid}{'db_srv'}" )
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   if ($db_mac) {
      $logger->info("$ll   found server and delete symlink");
      my $mac = Net::MAC->new( 'mac' => $db_mac, 'die' => 0 );
      my $nmac         = $mac->convert( 'base' => 16, 'bit_group' => 8, 'delimiter' => '-' );
      my $path_srvconf = $global{'pxeroot'} . "/sys/" . $nmac;
      my $sym_file     = $global{'pxeroot'} . "/pxelinux.cfg/01-" . $nmac;
      $logger->trace("$ll  symlink: $sym_file");
      unless ( -f $sym_file ) {
         $logger->trace("$ll  symlink for $mac does not exist - do not need to delete");
      } else {
         $logger->trace("$ll  symlink for $mac exist - delete");
         unless ( unlink($sym_file) ) {
            $logger->error("deleting $sym_file [$!]");
            $rc = 99;
         } else {
            $logger->debug("$ll  $sym_file deleted!");
         }
         unless ($rc) {
            my $updatecmd = "UPDATE entries SET j_inst = '' WHERE db_mac = '$mac' ";
            my $updsth = $db->prepare($updatecmd) or die $db->errstr;
            $logger->trace("$ll  $updatecmd");
            $updsth->execute();
            my $fehler = $sth->errstr;
            if ($fehler) {
               $logger->error("DB Meldung: $fehler");
               $rc = 99;
            } else {
               $updsth->finish();
            }
         } ## end unless ($rc)
         unless ($rc) {
            my $updatecmd = "UPDATE entries SET s_inststart = '' WHERE db_mac = '$mac' ";
            my $updsth = $db->prepare($updatecmd) or die $db->errstr;
            $logger->trace("$ll  $updatecmd");
            $updsth->execute();
            my $fehler = $updsth->errstr;
            if ($fehler) {
               $logger->error("DB Meldung: $fehler");
               $rc = 99;
            } else {
               $updsth->finish();
            }
         } ## end unless ($rc)
      } ## end else
   } else {
      $logger->warn("$ll   cannot find $server in db");
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub del_sym

sub check_patch_all {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;
   my $db = shift();
   $logger->trace("$ll  load db");
   my $sql = 'select id, db_srv,db_typ, j_logshow from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');
   $logger->trace("$ll  get $lastid records");

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      my $retc = check_patch_srv( $serverhash->{$srvid}{'db_srv'}, $db );
      if ($retc) {
         $logger->warn("error getting patches");
      }
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_patch_all

sub check_patch_pool {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc   = 0;
   my $pool = shift();
   my $db   = shift();
   $logger->trace("$ll  load db");
   my $sql = 'select id, db_srv,db_typ, db_control, j_logshow from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');
   $logger->trace("$ll  get $lastid records");

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      if ( $serverhash->{$srvid}{'db_control'} eq $pool ) {
         $logger->trace("$ll  found srv in pool $pool");
         my $retc = check_patch_srv( $serverhash->{$srvid}{'db_srv'}, $db );
         if ($retc) {
            $logger->warn("error getting patches");
         }
      } ## end if ( $serverhash->{$srvid}{'db_control'} eq $pool )
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_patch_pool

sub check_patch_srv {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc  = 0;
   my $srv = shift();
   my $db  = shift();

   if ( "$srv" eq "" ) {
      $logger->error("$ll  no servername given - abort");
      $rc = 99;
   } else {
      $logger->trace("$ll   load db");
      my $sql = 'select id, db_srv,db_typ from entries order by id desc';
      my $sth = $db->prepare($sql) or die $db->errstr;
      $sth->execute or die $sth->errstr;
      my $lastid     = $sth->rows;
      my $serverhash = $sth->fetchall_hashref('id');

      my $short;
      if ( $srv =~ /((.+?)|(.*?))\./ ) {
         $short = $1;
      } else {
         $short = $srv;
      }

      $rc = del_flag_srv( $db, "s_patchlevel", $short );
      unless ($rc) {
         $rc = del_flag_srv( $db, "s_patchlevels", $short );
      }
      unless ($rc) {
         $logger->debug("$ll call getpatch");
         my $command = "$global{'toolsdir'}/getpatch -q -l $global{'logfile'}.log -s $srv";
         $logger->trace("$ll  cmd: [$command]");
         my $patchliste = qx($command  2>&1);
         $rc = $?;
         $rc = $rc >> 8 unless ( $rc == -1 );
         $patchliste =~ s/^\s+//;
         $patchliste =~ s/\s+$//;
         $patchliste =~ s/\n//;

         if ( $rc == 0 ) {
            $logger->debug("$ll  found patchlist [$patchliste]");
            $rc = upd_flag( $db, 's_patchlevels', $srv, $patchliste );
            unless ($rc) {
               my $lastpatch = "";
               my @patchlist = split( / /, $patchliste );
               $lastpatch = $patchlist[ $#patchlist ];
               if ( defined $lastpatch ) {
                  if ( "$lastpatch" eq "" ) {
                     $logger->info("$ll  srv: $srv - no patches found");
                     $rc = upd_flag( $db, 's_patchlevel', $srv, "" );
                  } else {
                     $logger->info("$ll  srv: $srv - last patch: $lastpatch");
                     $rc = upd_flag( $db, 's_patchlevel', $srv, $lastpatch );
                  }
               } else {
                  $logger->info("$ll  srv: $srv - no patches found");
                  $rc = upd_flag( $db, 's_patchlevel', $srv, "" );
               }
            } else {
               $logger->error("$ll  cannot update db with patch list");
            }
         } elsif ( $rc == 3 ) {
            $logger->debug("$ll srv $srv offline");
            $rc = 0;
         } elsif ( $rc == 4 ) {
            $logger->debug("$ll srv $srv has wrong ssh keys");
            unless ($rc) {
               $rc = upd_flag( $db, 's_insterr', $srv, "W" );
               $rc = upd_flag( $db, 's_msg',     $srv, "wrong ssh keys" );
            }
         } elsif ( $rc == 5 ) {
            $logger->debug("$ll srv $srv refused connection");
            unless ($rc) {
               $rc = upd_flag( $db, 's_insterr', $srv, "W" );
               $rc = upd_flag( $db, 's_msg',     $srv, "server refused connection" );
            }
         } else {
            $logger->error("failed getting patchlist - maybe srv [$srv] offline");
         }
      } ## end unless ($rc)
   } ## end else [ if ( "$srv" eq "" ) ]
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub check_patch_srv

sub upd_srv {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc         = 0;
   my $srv        = shift();
   my $autoreboot = shift();
   $logger->trace("$ll   srv: $srv");
   $logger->trace("$ll   autoreboot: $autoreboot");
   my $command = "$global{'toolsdir'}/srvctrl -l $global{'logfile'}.log -s $srv -u";
   $logger->debug("$ll   test if server online");
   my $p = Net::Ping->new( $global{'pingprot'} );

   if ( $p->ping($srv) ) {
      $logger->trace("$ll server $srv connected");
      if ( $autoreboot eq "yes" ) {
         $logger->debug("$ll  run with auto reboot");
         $command = "$command -a";
      } else {
         $logger->debug("$ll  run with auto reboot");
      }
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      $logger->trace("$ll  rc=$retc");
      if ( $retc == 0 ) {
         $logger->trace("$ll  ok - no reboot");
      } elsif ( $retc == 1 ) {
         $logger->trace("$ll  ok - need reboot");
      } else {
         $logger->error("failed cmd [$eo]");
      }
   } else {
      $logger->trace("$ll server $srv not connected - srv offline ");
      $retc = 77;
   }
   $logger->trace("$ll func end: [$fc] rc=$rc");
   $flvl--;
   return $rc;
} ## end sub upd_srv

sub check_log {
   my $fc     = ( caller(0) )[ 3 ];
   my $llback = $logger->level();

   # $logger->level( $global{'logprod'} );
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;
   my $db = shift();
   $logger->trace("$ll  load db");
   my $sql = 'select id, db_srv,db_typ, j_logshow from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');
   $logger->trace("$ll  get $lastid records");

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      my $db_typ  = $serverhash->{$srvid}{'db_typ'};
      my $srvname = $serverhash->{$srvid}{'db_srv'};
      my $short;
      my $srvlog;
      $logger->trace("$ll  server: [$srvname]");
      if ( $srvname =~ /((.+?)|(.*?))\./ ) {
         $short = $1;
      } else {
         $short = $srvname;
      }
      $logger->trace("$ll  check log for $short");
      $srvlog = "$global{'fsiinstdir'}/$db_typ/ks/log/$short.log";
      unless ($rc) {
         my $j_showlog = "";
         if ( -f $srvlog ) {
            $logger->trace("$ll  log $srvlog exist");
            $j_showlog = "1";
         } else {
            $logger->trace("$ll  no log for $srvlog exist");
         }
         my $updatecmd = "UPDATE entries SET j_logshow = '$j_showlog' WHERE id = '$srvid' ";
         my $updsth = $db->prepare($updatecmd) or die $db->errstr;
         $logger->trace("$ll  $updatecmd");
         $updsth->execute();
         my $fehler = $sth->errstr;
         if ($fehler) {
            $logger->error("DB Meldung: $fehler");
         } else {
            $updsth->finish();
         }
      } ## end unless ($rc)
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   $logger->trace("$ll func end: [$fc]");
   $flvl--;

#   $logger->level($llback);
   return $rc;
} ## end sub check_log

sub sym_exist {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc       = 0;
   my $symexist = "";
   my $mac      = shift();
   my $sym      = $global{'pxeroot'} . "/pxelinux.cfg/01-" . $mac;
   $logger->trace("$ll  symlink: $sym");

   if ( -f $sym ) {
      $logger->trace("$ll  symlink for $mac exist");
      $symexist = "1";
   } else {
      $logger->trace("$ll  symlink for $mac does not exist");
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $symexist;
} ## end sub sym_exist

1;
__END__
