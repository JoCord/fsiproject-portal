any [ 'get', 'post' ] => '/showsrv/:srvid' => sub {
   my $weburl = '/showsrv';
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
         $logger->debug("$ll  GET Section  [" . session('user') . "]");
         my %params = params;

         my $srvpath="";
         my $srvhash_ref;                                                                                                          # server hash reference with info for ESXi, Xen or CentOS server

         my $srvid   = params->{srvid};
         $logger->trace("$ll  server id: $srvid  [" . session('user') . "]");
         
         my $sess_reload = $weburl . "/$srvid";
         $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
         $retc = backurl_add("$sess_reload");

         my $retc = db_reload();
         unless ($retc) {
            $logger->trace("$ll  reload db ok  [" . session('user') . "]");
         
   
            my $server = $serverhash_p->{$srvid}{'db_srv'};                                                                           # auslesen hash eintrag aus hash referenz
            $logger->trace("  server: $server  [" . session('user') . "]");
            my $typ = $serverhash_p->{$srvid}{'db_typ'};
            $logger->trace("  typ: $typ  [" . session('user') . "]");
            my $srv_control = $serverhash_p->{$srvid}{'db_control'};
            $logger->trace("  control: $srv_control  [" . session('user') . "]");
            
                        
            $logger->debug("$ll   test if server online  [" . session('user') . "]");
            my $p = Net::Ping->new( $global{'pingprot'} );
            
   
            if ( $p->ping($server) ) {
               $logger->trace("$ll server $server connected - can get new server infos  [" . session('user') . "]");
            } else {
               $logger->warn("$ll  server [$server] is offline - cannot get detail information  [" . session('user') . "]");
               set_flash("!W:server [$server] is offline");
            }
               
                  
            unless ( $retc ) {
               if ( $typ =~ m/^esxi/ ) {
                  $srvpath="$global{'fsiinstdir'}/$typ/ks/log/info/$server";
               } elsif ( $typ =~ m/^xen/ ) {
                  $srvpath="$global{'fsiinstdir'}/$typ/ks/pool/$srv_control/info/$server";
               } elsif ( $typ =~ m/^co/ ) {
                  $srvpath="$global{'fsiinstdir'}/$typ/ks/log/info/$server";
               } elsif ( $typ =~ m/^rh/ ) {
                  $srvpath="$global{'fsiinstdir'}/$typ/ks/log/info/$server";
               } else {
                  $logger->error("unsupported srv [$server] typ found [$typ] !  [" . session('user') . "]");
                  set_flash("!E:$errmsg");
                  $retc = 99;
               }
            }

            if ( "$srvpath" ne "" ) {               
               $logger->trace("$ll  srvpath: $srvpath  [" . session('user') . "]");
               unless ( -f "$srvpath/info.last" ) {
                  $logger->debug("$ll no last pool data exist  [" . session('user') . "]");
                  $retc = get_srv_data_fork($server,$srvpath,$typ);
                  if ($retc) {
                     $errmsg = "fork getting server [$server] data failed";
                     $logger->warn("$errmsg  [" . session('user') . "]");
                     set_flash("!E:$errmsg");
                  }
               } else {
                  $logger->trace("$ll old srv data exist - to old?  [" . session('user') . "]");
                  if ( status_last_2old( "$srvpath/info.last" ) ) {
                     $logger->debug("$ll last srv data to old  [" . session('user') . "]");
                     $retc = get_srv_data_fork($server,$srvpath,$typ);
                     if ($retc) {
                     $errmsg = "fork getting server [$server] data failed";
                        $logger->error("$errmsg  [" . session('user') . "]");
                        set_flash("!E:$errmsg");
                     }
                  } else {
                     $logger->debug("$ll start getting all current server data  [" . session('user') . "]");
                     if ( -f "$srvpath/info.server" ) {
                        $logger->debug("$ll  info.server data file exist - read it  [" . session('user') . "]");
                        $srvhash_ref=readjsonfile("$srvpath/info.server");
                     } else { 
                        $logger->debug("$ll  no info.server data file exist - ignore  [" . session('user') . "]");
                     }
                  } 
               } ## end else
            } 
               
   
            if ($logger->is_trace()) {
               my $dumpout=Dumper($serverhash_p->{$srvid});
               $logger->trace("$ll Server-Dump: $dumpout  [" . session('user') . "]");  
            }
   
            template 'show_srv.tt', 
            {
                'msg'      => get_flash(),
                'version'  => $ver,
                'server'   => $server,
                'vitemp'   => $host,
                'srvid'    => $srvid,
                'entries'  => $serverhash_p->{$srvid},
                'rzconfig' => \%rzconfig,
                'srvhash'  => $srvhash_ref,
                'bldlvl'   => \%bldlvl_h,
                'vienv'    => $global{'vienv'}, };
         } else {
            set_flash("!E:cannot read server id:$srvid config");
            my $sess_back = backurl_getlast("$sess_reload");
            $logger->debug("$ll  go back to $sess_back  [" . session('user') . "]");
            return redirect $sess_back;
         }
        
            
      } elsif ( request->method() eq "POST" ) {
         $logger->debug("$ll  POST Section  [" . session('user') . "]");
         my %params      = params;
         my $sess_reload = session('reload');
         $retc = backurl_add("$sess_reload");

         my $retc = db_reload();

         if ( params->{'Logout'} ) {
            $logger->info("$ll  logout  [" . session('user') . "]");
            return redirect '/logout';
         } elsif ( params->{'Back'} ) {
            my $sess_back = backurl_getlast("$sess_reload");
            $logger->debug("$ll  go back to $sess_back  [" . session('user') . "]");
            return redirect $sess_back;

         } elsif ( params->{'DelReadFlag'} ) {
            my $srvid=params->{'DelReadFlag'};
            $logger->trace("$ll  server id: $srvid  [" . session('user') . "]");
            
            my $server = $serverhash_p->{$srvid}{'db_srv'};                                                                           # auslesen hash eintrag aus hash referenz
            $logger->trace("  server: $server  [" . session('user') . "]");
            my $typ = $serverhash_p->{$srvid}{'db_typ'};
            $logger->trace("  typ: $typ  [" . session('user') . "]");
            my $srv_control = $serverhash_p->{$srvid}{'db_control'};
            $logger->trace("  control: $srv_control  [" . session('user') . "]");
            
            my $srvpath="";
            unless ( $retc ) {
               if ( $typ =~ m/^esxi/ ) {
                  $srvpath="$global{'fsiinstdir'}/$typ/ks/log/info/$server";
               } elsif ( $typ =~ m/^xen/ ) {
                  $srvpath="$global{'fsiinstdir'}/$typ/ks/pool/$srv_control/info/$server";
               } elsif ( $typ =~ m/^co/ ) {
                  $srvpath="$global{'fsiinstdir'}/$typ/ks/log/info/$server";
               } elsif ( $typ =~ m/^rh/ ) {
                  $srvpath="$global{'fsiinstdir'}/$typ/ks/log/info/$server";
               } else {
                  $errmsg="unsupported srv [$server] typ found [$typ] !";
                  $logger->error("$errmsg  [" . session('user') . "]");
                  set_flash("!E:$errmsg");
                  $retc = 99;
               }
            }

            if ( "$srvpath" ne "" ) {               
               $flagfile="$srvpath/info.last";
               unless ( unlink($flagfile) ) {
                  $logger->debug("$ll  $flagfile does not exist - do not need to delete!  [" . session('user') . "]");
               } else {
                  $logger->debug("$ll  $flagfile deleted!  [" . session('user') . "]");
               }
            } 
            redirect $sess_reload;
            
         } elsif ( params->{'Reload'} ) {
            return redirect $sess_reload;
         } elsif ( params->{'UpdateVIScriptsESXi'} ) {
            my $srv = params->{'UpdateVIScriptsESXi'};
            $logger->debug("$ll  update and deploy vi tool scripts on $srv  [" . session('user') . "]");

            # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
            my $addcmd = 'copy vi tools ' . $srv . ',copy vi tools to esxi server ' . $srv . ',' . session('user') . ',myShowTask,TASKID,' . $srv . ',srv,yes';
            $logger->trace("$ll cmd: $addcmd  [" . session('user') . "]");
            $taskid = task_add($addcmd);
            if ($taskid) {
               $logger->trace("$ll  fork now  [" . session('user') . "]");
               set_flash("!I:Start copy vi scripts to [$srv] ...");
               fork and return redirect $sess_reload;
               my $tasklog = $global{'logdir'} . "/task-" . $taskid;
               $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
               $retc = tasklog_add($tasklog);
               my $retc = deploy_scripts( 'ESXi', $srv, $tasklog );
               $logger->debug("$ll  delete task  [" . session('user') . "]");
               $retc = task_del( $taskid, 'yes' );
               $logger->trace("$ll  delete task log file  [" . session('user') . "]");
               $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
               $retc = tasklog_remove($tasklog);

               # if fork - than exit here
               exit;
            } else {
               set_flash("!E:Server $srv cannot get new task id ");
            }
            return redirect $sess_reload;
         } elsif ( params->{'UpdateVIScriptsXEN'} ) {
            my $srv = params->{'UpdateVIScriptsXEN'};
            $logger->debug("$ll  update and deploy vi tool scripts on $srv  [" . session('user') . "]");

            # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
            my $addcmd = 'copy vi tools ' . $srv . ',copy vi tools to esxi server ' . $srv . ',' . session('user') . ',myShowTask,TASKID,' . $srv . ',srv,yes';
            $logger->trace("$ll cmd: $addcmd  [" . session('user') . "]");
            $taskid = task_add($addcmd);
            if ($taskid) {
               $logger->trace("$ll  fork now  [" . session('user') . "]");
               set_flash("!I:Start copy vi scripts to [$srv] ...");
               fork and return redirect $sess_reload;
               my $tasklog = $global{'logdir'} . "/task-" . $taskid;
               $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
               $retc = tasklog_add($tasklog);
               my $retc = deploy_scripts( 'XEN', $srv, $tasklog );
               $logger->debug("$ll  delete task  [" . session('user') . "]");
               $retc = task_del( $taskid, 'yes' );
               $logger->trace("$ll  delete task log file  [" . session('user') . "]");
               $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
               $retc = tasklog_remove($tasklog);

               # if fork - than exit here
               exit;
            } else {
               set_flash("!E:Server $srv cannot get new task id ");
            }
            return redirect $sess_reload;
         } elsif ( params->{'EditFile'} ) {
            my $parameter = params->{'EditFile'};
            $logger->trace("$ll  parameter: $parameter  [" . session('user') . "]");
            my ( $file, $srv, $fileformat ) = split( ':', $parameter );
            $logger->debug("$ll  edit config file $file for $srv  [" . session('user') . "]");
            if ( -f "$file" ) {
               if ( "$fileformat" eq "" ) {
                  $fileformat='text';
               }
               $logger->trace("$ll  found file - open editor  [" . session('user') . "]");
               session 'edit_file'   => $file;
               session 'edit_ctrl'   => 'srv';
               session 'edit_what'   => $srv;
               session 'edit_format' => $fileformat;
               session 'backsik'     => $back;

               # session 'back'        => session('reload');
               return redirect "/editfile";
            } else {
               $logger->warn("$ll  cannot find file $file - abort  [" . session('user') . "]");
               set_flash("!E:Error - cannot find config file for $srv");
            }
            return redirect $sess_reload;
         } elsif ( params->{'Overview'} ) {
            return redirect "/overview";
         } else {
            return redirect $back;
         }
      } else {
         template 'error',
           {
             'msg'     => "unknown method in /showsrv",
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'}, };
      } ## end else [ if ( request->method() eq "GET" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
