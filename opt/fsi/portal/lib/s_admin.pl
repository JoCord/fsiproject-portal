any [ 'get', 'post' ] => '/admin/:cmd' => sub {
   my $weburl = '/admin';
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
      my $sess_reload = "/admin/show";
      $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
      session 'reload' => $sess_reload;
      my $admincmd = params->{cmd};
      if ( "$admincmd" eq "admin" ) {
         $logger->trace("$ll  reset admin command to show  [" . session('user') . "]");
         $admincmd = "show";
      }
      if ( ( request->method() eq "GET" ) || ( request->method() eq "POST" ) ) {
         my %params = params;
         $logger->info("$ll  enter admin area: $sess_reload  [" . session('user') . "]");

         if($global{'logprod'} < 10000) {
            my $dumpout = Dumper( \%params );
            $logger->trace("$ll Admin Return Dump: $dumpout  [" . session('user') . "]");
         }

         $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
         $retc = backurl_add("$sess_reload");
         if ( params->{'Logout'} ) {
            $logger->info("$ll  logout  [" . session('user') . "]");
            return redirect '/logout';
         } elsif ( params->{'CleanSSHKeysXen'} ) {
            $logger->debug("$ll  clean ssh keys  [" . session('user') . "]");
            my $rc = clean_ssh_keys_xen();
            return redirect $sess_reload;
         } elsif ( params->{'CleanSSHKeysESXi'} ) {
            $logger->debug("$ll  clean ssh keys  [" . session('user') . "]");
            my $rc = clean_ssh_keys_esxi();
            return redirect $sess_reload;
         } elsif ( ( params->{'dbnew'} ) || ( $admincmd eq "dbnew" ) ) {
            my $retc = 0;
            my @command = ( "service", "fsi", "stopd" );
            $retc = system(@command);
            if ( $retc == 0 ) {
               $logger->trace("$ll  stop fsi daemon  [" . session('user') . "]");
            } else {
               set_flash("!E:Error [$retc] stopping fsi daemon");
            }
            @command = ( "service", "fsi", "stopo" );
            $retc = system(@command);
            if ( $retc == 0 ) {
               $logger->trace("$ll  stop fsi check online daemon  [" . session('user') . "]");
            } else {
               set_flash("!E:Error [$retc] stopping fsi check online daemon");
            }
            @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--new", "-l", "$global{'logdir'}/fsi" );
            $retc = system(@command);
            if ( $retc == 0 ) {
               set_flash("!S:Complete recreate a new db");
            } else {
               set_flash("!E:Error [$retc] creating new db - please inform js");
            }
            @command = ( "service", "fsi", "startd" );
            $retc = system(@command);
            if ( $retc == 0 ) {
               $logger->trace("$ll  start fsi daemon  [" . session('user') . "]");
            } else {
               set_flash("!E:Error [$retc] starting fsi daemon");
            }
            @command = ( "service", "fsi", "starto" );
            $retc = system(@command);
            if ( $retc == 0 ) {
               $logger->trace("$ll  start fsi check online daemon  [" . session('user') . "]");
            } else {
               set_flash("!E:Error [$retc] starting fsi check online daemon");
            }
            return redirect backurl_getlast("$sess_reload");
         } elsif ( ( params->{'dbdel'} ) || ( $admincmd eq "dbdel" ) ) {
            my $retc = 0;
            my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--deldb", "-l", "$global{'logdir'}/fsi" );
            $retc = system(@command);
            if ( $retc == 0 ) {
               set_flash("!S:Complete delete db - please stay in admin menu until new db created");
            } else {
               set_flash("!E:Error [$retc] deleting db - please inform js");
            }
            return redirect backurl_getlast("$sess_reload");
         } elsif ( params->{'edituser'} ) {
            my $retc = 0;
            return redirect '/user';
         } elsif ( params->{'usersessions'} ) {
            my $retc = 0;
            return redirect '/usersessions';
         } elsif ( params->{'ImportSrv'} ) {
            my $retc       = 0;
            my $filesource = params->{'file'};
            if ( "$filesource" eq "" ) {
               $logger->trace("$ll  no file choosen - ignore  [" . session('user') . "]");
               set_flash("!W:No import file choosen, please select a file first");
            } else {
               $logger->debug("$ll  import file $filesource  [" . session('user') . "]");
               my $file       = request->upload('file');
               my $fileinhalt = $file->content;
               my @filelines  = split( "\n", $fileinhalt );
               my $msg        = "";
               foreach my $line (@filelines) {
                  $retc = import_server($line);
                  if ($retc) {
                     $logger->error("error importing server - abort  [" . session('user') . "]");
                     last;
                  }
               } ## end foreach my $line (@filelines)
               unless ($retc) {
                  set_flash("!S:Import server succesfull");
               }
            } ## end else [ if ( "$filesource" eq "" ) ]
            return redirect $sess_reload;
         } elsif ( params->{'DelRubbish'} ) {
            my $retc = 0;
            $retc = delete_path( $global{'rubbishdir'} );
            if ( $retc == 0 ) {
               $retc = create_path( $global{'rubbishdir'}, 0755 );
               if ( $retc == 0 ) {
                  set_flash("!S:Rubbish cleaned");
               } else {
                  $logger->error("$ll  cannot create rubbish dir [$retc]  [" . session('user') . "]");
                  set_flash("!E:Error recreating rubbish");
                  $retc = 99;
               }
            } else {
               $logger->error("$ll  cannot remove rubbish dir [$retc]  [" . session('user') . "]");
               set_flash("!E:Error empty rubbish");
            }
            return redirect $sess_reload;
         } elsif ( params->{'vchealth'} ) {
            my $retc = 0;
            return redirect '/showvc';
         } elsif ( params->{'cdblog'} ) {
            my $retc = 0;
            return redirect '/showcdblog';
         } elsif ( params->{'fsiNew'} ) {
            my $retc    = 0;
            my @command = ("fsictl new");
            $logger->trace("$ll  cmd: fsictl new  [" . session('user') . "]");
            set_flash("!W:fsi portal is recreating config now - please wait a few seconds ...");
            fork and return redirect $sess_reload;
            $retc = system(@command);
            exit 0;
         } elsif ( params->{'fsiRestart'} ) {
            my $retc    = 0;
            my @command = ("fsictl restart");
            $logger->trace("$ll  cmd: fsictl restart  [" . session('user') . "]");
            set_flash("!W:fsi portal is restarting now - please wait a few seconds ...");
            fork and return redirect $sess_reload;
            $retc = system(@command);
            exit 0;
         } elsif ( params->{'fsiRestartPortal'} ) {
            my $retc    = 0;
            my @command = ("fsictl restartp");
            $logger->trace("$ll  cmd: fsictl restartp  [" . session('user') . "]");
            set_flash("!W:fsi portal is restarting  - please wait a few seconds and then reload browser windows");
            fork and return redirect $sess_reload;
            $retc = system(@command);
            exit 0;
         } elsif ( params->{'fsiRestartCheck'} ) {
            my $retc    = 0;
            my @command = ("fsictl restartd");
            $logger->trace("$ll  cmd: fsictl restartd  [" . session('user') . "]");
            set_flash("!W:fsi check daemon is restarting ...");
            fork and return redirect $sess_reload;
            $retc = system(@command);
            exit 0;
         } elsif ( params->{'fsiStartCheck'} ) {
            my $retc    = 0;
            my @command = ("fsictl startd");
            $logger->trace("$ll  cmd: fsictl startd  [" . session('user') . "]");
            set_flash("!W:fsi check daemon is starting ...");
            fork and return redirect $sess_reload;
            $retc = system(@command);
            exit 0;
         } elsif ( params->{'fsiStopCheck'} ) {
            my $retc    = 0;
            my @command = ("fsictl stopd");
            $logger->trace("$ll  cmd: fsictl stopd  [" . session('user') . "]");
            set_flash("!W:fsi check daemon is stopping ...");
            fork and return redirect $sess_reload;
            $retc = system(@command);
            exit 0;
         } elsif ( params->{'fsiRestartOnline'} ) {
            my $retc    = 0;
            my @command = ("fsictl restarto");
            $logger->trace("$ll  cmd: fsictl restarto  [" . session('user') . "]");
            set_flash("!S:fsi online check daemon is restarting ...");
            fork and return redirect $sess_reload;
            $retc = system(@command);
            exit 0;
         } elsif ( params->{'fsiStartOnline'} ) {
            my $retc    = 0;
            my @command = ("fsictl starto");
            $logger->trace("$ll  cmd: fsictl starto  [" . session('user') . "]");
            set_flash("!S:fsi online check daemon is starting ...");
            fork and return redirect $sess_reload;
            $retc = system(@command);
            exit 0;
         } elsif ( params->{'fsiStopOnline'} ) {
            my $retc    = 0;
            my @command = ("fsictl stopo");
            $logger->trace("$ll  cmd: fsictl stopo  [" . session('user') . "]");
            set_flash("!S:fsi online check daemon is stopping ...");
            fork and return redirect $sess_reload;
            $retc = system(@command);
            exit 0;
         } elsif ( params->{'fsirescantime'} ) {
            my $newrescan=params->{'fsirescantime'};
            if ( $newrescan == 1 ) {
               $logger->warn("$ll  no new sleep time set - ignore  [" . session('user') . "]");
               set_flash("!W:no new sleep time set - ignore change");
            } else {
               $logger->info("$ll  set sleep time to $newrescan  [" . session('user') . "]");
               
               my $rzenv_conf = new Config::General("$global{'rzenvxml'}");
               my %rzenv_h = $rzenv_conf->getall;

               my $daemon_sleep_time=5;
               if ( defined $rzenv_h{'rz'}{ $global{'vienv'} }{'daemonsleep'} ) {
                  $logger->trace("$ll old daemonsleep: $rzenv_h{'rz'}{$global{'vienv'}}{'daemonsleep'}  [" . session('user') . "]");
               } else {
                  $logger->trace("$ll no old parameter daemonsleep found - create new  [" . session('user') . "]");
               }
               
               $rzenv_h{'rz'}{$global{'vienv'}}{'daemonsleep'}=$newrescan;
               $logger->trace("$ll new daemonsleep: $rzenv_h{'rz'}{$global{'vienv'}}{'daemonsleep'}  [" . session('user') . "]");
               $logger->debug("$ll save new daemonsleep to $global{'rzenvxml'}  [" . session('user') . "]");
               $rzenv_conf->save_file("$global{'rzenvxml'}", \%rzenv_h);
               
               $logger->trace("$ll  change actual hash too  [" . session('user') . "]");
               $rzconfig{'rz'}{$global{'vienv'}}{'daemonsleep'}=$newrescan;
               
               unless ($retc) {   
                  $logger->info("$ll  stop check all daemon  [" . session('user') . "]");
                  my @command = ("fsictl stopd");
                  $retc = system(@command);
               }
               unless ($retc) {
                  $logger->info("$ll  start check all daemon  [" . session('user') . "]");
                  @command = ("fsictl startd");
                  $retc = system(@command);
               }              
               unless ($retc) {
                  set_flash("!I:set fsi daemon sleep to $newrescan seconds");
               } else {
                  set_flash("!E:cannot set fsi daemon sleep to $newrescan seconds");
               }
            }
            return redirect $sess_reload;
         } elsif ( params->{'CronRestart'} ) {
            my $retc    = 0;
            my @command = ("service crond restart");
            $logger->trace("$ll  cmd: service crond restart  [" . session('user') . "]");
            $retc = system(@command);
            if ( $retc == 0 ) {
               $logger->trace("$ll  crond restarted  [" . session('user') . "]");
               set_flash("!S:crond restarted");
            } else {
               $logger->error("restarting crond  [" . session('user') . "]");
               set_flash("!E:restarting crond failed");
            }
            return redirect $sess_reload;
         } elsif ( params->{'EditFile'} ) {
            my $parameter = params->{'EditFile'};
            my $file;
            my $srv="fsi";
            my $forwhat="fsi";
            my $fileformat="space";
            
            if (index($parameter, ":") != -1) {
               ( $file, $srv, $fileformat ) = split( ':', $parameter );
               $logger->debug("$ll  edit config file $file for $srv with format $fileformat [" . session('user') . "]");
            } else {
               $file=$parameter;
               $logger->debug("$ll  edit config file $file  [" . session('user') . "]");
            }   

            if ( -f "$file" ) {
               $logger->trace("$ll  found file - open editor  [" . session('user') . "]");
               session 'edit_file'   => $file;
               session 'edit_ctrl'   => $srv;
               session 'edit_what'   => $forwhat;
               session 'edit_format' => $fileformat;
               return redirect "/editfile";
            } else {
               $logger->info("$ll  cannot find file [$file] - admin create new one");
               if ( open my $FH, '>', $file ) {
                  close $FH;
                  $logger->trace("$ll  create empty new file - open editor  [" . session('user') . "]");
                  session 'edit_file'   => $file;
                  session 'edit_ctrl'   => $srv;
                  session 'edit_what'   => $forwhat;
                  session 'edit_format' => $fileformat;
                  return redirect "/editfile";
               } else {
                  $logger->warn("$ll  cannot find or create file $file - abort  [" . session('user') . "]");
                  set_flash("!E:Error - cannot find or create new config file $file");
               }
            }
            return redirect $sess_reload;
         } elsif ( params->{'viewlog'} ) {
            if ( params->{'vmclogfile'} ) {
               my $file = params->{'vmclogfile'};
               my $vmclogfile="$global{'logdir'}/$file";
               $logger->debug("$ll  view logfile [$vmclogfile]  [" . session('user') . "]");
               if ( -f "$vmclogfile" ) {
                  $logger->trace("$ll  found file - open viewer  [" . session('user') . "]");
                  session 'edit_file'   => $vmclogfile;
                  session 'edit_ctrl'   => 'fsi';
                  session 'edit_what'   => 'fsi';
                  session 'edit_format' => 'space';
                  return redirect "/editfile";
               } else {
                  $logger->warn("$ll  cannot find file $vmclogfile - abort  [" . session('user') . "]");
                  set_flash("!E:Error - cannot find VMC logfile $vmclogfile");
               }
            } else {
               $logger->warn("$ll  please choose a logfile - abort  [" . session('user') . "]");
               set_flash("!W:please choose a logfile on the left side first");
            }
            return redirect $sess_reload;
         } elsif ( params->{'fsilog'} ) {
            my $retc = 0;
            return redirect '/showportallog';
            
         } elsif ( params->{'backup'} ) {
            my $retc    = 0;
            my $scriptparam="";
            
            if ( params->{'cfg_certs'} ) {
               $logger->trace("$ll  add cert parameter  [" . session('user') . "]");
               $scriptparam=" -c";
            }
            if ( params->{'cfg_logs'} ) {
               $logger->trace("$ll  add install logs parameter  [" . session('user') . "]");
               $scriptparam="$scriptparam -i";
            }
            if ( params->{'cfg_pool'} ) {
               $logger->trace("$ll  add xen pool parameter  [" . session('user') . "]");
               $scriptparam="$scriptparam -x";
            }
            if ( params->{'cfg_portal'} ) {
               $logger->trace("$ll  add fsi portal parameter  [" . session('user') . "]");
               $scriptparam="$scriptparam -p";
            }
            if ( params->{'cfg_rc'} ) {
               $logger->trace("$ll  add remote control parameter  [" . session('user') . "]");
               $scriptparam="$scriptparam -r";
            }
            if ( params->{'cfg_srv'} ) {
               $logger->trace("$ll  add server config parameter  [" . session('user') . "]");
               $scriptparam="$scriptparam -s";
            }
            if ( params->{'cfg_template'} ) {
               $logger->trace("$ll  add template parameter  [" . session('user') . "]");
               $scriptparam="$scriptparam -t";
            }
               
            if ( "$scriptparam" eq "" ) {
               $logger->info("$ll no checkbox enabled - do not know what to backup  [" . session('user') . "]");
               set_flash("!W:please select at least one checkbox to backup!");
            } else {
               $logger->trace("$ll  script param: $scriptparam  [" . session('user') . "]");
               $retc=backup_fsi($scriptparam);
               if ( $retc == 0 ) {
                  $logger->info("$ll  backup fsi started successful  [" . session('user') . "]");
                  set_flash("!S:backup fsi started successful - please reload the page to see finished backups");
               } else {
                  $logger->error("cannot start fsi backup  [" . session('user') . "]");
                  set_flash("!E:backup fsi failed to start");
               }
            }
            return redirect $sess_reload;
         } elsif ( params->{'restore'} ) {
            my $retc    = 0;

            my $restpoint=params->{'restore'};
            $logger->trace("$ll   restpoint: $restpoint  [" . session('user') . "]");
            
            if ( "$restpoint" eq "no" ) {
               $logger->info("$ll  no restore point given - abort  [" . session('user') . "]");
               set_flash("!W:Please choose a restore point first!");
            } else {
               my $scriptparam="";
            
               if ( params->{'cfg_certs'} ) {
                  $logger->trace("$ll  add cert parameter  [" . session('user') . "]");
                  $scriptparam=" -c";
               }
               if ( params->{'cfg_logs'} ) {
                  $logger->trace("$ll  add install logs parameter  [" . session('user') . "]");
                  $scriptparam="$scriptparam -i";
               }
               if ( params->{'cfg_pool'} ) {
                  $logger->trace("$ll  add xen pool parameter  [" . session('user') . "]");
                  $scriptparam="$scriptparam -x";
               }
               if ( params->{'cfg_portal'} ) {
                  $logger->trace("$ll  add fsi portal parameter  [" . session('user') . "]");
                  $scriptparam="$scriptparam -p";
               }
               if ( params->{'cfg_rc'} ) {
                  $logger->trace("$ll  add remote control parameter  [" . session('user') . "]");
                  $scriptparam="$scriptparam -r";
               }
               if ( params->{'cfg_srv'} ) {
                  $logger->trace("$ll  add server config parameter  [" . session('user') . "]");
                  $scriptparam="$scriptparam -s";
               }
               if ( params->{'cfg_template'} ) {
                  $logger->trace("$ll  add template parameter  [" . session('user') . "]");
                  $scriptparam="$scriptparam -t";
               }
                  
               if ( "$scriptparam" eq "" ) {
                  $logger->info("$ll no checkbox enabled - do not know what to retore  [" . session('user') . "]");
                  set_flash("!W:please select at least one checkbox to restore!");
               } else {
                  $logger->trace("$ll  script param: $scriptparam  [" . session('user') . "]");
                  $retc=restore_fsi($scriptparam,$restpoint);
                  if ( $retc == 0 ) {
                     $logger->info("$ll  restore fsi started successful  [" . session('user') . "]");
                     set_flash("!S:restore fsi started successful - maybe you need to restart fsi");
                  } else {
                     $logger->error("cannot start fsi restore  [" . session('user') . "]");
                     set_flash("!E:restore fsi failed to start");
                  }
               }
            }
            return redirect $sess_reload;
         } elsif ( params->{'clean'} ) {
            my $retc    = 0;
            my $scriptparam="";
            
            if ( params->{'cfg_certs'} ) {
               $logger->trace("$ll  add cert parameter  [" . session('user') . "]");
               $scriptparam=" -c";
            }
            if ( params->{'cfg_logs'} ) {
               $logger->trace("$ll  add install logs parameter  [" . session('user') . "]");
               $scriptparam="$scriptparam -i";
            }
            if ( params->{'cfg_pool'} ) {
               $logger->trace("$ll  add xen pool parameter  [" . session('user') . "]");
               $scriptparam="$scriptparam -x";
            }
            if ( params->{'cfg_portal'} ) {
               $logger->warn("$ll  fsi portal config cannot clean - otherwise the portal do not start again  [" . session('user') . "]");
            }
            if ( params->{'cfg_rc'} ) {
               $logger->trace("$ll  add remote control parameter  [" . session('user') . "]");
               $scriptparam="$scriptparam -r";
            }
            if ( params->{'cfg_srv'} ) {
               $logger->trace("$ll  add server config parameter  [" . session('user') . "]");
               $scriptparam="$scriptparam -s";
            }
            if ( params->{'cfg_template'} ) {
               $logger->trace("$ll  add template parameter  [" . session('user') . "]");
               $scriptparam="$scriptparam -t";
            }
               
            if ( "$scriptparam" eq "" ) {
               $logger->info("$ll no checkbox enabled - do not know what to clean  [" . session('user') . "]");
               set_flash("!W:please select at least one checkbox to clean!");
            } else {
               $logger->trace("$ll  script param: $scriptparam  [" . session('user') . "]");
               $retc=clean_fsi($scriptparam);
               if ( $retc == 0 ) {
                  $logger->info("$ll  cleaning fsi started successful  [" . session('user') . "]");
                  set_flash("!S:cleaning fsi started successful - maybe you need to restart fsi");
               } else {
                  $logger->error("cannot start fsi cleaning  [" . session('user') . "]");
                  set_flash("!E:cleaning fsi failed to start");
               }
            }
            return redirect $sess_reload;
         } elsif ( params->{'delete'} ) {
            my $retc    = 0;
            my $restpoint=params->{'delete'};
            $logger->trace("$ll   restpoint: $restpoint  [" . session('user') . "]");
            
            if ( "$restpoint" eq "no" ) {
               $logger->info("$ll  no restore point given - abort  [" . session('user') . "]");
               set_flash("!W:Please choose a restore point first!");
            } else {
               my $delrestorepointpath="$global{'bakdir'}/$restpoint";
               $logger->trace("$ll  remove restpoint $delrestorepointpath  [" . session('user') . "]");
               $retc = delete_path( $delrestorepointpath );
               if ( $retc == 0 ) {
                  $logger->trace("$ll  restore point $restpoint deleted  [" . session('user') . "]");
                  set_flash("!S:restore point $restpoint deleted");
               } else {
                  $logger->error("cannot delete $restpoint  [" . session('user') . "]");
                  set_flash("!E:Error deleting $restpoint");
               }
            }
            return redirect $sess_reload;
         } elsif ( ( params->{'dbupdate'} ) || ( $admincmd eq "dbupdate" ) ) {
            my $retc = 0;
            my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--update", "-l", "$global{'logdir'}/fsi" );
            $retc = system(@command);
            if ( $retc == 0 ) {
               set_flash("!S:Complete update db");
            } else {
               set_flash("!E:Error [$retc] updating db - please inform js");
            }
            return redirect backurl_getlast("$sess_reload");
         } elsif ( params->{'Back'} ) {
            return redirect backurl_getlast("$sess_reload");
         } elsif ( params->{'Reload'} ) {
            $logger->info("$ll  reload overview  [" . session('user') . "]");
            return redirect $sess_reload;
         }
      } else {
         template 'error',
           {
             'msg'     => "unknown method in /admin",
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'}, };
         $retc = 99;
      } ## end else [ if ( ( request->method() eq "GET" ) || ( request->method() eq "POST" ) ) ]
      if ( request->method() eq "GET" ) {
         my %backup;
         my @fcbdirs = glob( "$global{'bakdir'}/fcb-*" );
         my $dirfound=@fcbdirs;
         $logger->trace("$ll  found [$dirfound] fsi config backups  [" . session('user') . "]");
         if ( $dirfound > 0 ) {
            foreach my $dirfullname ( @fcbdirs ) {
               my ( $volume, $bakdirs, $dirname ) = File::Spec->splitpath($dirfullname);
               my @fsibaks = glob( "$global{'bakdir'}/$dirname/*" );
               my $baksfound=@fsibaks;
               if ( $baksfound > 0 ) {
                  $logger->debug("$ll  found archivs in $dirname  [" . session('user') . "]");
                  foreach my $bakfullfile ( @fsibaks ) {
                     my ( $vol, $bakdir, $bakfile ) = File::Spec->splitpath($bakfullfile);
                     $logger->trace("$ll  found archiv [$bakfile]  [" . session('user') . "]");
                     $backup{'fcbdate'}{$dirname}{$bakfile}=true;
                  }
               } else {
                  $logger->trace("$ll  found no archives in backup dir $dirname  [" . session('user') . "]");
               }
            }
            if($global{'logprod'} < 10000) {
               my $dumpout = Dumper( \%backup );
               $logger->trace("$ll Backup Dump: $dumpout  [" . session('user') . "]");
            }

         } else {
            $logger->info("$ll found no fsi config backups  [" . session('user') . "]");
         }

         $logger->trace("$ll  scan log dir for vmc logs  [" . session('user') . "]");
         my %vmclogs_h;
         my @vmlogs = glob( "$global{'logdir'}/clone-*log" );
         my $logsfound=@vmlogs;
         if ( $logsfound > 0 ) {
            $logger->debug("$ll  found vmc logs $global{'logdir'}  [" . session('user') . "]");
            foreach my $logfullfile ( @vmlogs ) {
               my ( $vol, $logdir, $vmclogfile ) = File::Spec->splitpath($logfullfile);
               $logger->trace("$ll  found logfile [$vmclogfile]  [" . session('user') . "]");
               $vmclogs_h{$vmclogfile}=time2str("%Y%m%d-%H%M", (stat $logfullfile)[9]);
            }
         } else {
            $logger->trace("$ll  found no vmc logfiles in $global{'logdir'}  [" . session('user') . "]");
         }

         if($global{'logprod'} < 10000) {
            my $dumpout = Dumper( \%vmclogs_h );
            $logger->trace("$ll Backup Dump: $dumpout  [" . session('user') . "]");
         }


         $logger->debug("$ll  check daemon sleep config  [" . session('user') . "]");
         my $daemonsleep=5;
         if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'daemonsleep'} ) {
            $daemonsleep=$rzconfig{'rz'}{ $global{'vienv'} }{'daemonsleep'};
         }
         template 'admin.tt',
           {
             'msg'          => get_flash(),
             'entries'      => $serverhash_p,
             'rzconfig'     => \%rzconfig,
             'version'      => $ver,
             'daemonsleep'  => $daemonsleep,
             'vmclogs'      => \%vmclogs_h,
             'backup'       => \%backup,
             'vitemp'       => $host,
             'vienv'        => $global{'vienv'}, };
      } ## end if ( request->method() eq "GET" )
   } ## end else [ if ( !session('logged_in') ) ]
};

