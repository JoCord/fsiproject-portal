any [ 'get', 'post' ] => '/delsrvmark' => sub {
   my $weburl = '/delsrvmark';
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
         $marksrvhash->{$c}{'dbid'} = $x;                                                                             # original ID !!!!
         $c++;
         $srvnames = "$srvnames $serverhash_p->{$x}{'db_srv'}";
      } ## end foreach $x (@markedsrv)

      if ( request->method() eq "POST" ) {
         $logger->trace("$ll  POST Section");
         my $sess_reload = session('reload');
         my $sess_back   = backurl_getlast("$sess_reload");
         my $retc        = 0;
         if ( params->{'OK'} ) {
            $logger->trace("$ll  OK Button");
            $logger->trace("$ll  marksrv: $marksrvhash");
            foreach my $srvid ( keys %$marksrvhash ) {
               my $mac = $marksrvhash->{$srvid}{'db_mac'};
               $logger->trace("$ll  mac: $mac");
               my $typ = $marksrvhash->{$srvid}{'db_typ'};
               $logger->trace("$ll  typ: $typ");
               my $pool = $marksrvhash->{$srvid}{'db_control'};
               $logger->trace("$ll  pool: $pool");
               $logger->trace("$ll  id: $srvid");
               $logger->info("$ll  delete server $marksrvhash->{$srvid}{'db_srv'} with db id=$marksrvhash->{$srvid}{'dbid'}");
               $retc = portal_del_srv( $mac, $typ, $pool, $marksrvhash->{$srvid}{'dbid'}, $marksrvhash->{$srvid}{'db_srv'} );

               if ($retc) {
                  $logger->error("removing srv $marksrvhash->{$srvid}{'db_srv'}");
                  $errmsg = $marksrvhash->{$srvid}{'db_srv'};
                  last;
               }
            }                                                                                                                      # Schleife aller server die ausgewählt worden sind
            unless ($retc) {
               $logger->trace("$ll check all symlinks");
               my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--sym", "-l", "$global{'logdir'}/fsi" );
               $retc = system(@command);
               if ( $retc == 0 ) {
                  $logger->trace("$ll check symlink ok");
               } else {
                  $errrmsg = "Error [$retc] checking symlink - please inform js";
                  $logger->error($errmsg);
               }
            } ## end unless ($retc)
            unless ($retc) {
               if ( $srvcount > 1 ) {
                  set_flash("!S:Removing multiple server configurations successful: $srvnames");
               } else {
                  set_flash("!S:Removeing server configuration successful: $srvnames");
               }
            } else {
               if ( $srvcount > 1 ) {
                  set_flash("!E:ERROR removing multiple server configurations - server: $errmsg");
               } else {
                  set_flash("!E:ERROR removing server configuration - server: $errmsg");
               }
            } ## end else
         } else {
            if ( $srvcount > 1 ) {
               set_flash("!W:Abort removing multiple server configurations: $srvnames");
            } else {
               set_flash("!W:Abort removing server configuration: $srvnames");
            }
         } ## end else [ if ( params->{'OK'} ) ]
         redirect $sess_back;
      } else {
         my $sess_reload = "/delsrvmark";
         $logger->trace("$ll  set reload: $sess_reload");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload");
         $retc = backurl_add("$sess_reload");

         template 'mark/delsrv',
           {
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'},
             'entries' => $marksrvhash, };
      } ## end else [ if ( request->method() eq "POST" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
