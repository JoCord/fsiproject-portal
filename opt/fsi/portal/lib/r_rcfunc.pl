# remote control functions

sub power_off_pool {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc      = 0;
   my $db      = shift();
   my $chkpool = shift();
   $logger->trace("$ll   select data from db");
   my $sql = 'select id, db_srv, db_typ, db_control from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      if ( $serverhash->{$srvid}{'db_typ'} =~ m/^xen/ ) {
         $logger->trace("$ll  found xen pool: [$serverhash->{$srvid}{'db_control'}]");
         if ( "$chkpool" eq "$serverhash->{$srvid}{'db_control'}" ) {
            $retc = remote_control( $db, $serverhash->{$srvid}{'db_srv'}, "poweroff" );
         }
      } else {
         $logger->debug("$ll  only XenServer can shutdown with pooloff flag");
      }
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub power_off_pool


sub remote_control {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;

   my $db     = shift();
   my $server = shift();
   my $job    = shift();

   my $rc_type = "";

   $logger->trace("$ll   select data from db");
   my $sql = 'select id, db_srv,db_mac,rc_type from entries order by id desc';
   my $sth = $db->prepare($sql) or die $db->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   my $serverhash = $sth->fetchall_hashref('id');

   $logger->trace("$ll  search server [$server]");

   for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ ) {
      if ( "$server" eq "$serverhash->{$srvid}{'db_srv'}" ) {
         $found = 1;
         $logger->trace("$ll   found srv in db");
         $rc_type = $serverhash->{$srvid}{'rc_type'};
         $db_mac  = $serverhash->{$srvid}{'db_mac'};
         last;
      } ## end if ( "$server" eq "$serverhash->{$srvid}{'db_srv'}" )
   } ## end for ( my $srvid = 1 ; $srvid <= $lastid ; $srvid++ )

   if ( "$rc_type" eq "" ) {
      $logger->warn("$ll  cannot find [$server] in db");
      $rc = 2;
   } elsif ( "$rc_type" eq "none" ) {
      $logger->info("$ll  no remote control configure for server $server - ignore");
   } else {
      $logger->debug("$ll found rc type: $rc_type");

      my $rcscript = "$global{'rcdir'}/$rc_type/rc.pl";
      $logger->trace("$ll  script: $rcscript");

      if ( -f $rcscript ) {
         $logger->trace("$ll  rc script exist - call it");
         my $command = "$rcscript -l $global{'logdir'}/fsi  --mac $db_mac --do $job";
         $logger->trace("$ll  cmd: [$command]");
         my $eo = qx($command  2>&1);
         $retc = $?;
         $retc = $retc >> 8 unless ( $retc == -1 );
         unless ($retc) {
            $logger->trace("$ll  ok");
            if ( "$job" eq "poweron" ) {

            } elsif ( "$job" eq "poweroff" ) {
               $retc = del_flag_srv( $db, 's_online', $server );
               $logger->trace("$ll  sleep 3 seconds to wait for hardware to power off");
            }
         } else {
            $logger->error("failed cmd [$eo]");
            $global{'errmsg'} = "$server - cannot $job";
         }
      } else {
         $logger->error("cannot find rc script: $rcscript");
         $rc = 99;
      }
   } ## end else [ if ( "$rc_type" eq "" ) ]

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub remote_control


1;
__END__
