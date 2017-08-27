any [ 'get', 'post' ] => '/overviewlx' => sub {
   my $weburl = '/overviewlx';
   session 'now' => $weburl;
   local *__ANON__ = "dance: $weburl";                                                                                             # default if no function for caller sub
   $flvl=2;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: $weburl");
   my $retc   = 0;
   my $errmsg = "";

   if ( !session('logged_in') ) {
      $logger->info("$ll  redirect to root web site / ");
      return redirect '/';
   } else {
      if ( request->method() eq "GET" ) {
         my $sess_reload = $weburl;
         session 'reload' => $sess_reload;
         $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
         $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
         $retc = backurl_add("$sess_reload");
         my $retc = db_reload();
         unless ($retc) {
            $logger->debug("  reload db ok  [" . session('user') . "]");
            $logger->trace("$ll  create linux hash  [" . session('user') . "]");
            my $lxhash_p;
            my $srvcount;
            foreach my $srvid ( sort { lc $a cmp lc $b } keys %{$serverhash_p} ) {
               if ( "$serverhash_p->{$srvid}{'db_controltyp'}" eq "lx" ) {
                  $srvcount++;
                  my $lxmodel    = $serverhash_p->{$srvid}{'db_control'};
                  my $lxver      = $serverhash_p->{$srvid}{'db_typ'};
                  my $lxversions = $lxhash_p->{$lxmodel}{'lxversions'};
                  unless ( $lxversions =~ /$lxver/ ) {                                                                             # new lx version for this model
                     $lxversions = "$lxhash_p->{$lxmodel}{'lxversions'}, $lxver";
                     if ( substr( $lxversions, 0, 2 ) eq ", " ) {
                        $lxversions = substr( $lxversions, 1, length($lxversions) - 1 );
                     }
                     $lxhash_p->{$lxmodel}{'lxversions'} = $lxversions;
                  } ## end unless ( $lxversions =~ /$lxver/ )
                  $logger->trace("$ll model: $lxmodel   [" . session('user') . "]");
                  $lxhash_p->{$lxmodel}{'count'}++;                                                                                # add hash-key if not exist and if add 1
               } ## end if ( "$serverhash_p->{$srvid}{'db_controltyp'}" eq "lx" )
            } ## end foreach my $srvid ( sort { lc $a cmp lc $b } keys %{$serverhash_p} )
            my $lxcount = keys %{$lxhash_p};
            if ( $global{'logprod'} < 10000 ) {
               my $dumpout = Dumper( \$lxhash_p );
               $logger->trace("$ll Overview-Dump: $dumpout  [" . session('user') . "]");
            }
            $logger->info("$ll  show linux server overview  [" . session('user') . "]");
            template 'overviewlx.tt',
              {
                'msg'      => get_flash(),
                'lx'       => $lxhash_p,
                'srvcount' => $srvcount,
                'lxcount'  => $lxcount,
                'version'  => $ver,
                'vitemp'   => $host,
                'vienv'    => $global{'vienv'}, };
         } else {
            $logger->error("cannot reload db - abort  [" . session('user') . "]");
            template 'error',
              {
                'msg'     => "cannot reload db",
                'version' => $ver,
                'vitemp'  => $host,
                'vienv'   => $global{'vienv'}, };
         } ## end else
      } elsif ( request->method() eq "POST" ) {
         $logger->info("$ll  POST section  [" . session('user') . "]");
         my %params = params;
         if ( $global{'logprod'} < 10000 ) {
            my $dumpout = Dumper( \%params );
            $logger->trace("$ll Overview-Dump: $dumpout  [" . session('user') . "]");
         }
         if ( params->{'Logout'} ) {
            $logger->info("$ll  logout  [" . session('user') . "]");
            return redirect '/logout';
         } elsif ( params->{'Reload'} ) {
            $logger->info("$ll  reload overview  [" . session('user') . "]");
            redirect $weburl;
         } else {
            $logger->error("no server found for overview  [" . session('user') . "]");
            error "no linux server found";
            template 'error',
              {
                'msg'     => "no server in /overview",
                'version' => $ver,
                'vitemp'  => $host,
                'vienv'   => $global{'vienv'}, };
         } ## end else [ if ( params->{'Logout'} ) ]
      } else {
         $logger->error("unknown method for fsi  [" . session('user') . "]");
         template 'error',
           {
             'msg'     => "unknown method in /overview",
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'}, };
      } ## end else [ if ( request->method() eq "GET" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
