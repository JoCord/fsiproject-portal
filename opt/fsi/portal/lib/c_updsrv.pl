any [ 'get', 'post' ] => '/updsrvmark' => sub {
   my $weburl = '/updsrvmark';
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
         $logger->debug("$ll  POST Section");
         my %params      = params;
         my $sess_reload = session('reload');
         my $sess_back   = backurl_getlast("$sess_reload");
         if ( params->{'OK'} ) {
            $logger->trace("$ll  OK Button");
            $logger->trace("$ll  marksrv: $marksrvhash");
            foreach my $srvid ( keys %$marksrvhash ) {
               my $server     = $marksrvhash->{$srvid}{'db_srv'};
               my $control    = $marksrvhash->{$srvid}{'db_control'};
               my $controltyp = $marksrvhash->{$srvid}{'db_controltyp'};
               my $autoreboot = "no";
               if ( params->{'AutoReboot'} ){
                  $autoreboot = "yes";
               }
               $logger->debug("$ll  call sub routine to update server: $server, $control, $controltyp, [$autoreboot]");
               $retc = portal_upd_srv( $server, $control, $controltyp, $autoreboot );
               if ($retc) {
                  $logger->error("cannot update srv $server");
                  $errmsg = $server;
                  last;
               }
            }                                                                                                                      # Schleife aller server die ausgewählt worden sind
            unless ($retc) {
               if ( $srvcount > 1 ) {
                  set_flash("!S:Start updating multiple server successful: $srvnames");
               } else {
                  set_flash("!S:Start updating server successful: $srvnames");
               }
            } else {
               if ( $srvcount > 1 ) {
                  set_flash("!E:ERROR updating multiple server: $errmsg");
               } else {
                  set_flash("!E:ERROR updating server: $errmsg");
               }
            } ## end else
         } else {
            if ( $srvcount > 1 ) {
               set_flash("!W:Abort updating multiple server: $srvnames");
            } else {
               set_flash("!W:Abort updating server: $srvnames");
            }
         } ## end else [ if ( params->{'OK'} ) ]
         $logger->trace("$ll  jump back to [$sess_back]");
         redirect $sess_back;
      } else {
         my $sess_reload = $weburl;
         $logger->trace("$ll  set reload: $sess_reload");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload");
         $retc = backurl_add("$sess_reload");

         template 'mark/updsrv',
           {
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'},
             'entries' => $marksrvhash, };
      } ## end else [ if ( request->method() eq "POST" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
