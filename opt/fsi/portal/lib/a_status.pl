# logger line commented for speed

sub get_daemon {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc   = ( caller(0) )[ 3 ];
   my $ll   = " " x $flvl;
   $flvl++;

   $logger->trace("$ll func start: [$fc]");
 
   my $rc         = 0;

   my %icon;
   my $check_icon;
   my $online_icon;
   
   $icon{'off'}="16_led-circle-red";
   $icon{'sleeping'}="16_led-circle-yellow";
   $icon{'running'}="16_led-circle-green";
   $icon{'unknown'}="16_led-circle-grey";

   my $db=db_connect();

   my $status=read_daemon( $db, "online");
   if ( defined $icon{$status} ) {
      $check_icon=$icon{$status};
   } else {
      $check_icon=$icon{'unknown'};
   }

   $status=read_daemon( $db, "all");
   if ( defined $icon{$status} ) {
      $online_icon=$icon{$status};
   } else {
      $online_icon=$icon{'unknown'};
   }
   
   $rc = db_disconnect($db);
   $status  = '{"Items":{
      "0":{
         "check": "' . $check_icon . '",
         "online": "' . $online_icon . '"
         }
   }}';

   $flvl--;
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $logger->level($llback);
   return $status;
}

sub get_status {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc   = ( caller(0) )[ 3 ];
   my $ll   = " " x $flvl;
   $flvl++;

   $logger->trace("$ll func start: [$fc]");
 
   my $rc         = 0;
   my $url        = "#myError";
   my $urlhost    = request->base->host;
   my $status;
   
   my $statdb=db_connect();
   
   my $sql = 'SELECT id, short, long, jobuser, url, logdatei, control, ctyp FROM status ORDER BY id ASC';
   my $sth = $statdb->prepare($sql);
   $sth->execute;

   my $lastid = $sth->rows;
   if ( $lastid >= 1 ) {
      my $statushash_p = $sth->fetchall_hashref('id');
      foreach my $id ( keys %{$statushash_p} ) {
         $statushash_p->{$id}{'vitemp'} = $urlhost;
      }
      $status = '{"Items":' . to_json($statushash_p) . '}';
   } else {
      my $url = "#myWaiting";
      $status = '{"Items":{
         "0":{
            "url":"' . $url . '",
            "short":"Waiting ...", 
            "long":"No active jobs on ' . $urlhost . ' - waiting for user to start new jobs", 
            "jobuser":"system",
            "logdatei":"fsi",
            "control":"-",
            "host":"' . $urlhost . '"
            }}}';
   } ## end else [ if ( $lastid >= 1 ) ]

   $sth->finish();
   $rc = db_disconnect($statdb);
   if ($rc) {
      $status  = '{"Items":{
         "0":{
            "url":"' . $url . '",
            "short":"Status Error", 
            "long":"Error during detecting portal status", 
            "user":"system",
            "logdatei":"fsi",
            "control":"-",
            "host":"' . $urlhost . '"
            }
      }}';
   }   

   $flvl--;
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $logger->level($llback);
   return $status;
} ## end sub get_status

sub get_info {
   my $llback = $logger->level();
   $logger->level( 'INFO' );
   my $fc   = ( caller(0) )[ 3 ];
   my $ll   = " " x $flvl;
   $flvl++;

   $logger->trace("$ll func start: [$fc]");

   my $rc      = 0;
   my $ctrltyp = shift();
   my $who     = shift();
   my $status  = "";
   
   if ( "$ctrltyp" eq "" ) {
      $status  = '{"Status":{"status":"error","msg":"no control typ given"}}';
      $rc=44;
   }
   if ( "$who" eq "" ) {
      $status  = '{"Status":{"status":"error","msg":"no search given"}}';
      $rc=44;
   }
   
   unless ( $rc ) {
      my $db=db_connect();
      my $sql = "SELECT typ,who,status,info FROM $global{'dbt_worker'} WHERE ( typ = '$ctrltyp' AND who = '$who' )";
      $logger->trace("$ll   sql: $sql");
      my $sth = $db->prepare($sql);
      $sth->execute;

      my $lastid = $sth->rows;
      $logger->trace("$ll  entries in $global{'dbt_worker'} found: [$lastid]");
      if ( $lastid > 1 ) {
         $status  = '{"Status":{"status":"error","msg":"to much workstat entries found - please clean up database"}}';
         $rc=44;
      } elsif ( $lastid == 1 ) {
         my $statushash_r = $sth->fetchall_hashref('who');
         
         if ($logger->is_trace()) {
            my $dumpout=Dumper($statushash_r);
            $logger->trace("$ll  Status Hash Dump: $dumpout");  
         }

         $status  = '{"Status":{"status":"' . $statushash_r->{$who}{'status'} . '","msg":"' . $statushash_r->{$who}{'info'} . '"}}';
      } else {
         $status  = '{"Status":{"status":"error","msg":"no workstat entry found for ' . $who . '"}}';
         $rc=44;
      }
      $sth->finish();
      $rc = db_disconnect($db);
      if ( $rc ) {
         $status  = '{"Status":{"status":"error","msg":"db closing error"}}';
      }   
   }
   $flvl--;
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $logger->level($llback);
   return $status;
}


ajax '/fsistat' => sub {
   content_type('application/json');
   return get_status();
};

ajax '/fsigetinfo/:typ/:who' => sub {
   content_type('application/json');
   my $who = params->{who};
   my $typ = params->{typ};
   # $logger->trace("$ll  who: [$who] / typ: [$typ]");
   return get_info($typ,$who);
};

ajax '/fsidaemon' => sub {
   content_type('application/json');
   return get_daemon();
};

