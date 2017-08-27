# flag functions
sub set_flag {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc   = 0;
   my $db   = shift();
   my $flag = shift();
   my $srv  = shift();
   $srv =~ s/^\s+//;
   $srv =~ s/\s+$//;
   $srv =~ s/\n//;
   my $cont = shift();
   $logger->trace("$ll  flag to set: $flag");
   $logger->trace("$ll  flag content: $cont");
   $logger->trace("$ll  server to set: $srv");
   $logger->trace("$ll  $flag exist ?");
   my $sql = "select exists(select $flag from entries)";
   $logger->trace("$ll   sql: $sql");
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute;
   my $rowtesterr = $sth->errstr;

   if ($rowtesterr) {
      $global{'errmsg'} = "$flag does not exist";
      $logger->error("$global{'errmsg'}");
      $rc = 99;
   } else {
      $logger->debug("$ll  flag $flag exist");
      if ( $srv ne "all" ) {
         $logger->debug("$ll  update one server");
         $logger->debug("$ll   update db with flag $flag for $server");
         $retc = upd_flag( $db, $flag, $srv, $cont );
      } else {
         $logger->debug("$ll  update all server");
         my $sql = 'select id, db_srv from entries order by id desc';
         my $sth = $db->prepare($sql) or die $db->errstr;
         $sth->execute or die $sth->errstr;
         my $lastid     = $sth->rows;
         my $serverhash = $sth->fetchall_hashref('id');
         $logger->trace("$ll  get $lastid records");
         for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
            $logger->debug("$ll   update db with flag $flag for $serverhash->{$srvid}{'db_srv'}");
            $retc = upd_flag( $db, $flag, $serverhash->{$srvid}{'db_srv'}, $cont );
            if ($retc) {
               last;
            }
         } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
      } ## end else [ if ( $srv ne "all" ) ]
   } ## end else [ if ($rowtesterr) ]
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub set_flag

sub del_flag {
   my $llback = $logger->level();

#   $logger->level($global{'logprod'}); # one of DEBUG, INFO, WARN, ERROR, FATAL
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc   = 0;
   my $db   = shift();
   my $flag = shift();
   $logger->trace("$ll  flag to delete: $flag");
   $logger->trace("$ll  $flag exist ?");
   my $sql = "select exists(select $flag from entries)";
   $logger->trace("$ll   sql: $sql");
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute;
   my $rowtesterr = $sth->errstr;

   if ($rowtesterr) {
      $global{'errmsg'} = "$flag does not exist";
      $logger->error("$global{'errmsg'}");
      $rc = 99;
   } else {
      $logger->trace("$ll  load db");
      $sql = "select id, $flag from entries order by id desc";
      $sth = $db->prepare($sql) or die $db->errstr;
      $sth->execute or die $sth->errstr;
      my $lastid     = $sth->rows;
      my $serverhash = $sth->fetchall_hashref('id');
      $logger->trace("$ll  get $lastid records");
      for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
         my $updatecmd = "UPDATE entries SET $flag = '' WHERE id = '$srvid' ";
         my $updsth = $db->prepare($updatecmd) or die $db->errstr;
         $logger->trace("$ll  $updatecmd");
         $updsth->execute();
         my $fehler = $sth->errstr;
         if ($fehler) {
            $logger->error("DB Meldung: $fehler");
            $rc = 99;
         } else {
            $logger->trace("$ll  del ok");
            $updsth->finish();
         }
      } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   } ## end else [ if ($rowtesterr) ]
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub del_flag

sub del_flag_dbcontrol {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );                                                                                           # one of DEBUG, INFO, WARN, ERROR, FATAL
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc   = 0;
   my $db   = shift();
   my $flag = shift();
   my $pool = shift();
   $logger->trace("$ll  flag to delete: $flag");
   $logger->trace("$ll  $flag exist ?");
   my $sql = "select exists(select $flag from entries)";
   $logger->trace("$ll   sql: $sql");
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute;
   my $rowtesterr = $sth->errstr;

   if ($rowtesterr) {
      $global{'errmsg'} = "$flag does not exist";
      $logger->error("$global{'errmsg'}");
      $rc = 99;
   } else {
      $logger->trace("$ll  load db");
      $sql = "SELECT id, db_control, db_typ, db_srv, $flag FROM entries order by id desc";
      $sth = $db->prepare($sql) or die $db->errstr;
      $sth->execute or die $sth->errstr;
      my $lastid     = $sth->rows;
      my $serverhash = $sth->fetchall_hashref('id');
      $logger->trace("$ll  get $lastid records");
      for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {

         # if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ ) {
         $logger->trace("$ll  found xen pool: [$serverhash->{$srvid}{'db_control'}]");
         if ( "$serverhash->{$srvid}{'db_control'}" eq "$pool" ) {
            $logger->trace("$ll   found pool [$pool] to delete flag [$flag]");
            $retc = del_flag_srv( $db, $flag, "$serverhash->{$srvid}{'db_srv'}" );
         }

         #}
      } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   } ## end else [ if ($rowtesterr) ]
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub del_flag_dbcontrol

sub del_flag_srv {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );                                                                                           # one of DEBUG, INFO, WARN, ERROR, FATAL
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc        = 0;
   my $db        = shift();
   my $flag      = shift();
   my $srv       = shift();
   my $updatecmd = "UPDATE entries SET $flag = '' WHERE db_srv = \'$srv\' ";
   my $updsth    = $db->prepare($updatecmd) or die $db->errstr;
   $logger->trace("$ll  $updatecmd");
   $updsth->execute();
   my $fehler = $updsth->errstr;

   if ($fehler) {
      $logger->error("DB Meldung: $fehler");
      $rc = 99;
      last;
   } else {
      $updsth->finish();
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub del_flag_srv

sub set_flag_pool {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );                                                                                           # one of DEBUG, INFO, WARN, ERROR, FATAL
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc        = 0;
   my $db        = shift();
   my $flag      = shift();
   my $pool      = shift();
   my $content   = shift();
   my $updatecmd = "UPDATE entries SET $flag = \'$content\' WHERE db_control = \'$pool\' ";
   my $updsth    = $db->prepare($updatecmd) or die $db->errstr;
   $logger->trace("$ll  $updatecmd");
   $updsth->execute();
   my $fehler = $updsth->errstr;

   if ($fehler) {
      $logger->error("DB Meldung: $fehler");
      $rc = 99;
      last;
   } else {
      $updsth->finish();
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub set_flag_pool

sub upd_flag {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );                                                                                           # one of DEBUG, INFO, WARN, ERROR, FATAL
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc   = 0;
   my $db   = shift();
   my $flag = shift();
   my $srv  = shift();
   my $cont = shift();
   unless ( defined $db ) {
      $logger->error("no db handle defined");
      return 99;
   }
   unless ( defined $flag ) {
      $logger->error("no flag defined");
      return 99;
   }
   unless ( defined $srv ) {
      $logger->error("no server to update defined");
      return 99;
   }
   unless ( defined $cont ) {
      $logger->error("no value for flag defined");
      return 99;
   }
   $logger->trace("$ll  flag: [$flag] / srv: [$srv] / content: [$cont]");
   my $updatecmd = "UPDATE entries SET $flag = \'$cont\' WHERE db_srv = \'$srv\' ";
   my $updsth = $db->prepare($updatecmd) or die $db->errstr;
   $logger->trace("$ll  $updatecmd");
   $updsth->execute();
   my $fehler = $updsth->errstr;
   if ($fehler) {
      $logger->error("DB Meldung: $fehler");
      $rc = 99;
      last;
   } else {
      $updsth->finish();
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub upd_flag
1;
