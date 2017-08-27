any [ 'get', 'post' ] => '/ponsrvmark' => sub {
   my $weburl = '/ponsrvmark';
   session 'now' => $weburl;
   $logger->trace("$ll func start: $weburl");
   local *__ANON__ = "dance: $weburl";                                                                                             # default if no function for caller sub
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $flvl--;
   my $retc   = 0;
   my $errmsg = "";

   if ( !session('logged_in') ) {
      $logger->info("$ll  redirect to root web site / ");
      return redirect '/';
   } else {
      my $retc = db_reload();
      
      my $marksrvhash = {};
      my $c           = 1;
      my @markedsrv   = split( " ", session('srvarray') );
      $logger->trace("$ll  marked server list: @markedsrv");
      my $srvnames = "";
      my $srvcount = $#markedsrv + 1;
      foreach $x (@markedsrv) {
         $marksrvhash->{$c} = $serverhash_p->{$x};
         $c++;
         $srvnames = "$srvnames $serverhash_p->{$x}{'db_srv'}";
      }

      if ( request->method() eq "POST" ) {
         $logger->trace("$ll  POST Section");
         my $sess_reload = session('reload');
         my $sess_back   = backurl_getlast("$sess_reload");
         my $retc        = 0;
         if ( params->{'OK'} ) {
            $logger->trace("$ll  OK Button");
            $logger->trace("$ll  marksrv: $marksrvhash");
            foreach my $srvid ( keys %$marksrvhash ) {
               my $server = $marksrvhash->{$srvid}{'db_srv'};
               $logger->debug("$ll   power on server $server");
               my $command = $global{'progdir'} . "/fsic.pl -q --srvon $server -l $global{'logdir'}/fsi";
               $logger->trace("$ll  cmd: [$command]");
               my $eo = qx($command  2>&1);
               $retc = $?;
               $retc = $retc >> 8 unless ( $retc == -1 );
               unless ($retc) {
                  $logger->trace("$ll  ok");
               } else {
                  $logger->error("failed cmd [$eo]");
                  $errmsg = "Cannot power on $server";
                  last;
               }
            }                                                                                                                      # Schleife aller server die ausgewählt worden sind
            unless ($retc) {
               if ( $srvcount > 1 ) {
                  set_flash("!S:Power on multiple server successful: $srvnames");
               } else {
                  set_flash("!S:Power on server successful: $srvnames");
               }
            } else {
               if ( $srvcount > 1 ) {
                  set_flash("!E:ERROR power on multiple server: $errmsg");
               } else {
                  set_flash("!E:ERROR power on server: $errmsg");
               }
            } ## end else
         } else {
            if ( $srvcount > 1 ) {
               set_flash("!W:Abort power on multiple server: $srvnames");
            } else {
               set_flash("!W:Abort power on server: $srvnames");
            }
         } ## end else [ if ( params->{'OK'} ) ]
         redirect $sess_back;
      } else {                                                                                                                     # get - Darstellung Liste ausgewählter Server
         my $sess_reload = "/ponsrvmark";
         $logger->trace("$ll  set reload: $sess_reload");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload");
         $retc = backurl_add("$sess_reload");

         template 'mark/ponsrv',
           {
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'},
             'entries' => $marksrvhash, };
      } ## end else [ if ( request->method() eq "POST" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
