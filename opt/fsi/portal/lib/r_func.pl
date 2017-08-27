sub set_flash {
   my $message = shift;
   session 'flash' => $message;
}

sub get_flash {
   my $msg = session('flash');
   session 'flash' => "";
   return $msg;
}

sub no_reading {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $typ=shift();
   my $who=shift();

   my $retc=0;
   my $isreading=1;         # default reading - check if not
   my $runstatus="";

   if ( "$typ" eq "" ) {
      $logger->error("no control typ given - abort");
      $retc=44;
   }
   if ( "$who" eq "" ) {
      $logger->error("no search given - abort");
      $retc=45;
   }
   
   unless ( $retc ) {
      my $dbh    = db_connect();
      my $sql    = "SELECT who,typ,status,info FROM $global{'dbt_worker'} WHERE ( typ = '$typ' AND who = '$who' )";
      $logger->trace("$ll  sql: $sql");
      my $sth = $dbh->prepare($sql) or die $dbh->errstr;
      $sth->execute or die $sth->errstr;
      my $statushash_r = $sth->fetchall_hashref('who');

      if ($logger->is_trace()) {
         my $dumpout=Dumper($statushash_r);
         $logger->trace("$ll  Status Hash for running stat: $dumpout");  
      }
      $runstatus=$statushash_r->{$who}{'status'};
      $logger->trace("$ll  reading status: [$runstatus]");

      if ( "$runstatus" eq "reading" ) {
         $logger->error("$ll  there is already a other task reading for $who");
         $isreading=0; 
      }
      $sth->finish();
      $retc = db_disconnect($dbh);
   }
  
   $logger->trace("$ll status: $isreading / $runstatus");
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $isreading;
}
  

sub readjsonfile {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;

   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );

   $logger->trace("$ll func start: [$fc]");
   my $retc=0;

   my $file=shift();
   my $jsonhash_ref = {}; # init hash ref

   if ( -f $file ) {
      open(IFIL,"<$file"); 
      $JSONdata= <IFIL>; 
      close(IFIL);
   
      $jsonhash_ref = decode_json($JSONdata);
      
      
   } else {
      $logger->error("no file [$file] found - abort");
      $retc=99;
   }
   
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;

   $logger->level($llback);
   return $jsonhash_ref;
}

sub writejsonfile {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;

   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );

   $logger->trace("$ll func start: [$fc]");
   my $retc=0;

   my $file=shift();
   my $hash_ref=shift();
  
   ##ToDo: file & error handling
   my $JSONdata = encode_json($hash_ref);
   open(OFIL,">$file"); 
   print OFIL $JSONdata; 
   close(OFIL);
 
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;

   $logger->level($llback);
   return $retc;
}



sub backurl_add {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;

   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );

   $logger->trace("$ll func start: [$fc]");

   my $retc   = 0;
   my $newurl = shift();

   $logger->trace("$ll  add url: $newurl");
   if ( "$newurl" eq "" ) {
      $logger->warn("$ll  no new url to set - ignore");
   } else {
      my $backlist = session('back');
      if ( "$backlist" eq "" ) {
         $logger->trace("$ll  no saved back url");
         $logger->trace("$ll   create new back url for session key");
         session 'back' => $newurl;
      } else {
         $logger->trace("$ll  convert list [$backlist] to array");
         my @backarray = parse_line( ',', 0, $backlist );
         $logger->trace("$ll  back array [@backarray]");
         $logger->trace("$ll  get last url element");
         if ( "$newurl" eq "$backarray[$#backarray]" ) {
            $logger->debug("$ll  new url [$newurl] same as last saved url [$backarray[$#backarray]] - ignore");
         } else {
            $logger->trace("$ll  test if I can reset url list");
            my $viewregex = qr{^[\/]?overview(?:vc|xenpools|)$};
            if ( $newurl =~ m/$viewregex/ ) {
               $logger->trace("$ll   reset url list with [$newurl]");
               $logger->trace("$ll   create new back url for session key");
               session 'back' => $newurl;
            } else {
               $logger->trace("$ll  no reset - test if url [$newurl] is in back list [$backlist]");
               $search_string = quotemeta "$newurl";
               if ( $backlist =~ m/$search_string/ ) {
                  $logger->trace("$ll   found match in url back list ... delete all behind");
                  my $backlist = substr( $backlist, 0, rindex( $backlist, $newurl ) );
                  $backlist = "$backlist,$newurl";
                  $logger->trace("$ll   new backlist: $backlist");
                  $logger->trace("$ll  create new back url list for session key");
                  session 'back' => $backlist;
               } else {
                  $logger->trace("$ll   do not find url in back list - add new url at the end");
                  @backarray = ( @backarray, $newurl );
                  $logger->trace("$ll  create new back url list for session key");
                  $backlist = join( ',', @backarray );
                  session 'back' => $backlist;
               } ## end else [ if ( $backlist =~ m/$search_string/ ) ]
            } ## end else [ if ( $newurl =~ m/$viewregex/ ) ]
         } ## end else [ if ( "$newurl" eq "$backarray[$#backarray]" ) ]
      } ## end else [ if ( "$backlist" eq "" ) ]
   } ## end else [ if ( "$newurl" eq "" ) ]
   $logger->debug( "$ll  => new back url list: " . session('back') );

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   
   $logger->level($llback);
   
   return $retc;
} ## end sub backurl_add

sub backurl_getlast {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   
   $logger->trace("$ll func start: [$fc]");
   my $retc       = 0;
   my $lasturl    = "";
   my $url        = "/overview";                                                                                                   # Standard if no back url saved
   my $currenturl = shift();
   $logger->trace("$ll  => url: $currenturl");
   my $backlist = session('back');
   $logger->trace("$ll  => backlist: $backlist");

   if ( "$backlist" eq "" ) {
      $logger->trace("$ll no saved back url - take standard [$url]");
   } else {
      $logger->trace("$ll  convert list to array");
      my @backarray = parse_line( ',', 0, $backlist );
      $logger->trace("$ll  get and remove last url element");
      $lasturl = pop(@backarray);
      if ( !defined $lasturl ) {
         $logger->trace("$ll  no url in array - take standard [$url]");
      } else {
         $logger->trace("$ll  found last url [$lasturl]");
         if ( "$currenturl" eq "" ) {
            $logger->trace("$ll  no current url given, take found last url");
         } elsif ( "$currenturl" eq "$lasturl" ) {
            $logger->trace("$ll  actual last url is same as current url - ignore and take next one");
            $lasturl = pop(@backarray);
            if ( !defined $lasturl ) {
               $logger->trace("$ll  no url in array - take overview");
               $lasturl = "/overview";
            } else {
               if ( "$lasturl" eq "" ) {
                  $logger->trace("$ll  empty url - take overview");
                  $lasturl = "/overview";
               } else {
                  $logger->trace("$ll  now I found a new url for go back - take this [$lasturl]");
               }
            } ## end else [ if ( !defined $lasturl ) ]
         } else {
            $logger->trace("$ll  found new url for go back [$lasturl]");
         }
         $logger->trace("$ll  create new back url list for session key");
         $backlist = join( ',', @backarray );
         session 'back' => $backlist;
         $logger->debug("$ll  found last url [$lasturl] ");
         $url = $lasturl;
      } ## end else [ if ( !defined $lasturl ) ]
   } ## end else [ if ( "$backlist" eq "" ) ]
   $logger->trace( "$ll  => new back url list: " . session('back') );

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;

   $logger->level($llback);
   
   return $url;
} ## end sub backurl_getlast

sub setmaintenancemode {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $srv = shift;
   $logger->trace("$ll  set server $srv in maintenance mode");
   $logger->debug("$ll   test if server online");
   my $p = Net::Ping->new( $global{'pingprot'} );

   if ( $p->ping($srv) ) {
      $logger->trace("$ll server $srv connected");
      my $command = "$global{'toolsdir'}/srvctrl -l $global{'logdir'}/fsi -s $srv -m";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         my $command = $global{'progdir'} . "/fsic.pl -l $global{'logdir'}/fsi --setflag s_online --set M --server $srv";
         $logger->trace("$ll  cmd: [$command]");
         my $eo = qx($command  2>&1);
         $retc = $?;
         $retc = $retc >> 8 unless ( $retc == -1 );
         unless ($retc) {
            $logger->trace("$ll  set flag s_online to M");
         }
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot set maintenance mode on $server";
      }
   } else {
      $logger->trace("$ll server $srv not connected - srv offline ");
      $retc   = 77;
      $errmsg = "";
   }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub setmaintenancemode

