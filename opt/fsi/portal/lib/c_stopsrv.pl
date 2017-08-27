any [ 'get', 'post' ] => '/stopsrvmark' => sub {
   my $weburl = '/stopsrvmark';
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
               $logger->info("$ll   abort installation of $server");
               my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--abort", $server, "-l", "$global{'logdir'}/fsi" );
               $retc = system(@command);
               if ( $retc == 0 ) {
                  $logger->trace("$ll abort $server installation ok");
               } else {
                  $errrmsg = "Error [$retc] aborting installation";
                  $logger->error($errmsg);
               }
            }                                                                                                                      # Schleife aller server die ausgewählt worden sind
            unless ($retc) {
               if ( $srvcount > 1 ) {
                  set_flash("!S:Stopping multiple server installation successful: $srvnames");
               } else {
                  set_flash("!S:Stopping server installation successful: $srvnames");
               }
            } else {
               if ( $srvcount > 1 ) {
                  set_flash("!E:ERROR stopping multiple server installation: $errmsg");
               } else {
                  set_flash("!E:ERROR stopping server installation: $errmsg");
               }
            } ## end else
         } else {
            if ( $srvcount > 1 ) {
               set_flash("!W:Abort stopping multiple server installation: $srvnames");
            } else {
               set_flash("!W:Abort stopping server installation: $srvnames");
            }
         } ## end else [ if ( params->{'OK'} ) ]
         redirect $sess_back;
      } else {                                                                                                                     # get - Darstellung Liste ausgewählter Server
         my $sess_reload = $weburl;
         $logger->trace("$ll  set reload: $sess_reload");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload");
         $retc = backurl_add("$sess_reload");

         template 'mark/stopsrv',
           {
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'},
             'entries' => $marksrvhash, };
      } ## end else [ if ( request->method() eq "POST" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
