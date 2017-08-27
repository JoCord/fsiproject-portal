any [ 'get', 'post' ] => '/instsrvmark' => sub {
   my $weburl = '/instsrvmark';
   session 'now' => $weburl;
   local *__ANON__ = "dance: $weburl";                                                                                             # default if no function for caller sub
   my $fc = ( caller(0) )[ 3 ];
   $logger->trace("$ll func start: $fc");
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

         if ( params->{'OK'} ) {
            $logger->trace("$ll  OK Button");
            $logger->trace("$ll  marksrv: $marksrvhash");
            foreach my $srvid ( keys %$marksrvhash ) {
               $logger->info("$ll   start installation of $marksrvhash->{$srvid}{'db_srv'}");

               $retc = portal_inst_srv( $marksrvhash->{$srvid}{'db_srv'} );
               if ($retc) {
                  $logger->error("cannot start installation of srv $marksrvhash->{$srvid}{'db_srv'}");
                  $errmsg = $marksrvhash->{$srvid}{'db_srv'};
                  last;
               }
            }                                                                                                                      # Schleife aller server die ausgewählt worden sind

            $logger->trace("$ll  server count: $srvcount");
            unless ($retc) {
               if ( $srvcount > 1 ) {
                  set_flash("!S:Start multiple server installation successful: $srvnames");
               } else {
                  set_flash("!S:Start server installation successful: $srvnames");
               }
            } else {
               if ( $srvcount > 1 ) {
                  set_flash("!E:ERROR starting multiple server installation - server: $errmsg");
               } else {
                  set_flash("!E:ERROR starting server installation - server: $errmsg");
               }
            } ## end else
         } else {
            if ( $srvcount > 1 ) {
               set_flash("!W:Abort multiple server installation: $srvnames");
            } else {
               set_flash("!W:Abort server installation: $srvnames");
            }
         } ## end else [ if ( params->{'OK'} ) ]
         $logger->debug("$ll  go back to [$sess_back]");
         redirect $sess_back;
      } else {                                                                                                                     # get - Darstellung Liste ausgewählter Server
         $logger->debug("$ll  GET Section");
         my %params = params;

         my $sess_reload = $weburl;
         $logger->trace("$ll  set reload: $sess_reload");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload");
         $retc = backurl_add("$sess_reload");

         template 'mark/instsrv',
           {
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'},
             'entries' => $marksrvhash, };
      } ## end else [ if ( request->method() eq "POST" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