sub import_server {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $line   = shift();
   my $errmsg = "";

   #$logger->trace("$ll  line: $line");
   my ( $os, $cmds ) = split /##/, $line, 2;
   if ( "$os" eq "xen" ) {
      $logger->debug("$ll  import xen server  [" . session('user') . "]");
      my $scriptcall = "$global{'toolsdir'}/mkx6 -l $global{'logfile'}.log " . $cmds;
      my $server     = "";
      my $pool       = "";

      if ( $scriptcall =~ /-c (.*?),(.*?),/ ) {
         $server = $2;
      } else {
         $errmsg = "no server found - abort";
         $logger->error("$errmsg  [" . session('user') . "]");
         $retc = 99;
      }

      unless ($retc) {
         my @parts = $line =~ /(".*?"|'.*?'|-.|\w+)/g;

         if ( $logger->is_trace() ) {
            my $dumpout = Dumper( \@parts );
            $logger->trace("$ll import line: $dumpout  [" . session('user') . "]");
         }

         foreach my $part (@parts) {
            if ( $pool eq 'found' ) {
               $pool = $part;
               last;
            }
            if ( $part eq '-p' ) {
               $pool = "found";
            }
         } ## end foreach my $part (@parts)
         if ( "$pool" eq "" ) {
            $errmsg = "no pool found - abort";
            $logger->error("$errmsg  [" . session('user') . "]");
            $retc = 99;
         }
      } ## end unless ($retc)

      if ( $retc eq 0 ) {
         $logger->trace("$ll   server: $server  [" . session('user') . "]");
         $logger->trace("$ll   pool: $pool  [" . session('user') . "]");
         $retc = add_xen( $scriptcall, $server, $pool, "no" );
         if ($retc) {
            set_flash("!E:Error adding $server in $pool");
         }
      } ## end if ( $retc eq 0 )
   } elsif ( "$os" eq "esxi" ) {
      $logger->debug("$ll  import esxi server  [" . session('user') . "]");
      my $scriptcall = "$global{'toolsdir'}/mkesxi -l $global{'logfile'}.log" . $cmds;
      my $server     = "";

      # if ( $scriptcall =~ /-E \"(.*?)\"/ ) {
      if ( $scriptcall =~ /-E (.*?),/ ) {
         $server = $1;
      } else {
         $errmsg = "no server found - abort";
         $logger->error("$errmsg  [" . session('user') . "]");
         $retc = 99;
      }
      if ( $retc eq 0 ) {
         $logger->trace("$ll   server: $server  [" . session('user') . "]");
         $retc = add_esxi( $scriptcall, $server );
         if ($retc) {
            $errmsg = "Error adding $server";
            $logger->error("$errmsg  [" . session('user') . "]");
         }
      } ## end if ( $retc eq 0 )
   } elsif ( "$os" eq "co" ) {
      $logger->debug("$ll  import centos server  [" . session('user') . "]");
   } elsif ( "$os" eq "rh" ) {
      $logger->debug("$ll  import redhat server  [" . session('user') . "]");
   } else {
      $errmsg = "unsupported os system [$os] - ignore";
      $logger->error("$errmsg  [" . session('user') . "]");
      $retc = 100;

   } ## end else [ if ( "$os" eq "xen" ) ]

   if ($retc) {
      set_flash("!E:ERROR: $errmsg");
   }

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub import_server

sub backup_fsi {
   my $llback = $logger->level();
#   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;

   my $scriptparam = shift;
   
   if ( "$scriptparam" eq "" ) {
      $logger->error("no script parameter defined - abort  [" . session('user') . "]");
      $retc=99;
   } else {
      
      $addcmd = 'backup fsi,' . session('user') . ',myShowTask,TASKID,all,all,no';
      my $taskid = task_add( $addcmd, 'force' );
   
      if ($taskid) {
         $logger->trace("$ll  fork now to id ($taskid)  [" . session('user') . "]");
         fork and return $retc;
         my $tasklog = $global{'logdir'} . "/task-" . $taskid;
         $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
         $retc = tasklog_add($tasklog);
   
         unless ($retc) {
            my $command = "$global{'toolsdir'}/cfgbackup $scriptparam -l $tasklog.log";
            $logger->trace("$ll  cmd: [$command]  [" . session('user') . "]");
            my $eo = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            unless ($retc) {
               $logger->trace("$ll  ok  [" . session('user') . "]");
               set_flash("!S:fsi backup finished without error");
            } else {
               $logger->error("failed cmd [$eo]  [" . session('user') . "]");
            }
         } 
   
         $logger->debug("$ll  delete task - with blocking  [" . session('user') . "]");
         $retc = task_del( $taskid, 'yes' );
         $logger->trace("$ll  delete task log file  [" . session('user') . "]");
         $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
         $retc = tasklog_remove($tasklog);
         exit;                                                                                                               # if fork than exit here
      }
   }

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
#   $logger->level($llback);
   return $retc;
}


sub restore_fsi {
   my $llback = $logger->level();
#   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;

   my ( $scriptparam, $restdir ) = @_;
   
   if ( "$scriptparam" eq "" ) {
      $logger->error("no script parameter defined - abort  [" . session('user') . "]");
      $retc=99;
   } else {
      
      if ( "$restdir" eq "" ) {
         $logger->error("no restore source dir defined - abort  [" . session('user') . "]");
         $retc=98;
      } else {
         $addcmd = 'restore fsi,' . session('user') . ',myShowTask,TASKID,all,all,no';
         my $taskid = task_add( $addcmd, 'force' );
      
         if ($taskid) {
            $logger->trace("$ll  fork now to id ($taskid)  [" . session('user') . "]");
            fork and return $retc;
            my $tasklog = $global{'logdir'} . "/task-" . $taskid;
            $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
            $retc = tasklog_add($tasklog);
      
            unless ($retc) {
               my $command = "$global{'toolsdir'}/cfgrestore $scriptparam -d $global{'bakdir'}/$restdir -l $tasklog.log";
               $logger->trace("$ll  cmd: [$command]  [" . session('user') . "]");
               my $eo = qx($command  2>&1);
               $retc = $?;
               $retc = $retc >> 8 unless ( $retc == -1 );
               unless ($retc) {
                  $logger->trace("$ll  ok  [" . session('user') . "]");
                  set_flash("!S:fsi backup finished without error");
               } else {
                  $logger->error("failed cmd [$eo]  [" . session('user') . "]");
               }
            } 
      
            $logger->debug("$ll  delete task - with blocking  [" . session('user') . "]");
            $retc = task_del( $taskid, 'yes' );
            $logger->trace("$ll  delete task log file  [" . session('user') . "]");
            $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
            $retc = tasklog_remove($tasklog);
            exit;                                                                                                               # if fork than exit here
         }
      }
   }

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
#   $logger->level($llback);
   return $retc;
}


sub clean_fsi {
   my $llback = $logger->level();
#   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;

   my ( $scriptparam, $restdir ) = @_;
   
   if ( "$scriptparam" eq "" ) {
      $logger->error("no script parameter defined - abort  [" . session('user') . "]");
      $retc=99;
   } else {
      
      $addcmd = 'clean fsi,' . session('user') . ',myShowTask,TASKID,all,all,no';
      my $taskid = task_add( $addcmd, 'force' );
   
      if ($taskid) {
         $logger->trace("$ll  fork now to id ($taskid)  [" . session('user') . "]");
         fork and return $retc;
         my $tasklog = $global{'logdir'} . "/task-" . $taskid;
         $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
         $retc = tasklog_add($tasklog);
   
         unless ($retc) {
            my $command = "$global{'toolsdir'}/cfgrestore -o $scriptparam -l $tasklog.log";
            $logger->trace("$ll  cmd: [$command]  [" . session('user') . "]");
            my $eo = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            unless ($retc) {
               $logger->trace("$ll  ok  [" . session('user') . "]");
               set_flash("!S:fsi cleaning finished without error");
            } else {
               $logger->error("failed cmd [$eo]  [" . session('user') . "]");
            }
         } 
   
         $logger->debug("$ll  delete task - with blocking  [" . session('user') . "]");
         $retc = task_del( $taskid, 'yes' );
         $logger->trace("$ll  delete task log file  [" . session('user') . "]");
         $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
         $retc = tasklog_remove($tasklog);
         exit;                                                                                                               # if fork than exit here
      }
   }

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
#   $logger->level($llback);
   return $retc;
}