any [ 'get', 'post' ] => '/overviewxenpools' => sub {
   my $weburl = '/overviewxenpools';
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
            $logger->trace("$ll  create xen pool hash  [" . session('user') . "]");
            my $xphash_p;
            my $srvcount;
            foreach my $srvid ( sort { lc $a cmp lc $b } keys %{$serverhash_p} ) {
               if ( "$serverhash_p->{$srvid}{'db_controltyp'}" eq "xp" ) {
                  my $poolname = $serverhash_p->{$srvid}{'db_control'};

                  # $logger->trace("$ll pool: $poolname   [" . session('user') . "]");
                  $xphash_p->{$poolname}{'count'}++;                                                                               # add hash-key if not exist and if add 1
                  $srvcount++;

                  if ( defined $xphash_p->{$poolname}{'xenver'} ) {
                     if ( "$serverhash_p->{$srvid}{'db_typ'}" ne "$xphash_p->{$poolname}{'xenver'}" ) {
                        $logger->warn("$ll  xenserver version differ in pool $poolname  [" . session('user') . "]");
                        $xphash_p->{$poolname}{'xenverdiffer'} = 1;
                     }
                  } ## end if ( defined $xphash_p->{$poolname}{'xenver'} )
                  if ( defined $xphash_p->{$poolname}{'patchlvl'} ) {
                     if ( "$serverhash_p->{$srvid}{'s_patchlevel'}" ne "" && "$xphash_p->{$poolname}{'patchlvl'}" ne "" ) {
                        $logger->trace("$ll  level: [$serverhash_p->{$srvid}{'s_patchlevel'}] [$xphash_p->{$poolname}{'patchlvl'}]  [" . session('user') . "]");
                        if ( "$serverhash_p->{$srvid}{'s_patchlevel'}" ne "$xphash_p->{$poolname}{'patchlvl'}" ) {
                           $logger->warn("$ll  xenserver patchlevel differ in pool $poolname  [" . session('user') . "]");
                           $xphash_p->{$poolname}{'patchlvldiffer'} = 1;
                        }
                     } ## end if ( "$serverhash_p->{$srvid}{'s_patchlevel'}" ne "" && "$xphash_p->{$poolname}{'patchlvl'}" ne "" )
                  } ## end if ( defined $xphash_p->{$poolname}{'patchlvl'} )

                  if ( "$serverhash_p->{$srvid}{'s_block'}" eq "B" ) {
                     $logger->debug("$ll  pool $poolname is blocked  [" . session('user') . "]");
                     $xphash_p->{$poolname}{'block'} = $serverhash_p->{$srvid}{'s_block'};
                  }
                  if ( "$serverhash_p->{$srvid}{'s_instrun'}" eq "R" ) {
                     $logger->debug("$ll  pool $poolname a installation is running  [" . session('user') . "]");
                     $xphash_p->{$poolname}{'instrun'} = $serverhash_p->{$srvid}{'s_instrun'};
                  }

                  if ( !defined $xphash_p->{$poolname}{'masterxenver'} ) {
                     $xphash_p->{$poolname}{'xenver'}   = $serverhash_p->{$srvid}{'db_typ'};
                     $xphash_p->{$poolname}{'patchlvl'} = $serverhash_p->{$srvid}{'s_patchlevel'};
                  }

                  if ( "$serverhash_p->{$srvid}{'s_xenmaster'}" eq "M" ) {
                     $xphash_p->{$poolname}{'master'}         = "$serverhash_p->{$srvid}{'db_srv'}";
                     $xphash_p->{$poolname}{'masterid'}       = "$srvid";
                     $xphash_p->{$poolname}{'masterxenver'}   = $serverhash_p->{$srvid}{'db_typ'};
                     $xphash_p->{$poolname}{'xenver'}         = $serverhash_p->{$srvid}{'db_typ'};
                     $xphash_p->{$poolname}{'patchlvl'}       = $serverhash_p->{$srvid}{'s_patchlevel'};
                     $xphash_p->{$poolname}{'masterpatchlvl'} = $serverhash_p->{$srvid}{'s_patchlevel'};
                  } ## end if ( "$serverhash_p->{$srvid}{'s_xenmaster'}" eq "M" )

               } ## end if ( "$serverhash_p->{$srvid}{'db_controltyp'}" eq "xp" )
            } ## end foreach my $srvid ( sort { lc $a cmp lc $b } keys %{$serverhash_p} )
            my $poolcount = keys %{$xphash_p};
            if ( $global{'logprod'} < 10000 ) {
               my $dumpout = Dumper( \$xphash_p );
               $logger->trace("$ll Overview-Dump: $dumpout");
            }
            $logger->info("$ll  show xenserver pools overview  [" . session('user') . "]");
            template 'overviewxenpools.tt',
              {
                'msg'      => get_flash(),
                'xp'       => $xphash_p,
                'srvcount' => $srvcount,
                'xpcount'  => $poolcount,
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
            $logger->trace("$ll Overview-Dump: $dumpout");
         }
         if ( params->{'Logout'} ) {
            $logger->info("$ll  logout  [" . session('user') . "]");
            return redirect '/logout';
         } elsif ( params->{'Reload'} ) {
            $logger->info("$ll  reload xenpool view  [" . session('user') . "]");
            redirect $weburl;
         } else {
            $logger->error("no xenserver found for pool overview  [" . session('user') . "]");
            error "no xenserver server for pool overview";
            template 'error',
              {
                'msg'     => "no xenserver server for pool overview",
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
