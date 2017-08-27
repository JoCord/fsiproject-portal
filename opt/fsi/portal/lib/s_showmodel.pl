any [ 'get', 'post' ] => '/showmodel/:lxmodel?' => sub {
   my $weburl = '/showmodel';
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

         my $retc = db_reload();
         if ($retc) {
            $looger->error("cannot reload db  [" . session('user') . "]");
            set_flash("!E:cannot reload db");
         } else {
            my %params = params;
   
            $lxmodel = param('lxmodel');
   
            my $sess_reload = $weburl . '/' . $lxmodel;
            $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
            session 'reload' => $sess_reload;
            $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
            $retc = backurl_add("$sess_reload");
   
            my $retc = db_reload();
            template 'show_lxmodel.tt',
              {
                'msg'      => get_flash(),
                'version'  => $ver,
                'lxmodel'  => $lxmodel,
                'vitemp'   => $host,
                'rzconfig' => \%rzconfig,
                'entries'  => $serverhash_p,
                'vienv'    => $global{'vienv'}, };
         }

      } elsif ( request->method() eq "POST" ) {
         $logger->debug("$ll  POST Section  [" . session('user') . "]");
         my $sess_reload = session('reload');
         $retc = backurl_add("$sess_reload");
         my %params = params;

         if ( $global{'logprod'} < 10000 ) {
            my $dumpout = Dumper( \%params );
            $logger->trace("$ll Dump: $dumpout");
         }
         if ( params->{'Logout'} ) {
            $logger->info("$ll  logout  [" . session('user') . "]");
            return redirect '/logout';
         } elsif ( params->{'Back'} ) {
            my $sess_back = backurl_getlast("$sess_reload");
            $logger->debug("$ll  go back to $sess_back  [" . session('user') . "]");
            return redirect $sess_back;
         } elsif ( params->{'Reload'} ) {
            $logger->info("$ll  reload lx model view");
            redirect $sess_reload;

            # Server Jobs
         } elsif ( params->{'Install'} ) {
            my $job = params->{'Install'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Install Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/instsrvmark';
            } else {
               $logger->debug("$ll  run single job - Install Server  [" . session('user') . "]");

               # $srvid = substr( params->{'Install'}, 3 );
               session 'srvarray' => substr( params->{'Install'}, 3 );
               redirect '/instsrvmark';
            } ## end else [ if ( $job eq "marked" ) ]
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
         } elsif ( params->{'Abort'} ) {
            my $job = params->{'Abort'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Abort Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked - go overview  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/stopsrvmark';
            } else {
               $logger->debug("$ll  run single job - Abort Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'Abort'}, 3 );
               redirect '/stopsrvmark';
            }
         } elsif ( params->{'PowerON'} ) {
            my $job = params->{'PowerON'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Power ON Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/ponsrvmark';
            } else {
               $logger->debug("$ll  run single job - Power ON Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'PowerON'}, 3 );
               redirect '/ponsrvmark';
            }
         } elsif ( params->{'PowerOFF'} ) {
            my $job = params->{'PowerOFF'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Power OFF Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/poffsrvmark';
            } else {
               $logger->debug("$ll  run single job - Power OFF Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'PowerOFF'}, 3 );
               redirect '/poffsrvmark';
            }
         } elsif ( params->{'Reboot'} ) {
            my $job = params->{'Reboot'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Reboot Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked   [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/bootsrvmark';
            } else {
               $logger->debug("$ll  run single job - Reboot Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'Reboot'}, 3 );
               redirect '/bootsrvmark';
            }
         } elsif ( params->{'Shutdown'} ) {
            my $job = params->{'Shutdown'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Shutdown Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked   [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/shutdownsrvmark';
            } else {
               $logger->debug("$ll  run single job - Shutdown Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'Shutdown'}, 3 );
               redirect '/shutdownsrvmark';
            }
         } elsif ( params->{'SetMaintenanceMode'} ) {
            my $job = params->{'SetMaintenanceMode'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - set server to maintenance mode  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked   [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/setmaintenancemodemark';
            } else {
               $logger->debug("$ll  run single job - set server to maintenance mode  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'SetMaintenanceMode'}, 3 );
               redirect '/setmaintenancemodemark';
            }
         } elsif ( params->{'ExitMaintenanceMode'} ) {
            my $job = params->{'ExitMaintenanceMode'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - exit server from maintenance mode  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked   [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/exitmaintenancemodemark';
            } else {
               $logger->debug("$ll  run single job - exit server from maintenance mode  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'ExitMaintenanceMode'}, 3 );
               redirect '/exitmaintenancemodemark';
            }
         } elsif ( params->{'Delete'} ) {
            my $job = params->{'Delete'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Delete Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ne "on" ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/delsrvmark';
            } else {
               $logger->debug("$ll  run single job - Delete Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'Delete'}, 3 );
               redirect '/delsrvmark';
            }
         } elsif ( params->{'ShowLog'} ) {
            session 'srvid' => substr( params->{'ShowLog'}, 3 );
            redirect '/showlog/notail';
         } elsif ( params->{'Update'} ) {
            my $job = params->{'Update'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Update Server  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/updsrvmark';
            } else {
               $logger->debug("$ll  run single job - Update Server  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'Update'}, 3 );
               redirect '/updsrvmark';
            }
         } elsif ( params->{'ResetMsg'} ) {
            $logger->debug("$ll  reset message  [" . session('user') . "]");
            session 'srvid' => substr( params->{'ResetMsg'}, 3 );
            my $rc = reset_msg( substr( params->{'ResetMsg'}, 3 ) );
            return redirect $sess_reload;
         } elsif ( params->{'DelLog'} ) {
            my $job = params->{'DelLog'};
            if ( $job eq "marked" ) {
               $logger->debug("$ll  run marked job - Delete Logfiles  [" . session('user') . "]");
               @markedsrv = ();
               if ( ref $params{'Marked'} eq 'ARRAY' ) {
                  $logger->trace("$ll  more than one element marked  [" . session('user') . "]");
                  foreach my $marksrv ( @{ $params{'Marked'} } ) {
                     if ( $marksrv ne "0" && $marksrv ne "on" ) {
                        @markedsrv = ( @markedsrv, $marksrv );
                     }
                  }
               } else {
                  if ( $params{'Marked'} ) {
                     $logger->trace("$ll  only one element marked  [" . session('user') . "]");
                     @markedsrv = ( @markedsrv, $params{'Marked'} );
                  } else {
                     $logger->trace("$ll  no element marked  [" . session('user') . "]");
                  }
               } ## end else [ if ( ref $params{'Marked'} eq 'ARRAY' ) ]
               session 'srvarray' => "@markedsrv";
               redirect '/dellogmark';
            } else {
               $logger->debug("$ll  run single job - Delete Logfile  [" . session('user') . "]");
               session 'srvarray' => substr( params->{'DelLog'}, 3 );
               redirect '/dellogmark';
            }

            # Linux specify
         } elsif ( params->{'UpdateVIScriptsLXmodel'} ) {
            $logger->debug("$ll  update and deploy vi tool scripts on $lxmodel  [" . session('user') . "]");
            my $pool = params->{'UpdateVIScriptsVC'};

            # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
            my $addcmd = 'copy vi tools to model ' . $lxmodel . ',copy vi tools to all linux server on with model ' . $lxmodel . ',' . session('user') . ',myShowTask,TASKID,' . $lxmodel . ',srv,yes';
            $logger->trace("$ll cmd: $addcmd  [" . session('user') . "]");
            $taskid = task_add($addcmd);
            if ($taskid) {
               $logger->trace("$ll  fork now  [" . session('user') . "]");
               set_flash("!I:Start copy vi scripts to all server with model [$lxmodel] ...");
               fork and return redirect $sess_reload;
               my $tasklog = $global{'logdir'} . "/task-" . $taskid;
               $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
               $retc = tasklog_add($tasklog);
               my $rc = deploy_scripts_lxmodel( $lxmodel, $tasklog );
               $logger->debug("$ll  delete task  [" . session('user') . "]");
               $retc = task_del( $taskid, 'yes' );
               $logger->trace("$ll  delete task log file  [" . session('user') . "]");
               $logger->trace("$ll  task log: $tasklog  [" . session('user') . "]");
               $retc = tasklog_remove($tasklog);

               # if fork - than exit here
               exit;
            } else {
               set_flash("!E:Server $lxmodel cannot get new task id ");
            }
            return redirect $sess_reload;
         } else {
            return redirect $sess_reload;
         }
      } else {
         template 'error',
           {
             'msg'     => "unknown method in $weburl",
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'}, };
      } ## end else [ if ( request->method() eq "GET" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