sub portal_poff_srv {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;

   my $server = shift();
   $logger->trace("$ll  srv: $server");
   if ( "$server" eq "" ) {
      $logger->error("no server given - abort");
      $retc = 99;
   } else {
      my $addcmd = 'poweroff ' . $server . ',power off server ' . $server . ',' . session('user') . ',myShowTask,TASKID,' . $server . ',srv,no';
      $logger->trace("$ll  cmd: $addcmd");
      my $taskid = task_add( $addcmd, 'force' );

      if ($taskid) {
         $logger->trace("$ll  fork now to id ($taskid)");
         set_flash("Start power off server [$server] ...");
         fork and return $retc;
         my $tasklog = $global{'logdir'} . "/task-" . $taskid;
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_add($tasklog);

         $logger->info("$ll   power off server $server");
         my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--srvoff", $server, "-l", $tasklog );
         $retc = system(@command);
         if ( $retc == 0 ) {
            $logger->trace("$ll power off server ok");
         } else {
            $errrmsg = "Error [$retc] power server off [$server]";
            $logger->error($errmsg);
            last;
         }

         $logger->debug("$ll  delete task");
         $retc = task_del( $taskid, 'yes' );
         $logger->trace("$ll  delete task log file");
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_remove($tasklog);
         unless ($retc) {
            set_flash("!S:Install server successful start [$server] $errmsg");
         } else {
            set_flash("!E:Error starting installation server [$errmsg] ");
         }
         exit;                                                                                                                     # if fork than exit here
      } else {
         set_flash("!E:Server $server cannot get new task id ");
         $retc = 99;
      }
   } ## end else [ if ( "$server" eq "" ) ]

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub portal_poff_srv


sub portal_inst_srv {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;

   my $server = shift();
   $logger->trace("$ll  srv: $server");
   if ( "$server" eq "" ) {
      $logger->error("no server given - abort");
      $retc = 99;
   } else {
      my $addcmd = 'install ' . $server . ',start install routine for server ' . $server . ',' . session('user') . ',myShowTask,TASKID,' . $server . ',srv,no';
      $logger->trace("$ll  cmd: $addcmd");
      my $taskid = task_add( $addcmd, 'force' );

      if ($taskid) {
         $logger->trace("$ll  fork now to id ($taskid)");
         set_flash("Start installing server [$server] ...");
         fork and return $retc;
         my $tasklog = $global{'logdir'} . "/task-" . $taskid;
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_add($tasklog);
         $logger->info("$ll  update $server");

         my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--install", $server, "-l", $tasklog );
         $retc = system(@command);
         if ( $retc == 0 ) {
            $logger->trace("$ll install start ok");
         } else {
            $errrmsg = "Error [$retc] starting installation [$server]";
            $logger->error($errmsg);
            last;
         }
         unless ($retc) {
            my $command = "$global{'toolsdir'}/dellog -l $tasklog.log -s $server ";
            $logger->trace("$ll  cmd: [$command]");
            my $eo = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            unless ($retc) {
               $logger->trace("$ll  ok");
            } else {
               $logger->error("failed cmd [$eo]");
               $errmsg = "Cannot delete logfile for $marksrvhash->{$srvid}{'db_srv'}";
            }
         } ## end unless ($retc)
         unless ($retc) {
            $db = db_connect();
            if ( "$db" eq "undef" ) {
               $retc = 99;
            } else {
               $retc = del_flag_srv( $db, "j_logshow", $marksrvhash->{$srvid}{'db_srv'} );
            }
            $retc = db_disconnect($db);
         } ## end unless ($retc)
         unless ($retc) {
            $db = db_connect();
            if ( "$db" eq "undef" ) {
               $retc = 99;
            } else {
               $retc = del_flag_srv( $db, "s_insterr", $marksrvhash->{$srvid}{'db_srv'} );
            }
            $retc = db_disconnect($db);
         } ## end unless ($retc)


         $logger->debug("$ll  delete task");
         $retc = task_del( $taskid, 'yes' );
         $logger->trace("$ll  delete task log file");
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_remove($tasklog);
         unless ($retc) {
            set_flash("!S:Install server successful start [$server] $errmsg");
         } else {
            set_flash("!E:Error starting installation server [$errmsg] ");
         }
         exit;                                                                                                                     # if fork than exit here
      } else {
         set_flash("!E:Server $server cannot get new task id ");
         $retc = 99;
      }
   } ## end else [ if ( "$server" eq "" ) ]

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub portal_inst_srv




sub portal_upd_srv {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $server     = shift();
   my $control    = shift();
   my $controltyp = shift();
   my $autoreboot = shift();
   my $addcmd     = "no";
   my $taskid     = 0;
   $logger->info("$ll  update server [$server] of [$control] with autoreboot=$autoreboot");

   if ( $controltyp eq "xp" ) {
      $logger->debug("$ll  $server is in xen pool [$control]");
      if ( task_ok($control) ) {

         # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
         $addcmd = 'xenpool update ' . $control . ',running update routine on all server in ' . $control . ',' . session('user') . ',myShowTask,TASKID,' . $control . ',xp,yes';
         $logger->debug("$ll  if xen block complete pool");
         my $pooltaskid = task_add( $addcmd, 'force' );
         if ($pooltaskid) {
            $logger->debug("$ll  pool blockade successfully");
            $logger->trace( "$ll  task log: " . $global{'logdir'} . "/task-" . $pooltaskid );
            $retc = tasklog_add( $global{'logdir'} . "/task-" . $pooltaskid );
         } else {
            $logger->error("$ll  cannot blockade pool");
         }
      } else {
         $logger->debug("$ll  xen pool still in blockade maybe from started update");
      }
      $addcmd = 'update ' . $server . ',running update routine for server ' . $server . ' on ' . $control . ',' . session('user') . ',myShowTask,TASKID,' . $server . ',srv,no';
      $logger->trace("$ll  cmd: $addcmd");
      $taskid = task_add( $addcmd, 'force' );
   } elsif ( $controltyp eq "vc" ) {
      $logger->debug("$ll  vc need no whole blockade, only server is enough");
      $addcmd = 'update ' . $server . ',running update routine for server ' . $server . ',' . session('user') . ',myShowTask,TASKID,' . $server . ',srv,yes';
      $logger->trace("$ll cmd: $addcmd");
      $taskid = task_add($addcmd);
   } else {
      $logger->trace("$ll  unknown control typ");
   }
   if ($taskid) {
      $logger->trace("$ll  fork now to id ($taskid)");
      set_flash("Start updating server [$server] ...");
      fork and return $retc;
      my $tasklog = $global{'logdir'} . "/task-" . $taskid;
      $logger->trace("$ll  task log: $tasklog");
      $retc = tasklog_add($tasklog);
      $logger->info("$ll  update $server");
      my $command = "$global{'toolsdir'}/srvctrl -l " . $tasklog . ".log -u -s " . $server;
      $logger->trace("$ll  cmd: $command");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $logger->trace("$ll  cmd rc=$retc");
      $retc = $retc >> 8 unless ( $retc == -1 );
      $logger->info("$ll  update return code=$retc");

      if ( $retc == 0 ) {
         $logger->info("$ll  ok - no reboot");
         $errmsg = "Update ok - no reboot needed";
      } elsif ( $retc == 1 ) {
         $logger->info("$ll  ok - need reboot");
         if ( "$autoreboot" eq "yes" ) {
            $logger->info("$ll  auto reboot after update");
            my $command = "$global{'toolsdir'}/srvctrl -l " . $tasklog . ".log -r -s " . $server;
            $logger->trace("$ll  cmd: $command");
            my $eo = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            $logger->trace("$ll  rc=$retc");
            if ( $retc == 0 ) {
               $errmsg = "Update ok - reboot started";
               $logger->info("$ll  $errmsg");
            } else {
               $errmsg = "Update ok - please reboot server and run Update again";
               $logger->error("$errmsg");
            }
         } else {
            $logger->info("$ll  no autoreboot flag - do not reboot after update");
            $errmsg = "Update ok - please reboot server and run update again";
         }
         $retc = 0;
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot update server $server";
      }
      $logger->debug("$ll  delete task - but not blocking");
      $retc = task_del( $taskid, 'no' );
      $logger->trace("$ll  delete task log file");
      $logger->trace("$ll  task log: $tasklog");
      $retc = tasklog_remove($tasklog);
      unless ($retc) {
         set_flash("!S:Update server successful [$server] $errmsg");
      } else {
         set_flash("!E:Error updating server [$errmsg] ");
      }
      exit;                                                                                                                        # if fork than exit here
   } else {
      set_flash("!E:Server $server cannot get new task id ");
      $retc = 99;
   }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub portal_upd_srv

sub getsrvinfo_esxi {
   my $llback = $logger->level();

   # $logger->level($global{'logprod'});
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc      = 0;
   
   my %srvinfo_h;
   
   my ( $server, $srvpath ) = @_;
   $logger->trace("$ll   server: $server");
   $logger->trace("$ll   path: $srvpath");
   
   unless ($retc) {
      $logger->debug("$ll   test if server online");
      my $p = Net::Ping->new( $global{'pingprot'} );
      if ( $p->ping($server) ) {
         $logger->trace("$ll server $server connected");

         unless ($retc) {
            $logger->trace("$ll delete old infos for $server");
            my $command = "$global{'toolsdir'}/delinfodir -l $global{'logfile'}.log -s $server";
            $logger->trace("$ll  cmd: [$command]");
            my $xenupd = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            if ( $retc == 0 ) {
               $logger->trace("$ll   ok");
            } else {
               $logger->trace("");
            }
         } ## end unless ($retc)

         unless ($retc) {
            $logger->trace("$ll get esxi informations from $server");
            my $command = "$global{'toolsdir'}/rinfo -l $global{'logfile'}.log -s $server -i";
            $logger->trace("$ll  cmd: [$command]");
            my $upd = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            if ( $retc == 0 ) {
               $logger->trace("$ll   ok");
               if ( -f "$srvpath/patchlvl" ) {
                  $logger->trace("$ll  patchlvl data file exist - read it  [" . session('user') . "]");

                  if (open(my $fh, '<:encoding(UTF-8)', "$srvpath/patchlvl")) {
                     while (my $row = <$fh>) {
                        chomp $row;
                        my ( $name, $version, $vendor, $cert, $instdate ) = split( ' ', $row);
                        $srvinfo_h{'patchlvl'}{$name}{'version'} = $version;
                        $srvinfo_h{'patchlvl'}{$name}{'vendor'} = $vendor;
                        $srvinfo_h{'patchlvl'}{$name}{'cert'} = $cert;
                        $srvinfo_h{'patchlvl'}{$name}{'instdate'} = $instdate;
                     }
                  } else {
                     $logger->error("cannot open $srvpath/patchlvl - abort");
                     $retc=99;
                  }

               } else { 
                  $logger->warn("$ll  no patchlvl data file exist - ignore  [" . session('user') . "]");
               }

               if ( -f "$srvpath/vms" ) {
                  $logger->trace("$ll  vms data file exist - read it  [" . session('user') . "]");

                  if (open(my $fh, '<', "$srvpath/vms")) {
                     while (my $row = <$fh>) {
                        chomp $row;
                        my ( $vmid, $rest ) = split( ' ', $row, 2);
                        $logger->trace("$ll  vm id: [$vmid]");
                        if ( $vmid =~ /^-?\d+\z/ ) {
                           my ( $vmname, $vmdatastore, $vmxfile, $guestos, $vmversion, $description) = split( ' ', $rest, 6);
                           # $logger->trace("$ll  vm name: [$vmname]");
                           $srvinfo_h{'vms'}{$vmid}{'vmname'} = $vmname;
                           $srvinfo_h{'vms'}{$vmid}{'vmds'} = $vmdatastore;
                           $srvinfo_h{'vms'}{$vmid}{'vmx'} = $vmxfile;
                           $srvinfo_h{'vms'}{$vmid}{'os'} = $guestos;
                           $srvinfo_h{'vms'}{$vmid}{'vmver'} = $vmversion;
                           $description =~ s/\s+$//;                                                                                                                 # no trailing white
                           $srvinfo_h{'vms'}{$vmid}{'descr'} = $description;
                        } else {
                           $logger->debug("$ll  line with: [$vmid] is not a vm id - ignore");
                        }
                     }
                  } else {
                     $logger->error("cannot open $srvpath/vms - abort");
                     $retc=99;
                  }

               } else { 
                  $logger->warn("$ll  no vm data file exist - ignore  [" . session('user') . "]");
               }


               unless ($retc) {
                  if ( $global{'logprod'} < 10000 ) {
                     my $dumpout = Dumper( \%srvinfo_h );
                     $logger->trace("$ll getsrvinfo_esxi srvinfo_h dump: $dumpout");
                  }
               } ## end unless ($retc)
               
               unless ($retc) {
                  $logger->info("$ll  write info.server json file");
                  $retc = writejsonfile( "$srvpath/info.server", \%srvinfo_h );
               }

            } else {
               $logger->error("cannot run rinfo to get esxi info");
            }
         } ## end unless ($retc)
      } else {
         $logger->trace("$ll server $server not connected - srv offline ");
         set_flash("!W:Server $server offline - cannot get all information");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub getsrvinfo_esxi


sub getsrvinfo_xen {
   my $llback = $logger->level();

   # $logger->level($global{'logprod'});
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc      = 0;
   my %srvinfo_h;
   
   my ( $server, $srvpath ) = @_;
   $logger->trace("$ll   server: $server");
   $logger->trace("$ll   path: $srvpath");
   
   unless ($retc) {
      $logger->info("$ll delete old infos for $server");
      my $command = "$global{'toolsdir'}/delinfodir -l $global{'logfile'}.log -s $server";
      $logger->trace("$ll  cmd: [$command]");
      my $xenupd = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      if ( $retc == 0 ) {
         $logger->trace("$ll   ok");
      } else {
         $logger->trace("");
      }
   } ## end unless ($retc)
   unless ($retc) {
      $logger->info("$ll  test if server online");
      my $p = Net::Ping->new( $global{'pingprot'} );
      if ( $p->ping($server) ) {
         $logger->trace("$ll server $server connected");
         unless ($retc) {
            my %xen = ();
            $logger->info("$ll  get server parameter");
            $retc = get_xensingle( $server, \%xen, "xe host-param-list uuid=\\\$(xe host-list name-label=$server --minimal)" );
            while ( ( $k, $v ) = each %xen ) {
               $srvinfo_h{'xenparams'}{$k} = $v;
            }
            undef %xen;
         } ## end unless ($retc)

         unless ($retc) {
            $logger->info("$ll get xen informations from $server");
            my $command = "$global{'toolsdir'}/rinfo -l $global{'logfile'}.log -s $server -i";
            $logger->trace("$ll  cmd: [$command]");
            my $xenupd = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            if ( $retc == 0 ) {
               $logger->trace("$ll   ok");
            } else {
               $logger->trace("");
            }
         } ## end unless ($retc)

         unless ($retc) {
            my %xen = ();
            $logger->info("$ll get pif informations from $server");
            $retc = get_xenmulti( $server, \%xen, "xe pif-list host-name-label=$server params=" );
            while ( ( $k, $v ) = each %xen ) {
               $srvinfo_h{'xenpifs'}{$k} = $v;
            }
            undef %xen;
         } ## end unless ($retc)
         unless ($retc) {
            my %xen = ();
            $logger->info("$ll get sr local informations from $server");
            $retc = get_xenmulti( $server, \%xen, "xe sr-list params= host=$server shared=false" );
            while ( ( $k, $v ) = each %xen ) {
               $srvinfo_h{'xensrs'}{$k} = $v;
            }
            undef %xen;
         } ## end unless ($retc)
         unless ($retc) {
            my %xen = ();
            $logger->info("$ll get sr shared informations from $server");
            $retc = get_xenmulti( $server, \%xen, "xe sr-list params= shared=true" );
            while ( ( $k, $v ) = each %xen ) {
               $srvinfo_h{'xenpoolsrs'}{$k} = $v;
            }
            undef %xen;
         } ## end unless ($retc)
         unless ($retc) {
            my %xen = ();
            $logger->info("$ll get vm list informations from $server");
            $retc = get_xenmulti( $server, \%xen, "xe vm-list is-control-domain=false params= resident-on=\\\$\(xe host-list name-label=$server --minimal\)" );
            while ( ( $k, $v ) = each %xen ) {
               $srvinfo_h{'xenvms'}{$k} = $v;
            }
            undef %xen;
         } ## end unless ($retc)
         unless ($retc) {
            my %xen = ();
            $logger->info("$ll  get pool information from $server");
            $retc = get_xensingle( $server, \%xen, "xe pool-list params=" );
            while ( ( $k, $v ) = each %xen ) {
               $srvinfo_h{'xenpool'}{$k} = $v;
            }
            undef %xen;
         } ## end unless ($retc)
         unless ($retc) {
            my %xen = ();
            $logger->info("$ll  read config now");
            $retc = get_masterconfig( $server, \%xen );
            while ( ( $k, $v ) = each %xen ) {
               $srvinfo_h{'xenconf'}{$k} = $v;
            }
            undef %xen;
         } ## end unless ($retc)
         unless ($retc) {
            if ( $global{'logprod'} < 10000 ) {
               my $dumpout = Dumper( \%srvinfo_h );
               $logger->trace("$ll getsrvinfo_xen srvinfo_h dump: $dumpout");
            }
         } ## end unless ($retc)
         
         unless ($retc) {
            $logger->info("$ll  write info.server json file");
            $retc = writejsonfile( "$srvpath/info.server", \%srvinfo_h );
         }
         
         unless ($retc) {
            $logger->info("$ll  get xen update file");
            $retc = get_xenupdfile($server);
         }
      } else {
         $logger->trace("$ll server $server not connected - srv offline ");
         set_flash("!W:Server $server offline - cannot get all information");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub getsrvinfo_xen


sub get_srv_data_fork {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my ( $srv, $srvpath, $typ ) = @_;

   my $retc   = 0;
   my $taskid = 0;
   my $fh;
   my $errmsg;

   if ( "$srv" eq "" ) {
      $errmsg = "no server to read data given";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
      $retc = 99;
   } elsif ( "$srvpath" eq "" ) {
      $errmsg = "no server path to read data given";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
      $retc = 98;
   } elsif ( "$typ" eq "" ) {
      $errmsg = "no server typ given";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
      $retc = 97;

   } else {
      my $not_reading=no_reading("srv","$srv");
      $logger->trace("$ll  already reading: $not_reading");
      if ( $not_reading ) {
         $retc = db_set_info( "srv", $srv, "reading", TimeStamp(11) );

         my $srvlastfile = "$srvpath/info.last";
         unless ( unlink($srvlastfile) ) {
            $logger->debug("$ll  $srvlastfile does not exist - do not need to delete!");
         } else {
            $logger->debug("$ll  $srvlastfile deleted!");
         }

         # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
         $addcmd = 'server get data ' . $srv . ',running data collector routine for server: ' . $srv . ',' . session('user') . ',myShowTask,TASKID,' . $srv . ',srv,no';
         $logger->trace("$ll  cmd: [$addcmd]");
         my $srvtaskid = task_add( $addcmd, 'force' );

         if ($srvtaskid) {
            $logger->trace("$ll  fork now to id ($srvtaskid)");
            fork and return $retc;
            my $tasklog = $global{'logdir'} . "/task-" . $srvtaskid;
            $logger->trace("$ll  task log: $tasklog");
            $retc = tasklog_add($tasklog);

            if ( $typ =~ m/^esxi/ ) {
               $retc = getsrvinfo_esxi( $srv, $srvpath );
            } elsif ( $typ =~ m/^xen/ ) {
               $retc = getsrvinfo_xen( $srv, $srvpath );
            } elsif ( $typ =~ m/^co/ ) {
               $retc = getsrvinfo_co( $srv, $srvpath );
            } elsif ( $typ =~ m/^rh/ ) {
               $retc = getsrvinfo_rh( $srv, $srvpath );
            } else {
               $logger->error("unsupported srv [$server] typ found [$typ] !");
               $retc = 99;
            }

            my $fintime = TimeStamp(11);
            $retc = db_set_info( "srv", $srv, "finish", $fintime );

            unless ( unlink($srvlastfile) ) {
               $logger->debug("$ll  $srvlastfile does not exist - do not need to delete!");
            } else {
               $logger->debug("$ll  $srvlastfile deleted!");
            }

            open $fh, '>', $srvlastfile or $retc = 88;
            if ($retc) {
               $errmsg = "Cannot open $srvlastfile";
               $logger->error("$ll $errmsg");
               set_flash("!E:$errmsg");
            } else {
               print $fh $fintime;
               close($fh);
            }

            $logger->debug("$ll  delete task - with blocking");
            $retc = task_del( $srvtaskid, 'yes' );
            $logger->trace("$ll  delete task log file");
            $logger->trace("$ll  task log: $tasklog");
            $retc = tasklog_remove($tasklog);
            exit;                                                                                                               # if fork than exit here

         } else {
            $logger->error("cannot get a no new task id - abort");
            $retc=99;
         }
      } 
   } ## 

   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $retc;
} ## end sub fork_get_pool_data








sub getsrvinfo_co {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc      = 0;
   my $server    = shift();
   my $srvinfo_h = shift();

   unless ($retc) {
      $logger->trace("$ll delete old infos for $server");
      my $command = "$global{'toolsdir'}/delinfodir -l $global{'logfile'}.log -s $server";
      $logger->trace("$ll  cmd: [$command]");
      my $xenupd = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      if ( $retc == 0 ) {
         $logger->trace("$ll   ok");
      } else {
         $logger->trace("");
      }
   } ## end unless ($retc)
   if ( $global{'logprod'} < 10000 ) {
      my $dumpout = Dumper( \$srvcfg_h );
      $logger->trace("$ll Overview-Dump: $dumpout");
   }
   unless ($retc) {
      $logger->debug("$ll   test if server online");
      my $p = Net::Ping->new( $global{'pingprot'} );
      if ( $p->ping($server) ) {
         $logger->trace("$ll server $server connected");
         unless ($retc) {
            $logger->trace("$ll get centos informations from $server");
            my $command = "$global{'toolsdir'}/rinfo -l $global{'logfile'}.log -s $server -i";
            $logger->trace("$ll  cmd: [$command]");
            my $upd = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            if ( $retc == 0 ) {
               $logger->trace("$ll   ok");
            } else {
               $logger->trace("");
            }
         } ## end unless ($retc)
      } else {
         $logger->trace("$ll server $server not connected - srv offline ");
         set_flash("!W:Server $server offline - cannot get all information");
      }
   } ## end unless ($retc)

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub getsrvinfo_co

sub getsrvinfo_rh {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc      = 0;
   my $server    = shift();
   my $srvinfo_h = shift();

   unless ($retc) {
      $logger->trace("$ll delete old infos for $server");
      my $command = "$global{'toolsdir'}/delinfodir -l $global{'logfile'}.log -s $server";
      $logger->trace("$ll  cmd: [$command]");
      my $xenupd = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      if ( $retc == 0 ) {
         $logger->trace("$ll   ok");
      } else {
         $logger->trace("");
      }
   } ## end unless ($retc)
   if ( $global{'logprod'} < 10000 ) {
      my $dumpout = Dumper( \$srvcfg_h );
      $logger->trace("$ll Overview-Dump: $dumpout");
   }
   unless ($retc) {
      $logger->debug("$ll   test if server online");
      my $p = Net::Ping->new( $global{'pingprot'} );
      if ( $p->ping($server) ) {
         $logger->trace("$ll server $server connected");
         unless ($retc) {
            $logger->trace("$ll get redhat informations from $server");
            my $command = "$global{'toolsdir'}/rinfo -l $global{'logfile'}.log -s $server -i";
            $logger->trace("$ll  cmd: [$command]");
            my $upd = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            if ( $retc == 0 ) {
               $logger->trace("$ll   ok");
            } else {
               $logger->trace("");
            }
         } ## end unless ($retc)
      } else {
         $logger->trace("$ll server $server not connected - srv offline ");
         set_flash("!W:Server $server offline - cannot get all information");
      }
   } ## end unless ($retc)



   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub getsrvinfo_rh

sub deploy_scripts {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $typ        = shift();
   my $srv        = shift();
   my $tasklog    = shift();
   my $copyscript = "$global{'toolsdir'}/cpvi";

   unless ($retc) {
      $logger->trace("$ll call script for $srv");
      my $command = "$copyscript -l $tasklog.log -s $srv ";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         set_flash("!S:esxi vi scripts updated on $srv");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Error during deploy vi tool scripts to server $srv";
         set_flash("!E:$errmsg");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub deploy_scripts

sub deploy_scripts_lxmodel {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $lxmodel = shift();
   my $tasklog = shift();
   unless ($retc) {
      $logger->trace("$ll call cpvi script for $lxmodel");
      my $command = "${dirs}../tools/cpvi -l $tasklog.log -m $lxmodel ";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         set_flash("!S:linux server vi scripts updated on $lxmodel");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Error during deploy vi tool scripts to server";
         set_flash("!E:$errmsg");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub deploy_scripts_lxmodel

sub deploy_scripts_vc {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $vc      = shift();
   my $tasklog = shift();
   unless ($retc) {
      $logger->trace("$ll call cpvi script for $vc");
      my $command = "${dirs}../tools/cpvi -l $tasklog.log -c $vc ";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         set_flash("!S:esxi vi scripts updated on $vc");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Error during deploy vi tool scripts to server";
         set_flash("!E:$errmsg");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub deploy_scripts_vc

sub reset_block_vc {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $vc = shift;
   $logger->trace("$ll  reset blockade for vc: $vc");
   unless ($retc) {
      my $command = $global{'progdir'} . "/fsic.pl -q -l $global{'logdir'}/fsi --delflag s_block --pool $vc";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         set_flash("!I:vc $vc blockade canceled");
      } else {
         $logger->error("failed cmd [$eo]");
         can $errmsg= "Cannot reset vc $vc blockade";
         set_flash("!E:cannot reset vc $vc blockade");
      }
   } ## end unless ($retc)
   unless ($retc) {
      my $id = task_findid( $vc, 'yes' );
      if ($id) {
         $logger->debug("$ll  found task $id - delete them too");
         $retc = task_del($id);
         unless ($retc) {
            $logger->trace("$ll  remove task log");
            $retc = tasklog_remove( $global{'logdir'} . "/task-" . $id );
         }
      } else {
         $logger->trace("$ll  no task for $control found");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub reset_block_vc

sub shutdownsrv {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $srv = shift;
   $logger->trace("$ll  shutdown server $srv");
   $logger->debug("$ll   test if server online");
   my $p = Net::Ping->new( $global{'pingprot'} );

   if ( $p->ping($srv) ) {
      $logger->debug("$ll ip $srv connected");
      $logger->debug("$ll test if server is in maintenance mode");
      my $command = "$global{'toolsdir'}/srvctrl -l $global{'logdir'}/fsi.log -c -s $srv";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      if ( $retc == 1 ) {
         $logger->trace("$ll  server in maintenance mode");
         $retc = 0;
      } elsif ( $retc == 0 ) {
         $logger->trace("$ll  server is not maintenance mode - try to set mm");
         my $command = "$global{'toolsdir'}/srvctrl -l $global{'logdir'}/fsi.log -m -s $srv";
         $logger->trace("$ll  cmd: [$command]");
         my $eo = qx($command  2>&1);
         $retc = $?;
         $retc = $retc >> 8 unless ( $retc == -1 );
         unless ($retc) {
            $logger->debug("$ll  server is now in maintenance mode");
         } else {
            $errmsg = "Cannot set maintenance mode on $srv";
            $logger->error($errmsg);
         }
      } else {
         $logger->error("unknown maintenance mode status on $srv = cmd [$eo]");
         $errmsg = "unknown maintenance mode status on $srv";
      }
      unless ($retc) {
         $logger->debug("$ll  server $srv is in maintenance mode");
         my $command = "$global{'toolsdir'}/srvctrl -l $global{'logdir'}/fsi.log -o -s $srv";
         $logger->trace("$ll  cmd: [$command]");
         my $eo = qx($command  2>&1);
         $retc = $?;
         $retc = $retc >> 8 unless ( $retc == -1 );
         unless ($retc) {
            $logger->trace("$ll  ok");
         } else {
            $logger->error("failed shutdown server $srv cmd [$eo]");
            $errmsg = "Cannot shutdown on $srv";
         }
      } ## end unless ($retc)
   } else {
      $logger->trace("$ll ip $srv not connected - srv offline ");
      $retc   = 77;
      $errmsg = "";
   }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub shutdownsrv

sub exitmaintenancemode {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $srv = shift;
   $logger->trace("$ll  server $srv exit maintenance mode");
   $logger->debug("$ll   test if server online");
   my $p = Net::Ping->new( $global{'pingprot'} );

   if ( $p->ping($srv) ) {
      $logger->trace("$ll server $srv connected");
      my $command = "$global{'toolsdir'}/srvctrl -l $global{'logdir'}/fsi -s $srv -e";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         my $command = $global{'progdir'} . "/fsic.pl -l $global{'logdir'}/fsi --setflag s_online --set O --server $srv";
         $logger->trace("$ll  cmd: [$command]");
         my $eo = qx($command  2>&1);
         $retc = $?;
         $retc = $retc >> 8 unless ( $retc == -1 );
         unless ($retc) {
            $logger->trace("$ll  set flag s_online to O");
         }
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot exit maintenance mode on $server";
      }
   } else {
      $logger->trace("$ll server $srv not connected - srv offline ");
      $retc   = 77;
      $errmsg = "";
   }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub exitmaintenancemode

sub portal_del_srv {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $mac       = shift;
   my $typ       = shift;
   my $pool      = shift;
   my $srvid     = shift;
   my $server    = shift;
   my $poolcount = 0;
   
   if ( "$server" eq "" ) {
      $logger->error("no server to delete given - abort");
      $retc=99;
   } else {
      $logger->trace("$ll  rubbish: $global{'rubbishdir'}");
      my $macobj = Net::MAC->new( 'mac' => $mac, 'die' => 0 );
      my $macsym = $macobj->convert( 'delimiter' => '-' );
      $logger->trace("$ll  mac: $macsym");
      $logger->trace("$ll  typ: $typ");
      $logger->trace("$ll  pool: $pool");
      $logger->trace("$ll  srv: $server");
   
   
      $retc = portal_del_log($server);
   
      unless ($retc) {                                                                                                                # remove pxe sys
         local $File::Copy::Recursive::RMTrgDir = 2;
         my $orig = "$global{'pxesysdir'}/$macsym";
         my $dest = $global{'rubbishdir'} . "/pxe_" . $macsym . "-" . TimeStamp(13);
         $logger->debug("$ll  move: $orig -> $dest");
         my $rc = dirmove( $orig, $dest );
         unless ($rc) {
            $errmsg = $!;
            $logger->error("err moving server config dir to rubbish");
            $logger->error("$errmsg");
            $retc = 99;
         } else {
            $logger->info("$ll  ok");
         }
      } ## end unless ($retc)
   
      unless ($retc) {                                                                                                                # remove rc sys
         local $File::Copy::Recursive::RMTrgDir = 2;
         my $orig = "$global{'rcsysdir'}/$macsym";
         my $dest = $global{'rubbishdir'} . "/rc_" . $macsym . "-" . TimeStamp(13);
         $logger->debug("$ll  move: $orig -> $dest");
         my $rc = dirmove( $orig, $dest );
         unless ($rc) {
            $errmsg = $!;
            $logger->error("err moving server rc config dir to rubbish");
            $logger->error("$errmsg");
            $retc = 99;
         } else {
            $logger->info("$ll  ok");
         }
      } ## end unless ($retc)
   
      unless ($retc) {
         if ( "$typ" =~ m/^xen/ ) {
            $logger->debug("$ll  check if last server in pool");
            $poolcount = $serverhash_p->{$srvid}{'x_poolcount'};
            $logger->debug("$ll  server in pool = $poolcount");
            if ( $poolcount == 1 ) {
               $logger->debug("$ll  last server in pool $pool");
               $logger->debug("$ll  delete install dir");
               my $poolpath = $global{'fsiinstdir'} . "/" . $typ . "/ks/pool/" . $pool;
               $retc = delete_path($poolpath);
            } ## end if ( $poolcount == 1 )
         } ## end if ( "$typ" =~ m/^xen/ )
      } ## end unless ($retc)
      unless ($retc) {
         $logger->debug("$ll  delete server db $server");
         my $command = $global{'progdir'} . "/fsic.pl -q --delsrv $server -l $global{'logdir'}/fsi";
         $logger->trace("$ll  cmd: [$command]");
         my $eo = qx($command  2>&1);
         $retc = $?;
         $retc = $retc >> 8 unless ( $retc == -1 );
         unless ($retc) {
            $logger->trace("$ll  ok");
         } else {
            $logger->error("failed cmd [$eo]");
            $errmsg = "Cannot update db";
         }
      } ## end unless ($retc)
      unless ($retc) {
         if ( "$typ" =~ m/^xen/ ) {
            $logger->debug("$ll  xen needs more deleting jobs");
            $logger->trace("$ll  pool: $pool");
   
            # if last server in pool do not go on
            unless ($retc) {
               $logger->debug("$ll  create pool ssh files from config");
               my $command = "$global{'toolsdir'}/cssh2pool -l $global{'logfile'}.log -p $pool ";
               $logger->trace("$ll  cmd: [$command]");
               my $eo = qx($command  2>&1);
               $retc = $?;
               $retc = $retc >> 8 unless ( $retc == -1 );
               unless ($retc) {
                  $logger->trace("$ll  ok");
               } else {
                  $logger->error("failed cmd [$eo]");
                  $errmsg = "Cannot create new pool ssh files";
               }
            } ## end unless ($retc)
            unless ($retc) {
               $logger->debug("$ll  create ssh pool config in server config dir");
               my $command = "$global{'toolsdir'}/cssh2cfg -l $global{'logfile'}.log -p $pool ";
               $logger->trace("$ll  cmd: [$command]");
               my $eo = qx($command  2>&1);
               $retc = $?;
               $retc = $retc >> 8 unless ( $retc == -1 );
               unless ($retc) {
                  $logger->trace("$ll  ok");
               } else {
                  $logger->error("failed cmd [$eo]");
                  $errmsg = "Cannot deploy new ssh files to all server config dirs";
               }
            } ## end unless ($retc)
            unless ($retc) {
               $logger->debug("$ll  deploy to all online server in pool");
               my $command = "$global{'toolsdir'}/cssh2server -l $global{'logfile'}.log -p $pool ";
               $logger->trace("$ll  cmd: [$command]");
               my $eo = qx($command  2>&1);
               $retc = $?;
               $retc = $retc >> 8 unless ( $retc == -1 );
               unless ($retc) {
                  $logger->trace("$ll  ok");
               } else {
                  $logger->error("failed cmd [$eo]");
                  $errmsg = "Cannot deploy new ssh files to all server";
               }
            } ## end unless ($retc)
            unless ($retc) {
               $logger->debug("$ll  check xen pool counter");
               my $command = $global{'progdir'} . "/fsic.pl -q --xpc -l $global{'logdir'}/fsi";
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
            } ## end unless ($retc)
         }                                                                                                                            # if xen pool
      } ## end unless ($retc)
      unless ($retc) {
         $logger->debug("$ll  delete symlink if exist");
         my $delsym = $global{'symdir'} . "/01-" . $macsym;
         $logger->debug("$ll  del: $delsym ");
         unless ( unlink($delsym) ) {
            $logger->debug("$ll  $delsym does not exist - do not need to delete!");
         } else {
            $logger->debug("$ll  $delsym deleted!");
         }
      } ## end unless ($retc)
   }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub portal_del_srv

sub portal_del_log {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $srv = shift;
   if ( "$srv" eq "" ) {
      $logger->error("no server to del log given - abort");
      $retc=99;
   } else {
      $logger->trace("$ll  del server log: $srv");
      unless ($retc) {
         my $command = "$global{'toolsdir'}/dellog -l $global{'logfile'}.log -s $srv ";
         $logger->trace("$ll  cmd: [$command]");
         my $eo = qx($command  2>&1);
         $retc = $?;
         $retc = $retc >> 8 unless ( $retc == -1 );
         unless ($retc) {
            $logger->trace("$ll  ok");
         } else {
            $logger->error("failed cmd [$eo]");
            $errmsg = "Cannot delete logfile for $srv";
         }
      } ## end unless ($retc)
   }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub portal_del_log

sub portal_boot_srv {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $server = shift;

   $logger->trace("$ll  srv: $server");
   if ( "$server" eq "" ) {
      $logger->error("no server given - abort");
      $retc = 99;
   } else {
      my $addcmd = 'boot ' . $server . ',boot server ' . $server . ',' . session('user') . ',myShowTask,TASKID,' . $server . ',srv,no';
      $logger->trace("$ll  cmd: $addcmd");
      my $taskid = task_add( $addcmd, 'force' );

      if ($taskid) {
         $logger->trace("$ll  fork now to id ($taskid)");
         set_flash("!I:Start reboot server [$server] ...");
         fork and return $retc;
         my $tasklog = $global{'logdir'} . "/task-" . $taskid;
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_add($tasklog);


         $logger->trace("$ll  reboot server $server");
         $logger->debug("$ll   test if server online");
         my $p = Net::Ping->new( $global{'pingprot'} );

         if ( $p->ping($server) ) {
            $logger->debug("$ll ip $server connected");
            $logger->debug("$ll test if server is in maintenance mode");
            my $command = "$global{'toolsdir'}/srvctrl -l $global{'logdir'}/fsi.log -c -s $server";
            $logger->trace("$ll  cmd: [$command]");
            my $eo = qx($command  2>&1);
            $retc = $?;
            $retc = $retc >> 8 unless ( $retc == -1 );
            if ( $retc == 1 ) {
               $logger->trace("$ll  server in maintenance mode");
               $retc = 0;
            } elsif ( $retc == 0 ) {
               $logger->trace("$ll  server is not maintenance mode - try to set mm");
               my $command = "$global{'toolsdir'}/srvctrl -l $global{'logdir'}/fsi.log -m -s $server";
               $logger->trace("$ll  cmd: [$command]");
               my $eo = qx($command  2>&1);
               $retc = $?;
               $retc = $retc >> 8 unless ( $retc == -1 );
               unless ($retc) {
                  $logger->debug("$ll  server is now in maintenance mode");
               } else {
                  $errmsg = "Cannot set maintenance mode on $server";
                  $logger->error($errmsg);
               }
            } else {
               $logger->error("unknown maintenance mode status on $server = cmd [$eo]");
               $errmsg = "unknown maintenance mode status on $server";
            }
            unless ($retc) {
               $logger->debug("$ll  server $server is in maintenance mode");
               my $command = "$global{'toolsdir'}/srvctrl -l $global{'logdir'}/fsi.log -r -s $server";
               $logger->trace("$ll  cmd: [$command]");
               my $eo = qx($command  2>&1);
               $retc = $?;
               $retc = $retc >> 8 unless ( $retc == -1 );
               unless ($retc) {
                  $logger->trace("$ll  ok");
               } else {
                  $logger->error("failed reboot server $server cmd [$eo]");
                  $errmsg = "Cannot reboot on $server";
               }
            } ## end unless ($retc)
         } else {
            $logger->trace("$ll ip $server not connected - srv offline ");
            $retc   = 77;
            $errmsg = "";
         }

         $logger->debug("$ll  delete task");
         $retc = task_del( $taskid, 'yes' );
         $logger->trace("$ll  delete task log file");
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_remove($tasklog);
         unless ($retc) {
            set_flash("!S:Boot server successful start [$server] $errmsg");
         } else {
            set_flash("!E:Error booting server [$errmsg] ");
         }
         exit;                                                                                                                     # if fork than exit here
      } else {
         set_flash("!E:Server $server cannot get new task id ");
         $retc = 99;
      }
   } ## end else [ if ( "$server" eq "" ) ]



   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub portal_boot_srv

sub clean_pool_patches {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $pool = shift;
   unless ($retc) {
      my $command = "$global{'toolsdir'}/xencleanpatch -l $global{'logdir'}/fsi.log -p $pool ";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         set_flash("!S:xen pool $pool patch dirs cleaned");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Error during cleaning xen pool patch dirs [$pool]";
         set_flash("!E:$errmsg");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub clean_pool_patches

sub deploy_scripts_xenpool {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $pool    = shift;
   my $tasklog = shift();
   unless ($retc) {
      my $command = "$global{'toolsdir'}/cpvi -l $tasklog.log -p $pool ";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         set_flash("!S:xen vi scripts updated");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Error during deploy vi tool scripts to server";
         set_flash("!E:$errmsg");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub deploy_scripts_xenpool

sub deploy_sshkeys {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $pool = shift;
   unless ($retc) {
      my $command = "$global{'toolsdir'}/sshkeyclean -l $global{'logdir'}/fsi.log -p $pool";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Error during cleaning ssh keys in pool";
         set_flash("!E:$errmsg");
      }
   } ## end unless ($retc)
   unless ($retc) {
      my $command = "$global{'toolsdir'}/cssh2server -l $global{'logdir'}/fsi.log -p $pool";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         set_flash("!S:ssh keys deployed");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Error during deploy ssh keys";
         set_flash("!E:$errmsg");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub deploy_sshkeys

sub reset_block_pool {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $pool = shift;
   $logger->trace("$ll  reset blockade for pool: $pool");
   unless ($retc) {
      my $command = $global{'progdir'} . "/fsic.pl -q --sub $flvl -l $global{'logdir'}/fsi --delflag s_block --pool $pool";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         set_flash("!I:Pool $pool blockade canceled");
      } else {
         $logger->error("failed cmd [$eo]");
         can $errmsg= "Cannot reset pool $pool blockade";
         set_flash("!E:cannot reset pool $pool blockade");
      }
   } ## end unless ($retc)
   unless ($retc) {
      my $id = task_findid( $pool, 'yes' );
      if ($id) {
         $logger->debug("$ll  found task $id - delete them too");
         $retc = task_del($id);
         unless ($retc) {
            $logger->trace("$ll  remove task log");
            $retc = tasklog_remove( $global{'logdir'} . "/task-" . $id );
         }
      } else {
         $logger->trace("$ll  no task for $control found");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub reset_block_pool

sub check_poolrun {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   unless ($retc) {
      my $command = $global{'progdir'} . "/fsic.pl --sub $flvl -q --chkpoolrun -l $global{'logdir'}/fsi";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot check pool.run dir";
         set_flash("!E:Error checking pool.run dir");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub check_poolrun

sub reset_msg_pool {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $pool = shift;
   $logger->trace("$ll  reset message and error for pool: $pool");
   unless ($retc) {
      my $command = $global{'progdir'} . "/fsic.pl --sub $flvl -q --delflag s_msg --pool $pool -l $global{'logdir'}/fsi";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot reset message";
      }
   } ## end unless ($retc)
   unless ($retc) {
      my $command = $global{'progdir'} . "/fsic.pl --sub $flvl -q --delflag s_insterr --pool $pool -l $global{'logdir'}/fsi";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot reset msg flag";
      }
   } ## end unless ($retc)
   if ($retc) {
      set_flash("!E:ERROR: cannot reset pool $pool messages");
   } else {
      set_flash("!S:Pool messages reseted in $pool.");
   }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub reset_msg_pool

sub haenable {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $pool = shift;
   
   if ( "$pool" eq "" ) {
      $logger->error("no pool defined - abort");
      set_flash("!E:no pool defined for disabling ha");
      $retc=99;
   } else {

      # parm:   <short>                ,<long>                                           ,<jobuser>              ,<url>     ,<logdatei>,<control>  ,<ctyp>,<block>
      $addcmd = 'enable ha ' . $pool . ',enable ha in pool [' . $pool . '],' . session('user') . ',myShowTask,TASKID,' . $pool . ',xp,yes';
      $logger->trace("$ll cmd: $addcmd");
      $taskid = task_add($addcmd);
   
      if ($taskid) {
         $logger->trace("$ll  fork now to id ($taskid)");
         set_flash("!I:Start enabling ha in pool $pool ...");                                                                            # fsi message for fork
   
         $pid = fork();
         if ( $pid < 0 ) {
            $logger->error("Failed to fork process - abort");
            $retc = 99;
         } elsif ( $pid == 0 ) {                                                                                                      #child process
            $logger->debug("$ll  CHILD PROCESS [$pid]");
   
            my $tasklog = $global{'logdir'} . "/task-" . $taskid;
            $logger->trace("$ll  task log: $tasklog");
            $retc = tasklog_add($tasklog);
   
            $logger->info("$ll   enable ha in pool $pool");
            my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--sub", $flvl, "--haon", "$pool", "-l", $tasklog );
            $retc = system(@command);
            $retc = $retc >> 8 unless ( $retc == -1 );
   
            unless ($retc) {
               $logger->trace("$ll  ha enabled");
            } else {
               $logger->warn("cannot enable ha in pool");
               set_flash("!E:Error: cannot enable ha in pool $pool");
            }
            unless ($retc) {
               $logger->info("$ll   check ha status in $pool");
               my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--sub", $flvl, "--chkha", "$pool", "-l", $tasklog );
               $retc = system(@command);
               $retc = $retc >> 8 unless ( $retc == -1 );
               unless ($retc) {
                  $logger->trace("$ll  ha status checked");
               } else {
                  $logger->warn("cannot check ha in pool");
                  set_flash("!E:Error: cannot check ha in pool $pool");
               }
            } ## end unless ($retc)
   
            $logger->debug("$ll  delete task and blocking");
            $retc = task_del( $taskid, 'yes' );
   
            $logger->trace("$ll  delete task log file");
            $logger->trace("$ll  task log: $tasklog");
            $retc = tasklog_remove($tasklog);
   
            unless ($retc) {
               set_flash("!S:ha enabled in pool $pool");
            } else {
               set_flash("!E:Error enabling ha in pool $pool");
            }
   
            exit $retc;
         } else {                                                                                                                     #execute rest of parent}
            $logger->trace("$ll  PARENT PROCESS - go on after fork ($pid)");
         }
      } else {
         set_flash("!E:Server $server cannot get new task id - cannot fork");
         $retc = 99;
      }
   }

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub haenable

sub hadisable {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $pool = shift;
   
   if ( "$pool" eq "" ) {
      $logger->error("no pool defined - abort");
      set_flash("!E:no pool defined for disabling ha");
      $retc=99;
   } else {

      # parm:   <short>                ,<long>                                           ,<jobuser>              ,<url>     ,<logdatei>,<control>  ,<ctyp>,<block>
      $addcmd = 'disable ha ' . $pool . ',disable ha in pool [' . $pool . '],' . session('user') . ',myShowTask,TASKID,' . $pool . ',xp,yes';
      $logger->trace("$ll cmd: $addcmd");
      $taskid = task_add($addcmd);
   
      if ($taskid) {
         $logger->trace("$ll  fork now to id ($taskid)");
         set_flash("!I:Start disabling ha in pool $pool ...");                                                                            # fsi message for fork
   
         $pid = fork();
         if ( $pid < 0 ) {
            $logger->error("Failed to fork process - abort");
            $retc = 99;
         } elsif ( $pid == 0 ) {                                                                                                      #child process
            $logger->debug("$ll  CHILD PROCESS [$pid]");
   
            my $tasklog = $global{'logdir'} . "/task-" . $taskid;
            $logger->trace("$ll  task log: $tasklog");
            $retc = tasklog_add($tasklog);
   
            $logger->info("$ll   disable ha in pool $pool");
            my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--sub", $flvl, "--haoff", "$pool", "-l", $tasklog );
            $retc = system(@command);
            $retc = $retc >> 8 unless ( $retc == -1 );
   
            unless ($retc) {
               $logger->trace("$ll  ha disable");
            } else {
               $logger->warn("cannot disable ha in pool");
               set_flash("!E:Error: cannot disable ha in pool $pool");
            }
            unless ($retc) {
               $logger->info("$ll   check ha status in $pool");
               my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--sub", $flvl, "--chkha", "$pool", "-l", $tasklog );
               $retc = system(@command);
               $retc = $retc >> 8 unless ( $retc == -1 );
               unless ($retc) {
                  $logger->trace("$ll  ha status checked");
               } else {
                  $logger->warn("cannot check ha in pool");
                  set_flash("!E:Error: cannot check ha in pool $pool");
               }
            } ## end unless ($retc)
   
            $logger->debug("$ll  delete task and blocking");
            $retc = task_del( $taskid, 'yes' );
   
            $logger->trace("$ll  delete task log file");
            $logger->trace("$ll  task log: $tasklog");
            $retc = tasklog_remove($tasklog);
   
            unless ($retc) {
               set_flash("!S:ha enabled in pool $pool");
            } else {
               set_flash("!E:Error enabling ha in pool $pool");
            }
   
            exit $retc;
         } else {                                                                                                                     #execute rest of parent}
            $logger->trace("$ll  PARENT PROCESS - go on after fork ($pid)");
         }
      } else {
         set_flash("!E:Server $server cannot get new task id - cannot fork");
         $retc = 99;
      }
   }

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub hadisable

sub del_pool_dir {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $pool = shift;
   
   if ( "$pool" eq "" ) {
      $logger->error("$ll no pool given - abort");
      $retc=99;
   }

   unless ($retc) {
      # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
      $addcmd = 'del pool dir ' . $pool . ',poweroff and delete pool config dir for pool: ' . $pool . ',' . session('user') . ',myShowTask,TASKID,' . $pool . ',xp,no';
      $logger->debug("$ll  no pool blockade for cmd: [$addcmd]");
      my $pooltaskid = task_add( $addcmd, 'force' );
   
      if ($pooltaskid) {
         $logger->trace("$ll  fork now to id ($pooltaskid)");
         fork and return $retc;
         my $tasklog = $global{'logdir'} . "/task-" . $pooltaskid;
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_add($tasklog);
      
      
         $logger->info("$ll   power off all server in pool");
         my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--sub", $flvl, "--pooloff", $pool, "-l", $tasklog );
         $retc = system(@command);
         $retc = $retc >> 8 unless ( $retc == -1 );
         $logger->trace("$ll  rc=$retc");
      
         unless ($retc) {
            $logger->trace("$ll  all server powered off");
         } else {
            $logger->warn("cannot power off all server in pool");
            set_flash("!E:Error: cannot power off server in pool");
         }
         unless ($retc) {
            $logger->info("$ll   delete pool config dir");
            my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--sub", $flvl, "--dpcd", $pool, "-l", $tasklog );
            $retc = system(@command);
            $retc = $retc >> 8 unless ( $retc == -1 );
            $logger->trace("$ll  rc=$retc");
            unless ($retc) {
               $logger->trace("$ll  pool config dir deleted");
               set_flash("!S:pool dir deleted and all server powered of");
            } else {
               if ( $retc eq 6 ) {
                  $logger->debug("$ll  config dir does not exist");
                  set_flash("!W:no config dir exist");
                  $retc = 0;
               } else {
                  $logger->warn("cannot delete pool config dir (rc=$retc)");
                  set_flash("!E:Error: cannot delete pool config dir");
               }
            } ## end else
         } ## end unless ($retc)
         unless ($retc) {
            $logger->info("$ll   delete master flag in pool");
            my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--sub", $flvl, "--delflag", "s_xenmaster", "--pool", $pool, "-l", $tasklog );
            $retc = system(@command);
            $retc = $retc >> 8 unless ( $retc == -1 );
            unless ($retc) {
               $logger->trace("$ll  master flags deleted");
            } else {
               $logger->warn("cannot delete master flag in pool");
               set_flash("!E:Error: cannot delete master flag in pool");
            }
         } ## end unless ($retc)
   
   
         $logger->debug("$ll  delete task - with blocking");
         $retc = task_del( $pooltaskid, 'yes' );
         $logger->trace("$ll  delete task log file");
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_remove($tasklog);
         exit;                                                                                                               # if fork than exit here
   
      }
   }


   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub del_pool_dir

sub del_pool_run {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $pool = shift;
   unless ($retc) {
      $logger->info("$ll   delete pool running dir");
      my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--sub", $flvl, "--dprd", $pool, "-l", $global{'logdir'} ."/fsi" );
      $retc = system(@command);
      $retc = $retc >> 8 unless ( $retc == -1 );
      $logger->trace("$ll  rc=$retc");
      unless ($retc) {
         $logger->trace("$ll  pool run dir deleted");
         set_flash("!S:pool run dir deleted");
      } else {
         if ( $retc eq 6 ) {
            $logger->debug("$ll  pool run dir does not exist");
            set_flash("!W:no pool run dir exist");
            $retc = 0;
         } else {
            $logger->warn("cannot delete pool run dir (rc=$retc)");
            set_flash("!E:Error: cannot delete pool run dir");
         }
      } ## end else
   } ## end unless ($retc)
   unless ($retc) {
      $logger->info("$ll   delete running flag in pool");
      my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "--sub", $flvl, "--delflag", "s_instrun", "--pool", $pool, "-l", $global{'logdir'} ."/fsi" );
      $retc = system(@command);
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  instrun flags deleted");
      } else {
         $logger->warn("cannot delete instrun flag in pool");
         set_flash("!E:Error: cannot delete instrun flag in pool");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub del_pool_run

sub portal_check_master {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $pool = shift;
   $logger->info("$ll   check master in pool [$pool]");
   my @command = ( $global{'progdir'} . "/fsic.pl", "-q", "-l", $global{'logdir'} . "/fsi", "--sub", $flvl, "--chkmaster", $pool );
   $retc = system(@command);

   unless ($retc) {
      $logger->trace("$ll  found master [$poolmaster]");
      set_flash("!S:Check pool master ok");
      $retc = db_reload();
      unless ($retc) {
         $logger->debug("  reload db ok");
      } else {
         set_flash("!E:Check pool master ok - but reload db error !");
      }
   } else {
      $logger->warning("failed find master");
      set_flash("!W:Error: cannot find master for pool");
   }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub portal_check_master


sub clean_ssh_keys_esxi {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   $logger->trace("$ll  reset message and error");

   unless ($retc) {
      my $command = "$global{'toolsdir'}/sshkeyclean -y esxi -l $global{'logdir'}/fsi.log";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         set_flash("!S:All ESXi SSH keys successful cleanup");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot clean ESXi ssh keys";
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub clean_ssh_keys_esxi

sub reset_msg {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $id     = shift;
   my $server = $serverhash_p->{$id}{'db_srv'};                                                                                    # auslesen hash eintrag aus hash referenz
   $logger->trace("$ll  reset message and error for server: $server");

   unless ($retc) {
      my $command = $global{'progdir'} . "/fsic.pl -q --delflag s_msg --server $server -l $global{'logdir'}/fsi";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot reset message for $server";
      }
   } ## end unless ($retc)
   unless ($retc) {
      my $command = $global{'progdir'} . "/fsic.pl -q --delflag s_insterr --server $server -l $global{'logdir'}/fsi";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot reset msg flag";
      }
   } ## end unless ($retc)
   if ($retc) {
      set_flash("!E:ERROR: cannot reset server $server messages");
   } else {
      set_flash("!S:reset server $server messages ok.");
   }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub reset_msg

sub reset_block {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $id     = shift;
   my $server = $serverhash_p->{$id}{'db_srv'};                                                                                    # auslesen hash eintrag aus hash referenz
   $logger->trace("$ll  reset blockade for server: $server");

   unless ($retc) {
      my $command = $global{'progdir'} . "/fsic.pl -q --delflag s_block --server $server -l $global{'logdir'}/fsi";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         set_flash("!W:server $server blockade canceled");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot reset server $server blockade";
         set_flash("!E:ERROR: cannot reset server $server blockade");
      }
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub reset_block


sub reset_msg_all {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   $logger->trace("$ll  reset message and error");

   unless ($retc) {
      my $command = $global{'progdir'} . "/fsic.pl -q --delflag s_msg -l $global{'logdir'}/fsi";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot reset message";
      }
   } ## end unless ($retc)
   unless ($retc) {
      my $command = $global{'progdir'} . "/fsic.pl -q --delflag s_insterr -l $global{'logdir'}/fsi";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed cmd [$eo]");
         $errmsg = "Cannot reset msg flag";
      }
   } ## end unless ($retc)
   unless ($retc) {
      set_flash("!S:Clear all messages");
   }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub reset_msg_all


sub add_lx {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   my $scriptcall = shift();
   my $server     = shift();
   my $file;
   my $fh;


   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub add_lx



1;
__END__
