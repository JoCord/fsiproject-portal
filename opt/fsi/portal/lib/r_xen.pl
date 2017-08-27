our $xenpool;

sub clean_ssh_keys_xen {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   $retc = 0;
   $logger->trace("$ll  reset message and error");

   # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
   $addcmd = 'clean xen ssh keys,running clean all xenserver ssh keys,' . session('user') . ',myShowTask,TASKID,all,all,no';
   my $taskid = task_add( $addcmd, 'force' );

   if ($taskid) {
      $logger->trace("$ll  fork now to id ($taskid)");
      fork and return $retc;
      my $tasklog = $global{'logdir'} . "/task-" . $taskid;
      $logger->trace("$ll  task log: $tasklog");
      $retc = tasklog_add($tasklog);

      unless ($retc) {
         my $command = "$global{'toolsdir'}/sshkeyclean -y xen -l $tasklog.log";
         $logger->trace("$ll  cmd: [$command]");
         my $eo = qx($command  2>&1);
         $retc = $?;
         $retc = $retc >> 8 unless ( $retc == -1 );
         unless ($retc) {
            $logger->trace("$ll  ok");
            set_flash("!S:All Xen SSH keys successful cleanup");
         } else {
            $logger->error("failed cmd [$eo]");
            $errmsg = "Cannot clean xen ssh keys";
         }
      } ## end unless ($retc)

      $logger->debug("$ll  delete task - with blocking");
      $retc = task_del( $taskid, 'yes' );
      $logger->trace("$ll  delete task log file");
      $logger->trace("$ll  task log: $tasklog");
      $retc = tasklog_remove($tasklog);
      exit;                                                                                                               # if fork than exit here
   }

   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub clean_ssh_keys_xen



sub get_masterconfig {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc       = 0;
   my $poolmaster = shift();
   my $masterc    = shift();
   my $mac        = db_get_mac($poolmaster);
   if ( "$mac" eq "" ) {
      $errmsg = "Error getting master xenserver $poolmaster mac";
      set_flash("!E:$errmsg");
   } else {
      $logger->trace("$ll  mac: $mac");
      $logger->trace("$ll  mac: $mac");

      my $conffile = "";
      if ( -e "$global{'pxesysdir'}/$mac/xen6.pool" ) {
         $conffile = "$global{'pxesysdir'}/$mac/xen6.pool";
         $logger->trace("$ll  pool config file: $conffile");   
      } elsif ( -e "$global{'pxesysdir'}/$mac/xen7.pool" ) {
         $conffile = "$global{'pxesysdir'}/$mac/xen7.pool";
         $logger->trace("$ll  pool config file: $conffile");   
      }
      
      if ( "$conffile" eq "" ) {
         $errmsg = "cannot find pool config file for $poolmaster / $mac !";
         set_flash("!E:$errmsg");
      } else {
         my $poolconf = new Config::General("$conffile");
         my %poolhash = $poolconf->getall;
         %$masterc = ();
         %$masterc = %poolhash;
      } ## end else
   } ## end else [ if ( "$mac" eq "" ) ]
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub get_masterconfig

sub get_xenupdfile {
   my $llback = $logger->level();

   # $logger->level($global{'logprod'});
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $srv  = shift();
   if ( -z $srv ) {
      $logger->error("no server define to get xen update list from");
      $retc = 99;
   }
   unless ($retc) {
      $logger->trace("$ll get xen update file from $srv");

      my $xentyp  = db_get_typ_srv($srv);
      my $osmain  = substr $xentyp, 3, 1; 
      $logger->trace("$ll  xen os version: $osmain");
      my $xencfg="xen$osmain";
      $logger->trace("$ll  xen cfg: $xencfg");
      
      my $xenpool = db_get_control($srv);
      $logger->trace("$ll  xen inst typ and ver: $xentyp");
      $logger->trace("$ll  pool: $xenpool");
      if ( $xentyp eq "" ) {
         $logger->error("$ll  cannot detect xen inst typ version - abort");
         $retc = 77;
      } elsif ( $xenpool eq "" ) {
         $logger->error("$ll  cannot detect xen pool - abort");
         $retc = 78;
      } else {
         my $command = "$global{'toolsdir'}/rmc -q -l $global{'logfile'}.log -s $srv -j \"cat $global{'xeninstdir'}/$xencfg.upd\" ";
         $logger->trace("$ll  rmc cmd: [$command]");
         my $xenupd = qx($command  2>&1);
         $retc = $?;
         $retc = $retc >> 8 unless ( $retc == -1 );
         if ( $retc == 0 ) {
            $logger->trace("$ll  ok [$xenupd]");

            my $fh;
            unless ($retc) {
               my $file = "$global{'fsiinstdir'}/$xentyp/ks/pool/$xenpool/upd_$srv";
               open $fh, '>', $file or $retc = 88;
               if ($retc) {
                  $errmsg = "Cannot open $file";
               }
            } ## end unless ($retc)
            unless ($retc) {
               print $fh "$xenupd";
            }
            close($fh);
         } elsif ( $retc == 1 ) {
            $logger->trace("$ll  error rc=1 - try to find out what happen");
            if ( $xenupd =~ m/Datei oder Verzeichnis nicht gefunden/ ) {
               $logger->info("$ll  no xen$xencfg.upd found on $srv - ignore");
               $retc = 0;
            } elsif ( $xenupd =~ m/No such file or directory/ ) {
               $logger->info("$ll  no xen$xencfg.upd found on $srv - ignore");
               $retc = 0;
            } else {
               $logger->error("failed cmd [$xenupd]");
               $errmsg = "Error getting xen server update list";
               set_flash("!E:$errmsg");
            }
         } else {
            $logger->error("failed cmd [$xenupd]");
            $errmsg = "Error getting xen server update list";
            set_flash("!E:$errmsg");
         }

      }

   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub get_xenupdfile

sub get_xensingle {
   my $llback = $logger->level();

   $logger->level($global{'logprod'});
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $srv  = shift();
   my $xen  = shift();
   my $cmd  = shift();
   $logger->trace("$ll  single cmd: [$cmd]");

   if ( -z $srv ) {
      $logger->error("no server define - abort");
      $retc = 99;
   }

   unless ($retc) {
      my $command = "$global{'toolsdir'}/rmc -q -l $global{'logfile'}.log -s $srv -j \"$cmd\" ";
      $logger->trace("$ll  rmc cmd: [$command]");
      my $hostout = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         my @lines = split( /\n/, $hostout );
         foreach my $line (@lines) {
            my ( $key, $val ) = split( ':', $line, 2 );
            if ( defined $key ) {
               $val =~ s/^\s+//;
               $val =~ s/\s+$//;
               $val =~ s/\<//g;
               $val =~ s/\>//g;
               $key =~ s/\([^)]+\)//g;
               $key =~ s/^\s+//;
               $key =~ s/\s+$//;
               unless ( $val eq "" || $key eq "" ) {
                  ${$xen}{$key} = $val;
               }
            } ## end if ( defined $key )
         } ## end foreach my $line (@lines)
      } else {
         $logger->error("failed cmd [$netout]");
         $errmsg = "Error getting xen server settings";
         set_flash("!E:$errmsg");
         $retc = 0;
      } ## end else
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub get_xensingle

sub get_xenmulti {
   my $llback = $logger->level();

   $logger->level($global{'logprod'});
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc   = 0;
   my $server = shift();
   my $nets   = shift();
   my $cmd    = shift();
   $logger->trace("$ll  multi cmd: [$cmd]");
   $logger->trace("$ll  multi net: [$nets]");
   $logger->trace("$ll  multi srv: [$server]");

   if ( -z $server ) {
      $logger->error("no server define - abort");
      $retc = 99;
   }
   if ( -z $nets ) {
      $logger->error("no net define - abort");
      $retc = 99;
   }
   if ( -z $cmd ) {
      $logger->error("no command define - abort");
      $retc = 99;
   }

   unless ($retc) {
      my $command = "$global{'toolsdir'}/rmc -q -l $global{'logfile'}.log -s $server -j \"$cmd\" ";
      $logger->trace("$ll  cmd: [$command]");
      my $netout = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         my @lines = split( /\n/, $netout );
         my $uuid = "";
         foreach my $line (@lines) {
            my ( $key, $val ) = split( ':', $line, 2 );

            # my ($key, $val) = split ":",$line;
            if ( defined $key ) {
               if ( $key =~ /^uuid/i ) {
                  $val =~ s/^\s+//;
                  $val =~ s/\s+$//;
                  $uuid = $val;
               } else {
                  $val =~ s/^\s+//;
                  $val =~ s/\s+$//;
                  $val =~ s/\<//g;
                  $val =~ s/\>//g;
                  $key =~ s/\([^)]+\)//g;
                  $key =~ s/^\s+//;
                  $key =~ s/\s+$//;
                  unless ( $val eq "" || $key eq "" ) {
                     ${$nets}{$uuid}{$key} = $val;
                  }
               } ## end else [ if ( $key =~ /^uuid/i ) ]
            } ## end if ( defined $key )
         } ## end foreach my $line (@lines)
      } else {
         $errmsg = "executing cmd [$cmd]";
         $logger->error("$errmsg");
         $logger->error("failed cmd [$netout]");
         set_flash("!E:$errmsg");
         $retc = 0;
      } ## end else
   } ## end unless ($retc)
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub get_xenmulti

sub get_pool_data {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");

   my $xenpool=shift();

   my $retc=0;
   my %vmshash;
   my %hosthash;
   my %srhash;
   my %nethash;
   my %masterhash;
   my %xenhash;
   my %poolmasterhash;
   my $poolmaster="";
   my $poolpath="";
   my $xentyp="";
   
   my %vmnethash;
   my %vmhdhash;
   
   unless ( defined $xenpool ) {
      $logger->error("no xenpool to get data given");
      $retc=99;
   } else {
      $logger->info("$ll  get xen pool data from [$xenpool]");
      $poolmaster = get_master_db_file($xenpool);
      if ( "$poolmaster" eq "" ) {
         $logger->warn("$ll  no master in db, try to run findmaster");
         $poolmaster = get_master($xenpool);
         if ( "$poolmaster" eq "" ) {
            $logger->warn("$ll  cannot get poolmaster from pool [$xenpool]");
            $retc=98;
         }
      }
      
      unless ( $retc ) {
         $logger->info("$ll  poolmaster: [$poolmaster]");
         $logger->info("$ll  get pool xen version");
         $xentyp=db_get_typ_pool($xenpool);
         if ( "$xentyp" eq "" ) {
            $logger->error("cannot get xen ver for pool [$xenpool]");
            $retc=97;
         }
      
         unless ( $retc ) {
            $poolpath   = "$global{'fsiinstdir'}/$xentyp/ks/pool/$xenpool";
            $logger->trace("$ll  poolpath: $poolpath");
         }
         
         unless ($retc) {
            $logger->info("$ll  start pool master server info collection ...");
            my $srvpath="$global{'fsiinstdir'}/$xentyp/ks/pool/$xenpool/info/$poolmaster";
            $logger->trace("$ll  get master server [$poolmaster] data");
            $retc = getsrvinfo_xen( $poolmaster, $srvpath );
            unless ($retc) {
               $srvhash_ref=readjsonfile("$srvpath/info.server");
               if ( $logger->is_trace() ) {
                  my $dumpout = Dumper( \%poolmasterhash );
                  $logger->trace("$ll XenPool Poolmaster Serverinfo Dump: $dumpout");
               }
               $retc = writejsonfile( "$poolpath/info.mastersrv", \%poolmasterhash );
            } ## end unless ($retc)
         } ## end unless ($retc)
         
         
         unless ( $retc ) {
            $logger->info("$ll  read vm list ...");
            $retc = get_xenmulti( $poolmaster, \%vmshash, "xe vm-list is-control-domain=false params=" );
            unless ($retc) {
               $logger->trace("$ll  get vm hash ok");
               if ( $logger->is_trace() ) {
                  my $dumpout = Dumper( \%vmshash );
                  $logger->trace("$ll XenPool VM List Dump: $dumpout");
               }

               $logger->info("$ll  read vm net list ...");
               $retc = get_xenmulti( $poolmaster, \%vmnethash, "xe vm-vif-list --multiple params=" );
               unless ($retc) {
                  $logger->trace("$ll  get vm nic hash ok");
                  if ( $logger->is_trace() ) {
                     my $dumpout = Dumper( \%vmnethash );
                     $logger->trace("$ll XenPool VM Net Dump: $dumpout");
                  }

                  $logger->info("$ll  read vm hd list ...");
                  $retc = get_xenmulti( $poolmaster, \%vmhdhash, "xe vm-disk-list --multiple vbd-params= vdi-params=" );
                  unless ($retc) {
                     $logger->trace("$ll  get vm hd hash ok");
                     if ( $logger->is_trace() ) {
                        my $dumpout = Dumper( \%vmhdhash );
                        $logger->trace("$ll XenPool VM HD Dump: $dumpout");
                     }

                     foreach my $vm_uuid ( keys %vmshash ) {
                        $logger->trace("$ll   vm uuid: $vm_uuid");

                        foreach my $vbd_uuid ( keys %vmhdhash ) {
                           $logger->trace("$ll   vbd uuid: $vbd_uuid");
                           if ( defined "$vmhdhash{$vbd_uuid}{'vm-uuid'}" ) {
                              if ( "$vmhdhash{$vbd_uuid}{'vm-uuid'}" eq "$vm_uuid" ) {
                                 $logger->trace("$ll   found vbd for vm");
                                 
                                 foreach my $vdi_uuid ( keys %vmhdhash ) {
                                    $logger->trace("$ll   vdi uuid: $vdi_uuid");
                                    if ( defined "$vmhdhash{$vdi_uuid}{'vbd-uuids'}" ) {
                                       if ( "$vmhdhash{$vdi_uuid}{'vbd-uuids'}" eq "$vbd_uuid" ) {
                                          $logger->trace("$ll   found vdi for vbd for vm");
                                          $vmshash{$vm_uuid}{'vbd'}{$vbd-uuid}{'vdi'}{$vdi_uuid}{'virtual-size'} = $vmhdhash{$vdi_uuid}{'virtual-size'};
                                          $vmshash{$vm_uuid}{'vbd'}{$vbd-uuid}{'vdi'}{$vdi_uuid}{'physical-utilisation'} = $vmhdhash{$vdi_uuid}{'physical-utilisation'};
                                          $vmshash{$vm_uuid}{'vbd'}{$vbd-uuid}{'vdi'}{$vdi_uuid}{'name-label'} = $vmhdhash{$vdi_uuid}{'name-label'};
                                       }
                                    }
                                 }

                              }
                           }
                        }
                        
                     }

                     unless ($retc) {
                        $logger->debug("$ll  write vm infos to json file");
                        $retc = writejsonfile( "$poolpath/info.vms", \%vmshash );
                     } else {
                        $logger->error("something wrong during work on vm data");
                     }
                  } else {
                     $logger->error("cannot read hd vbd and vdi list");
                  }
               } else {
                  $logger->error("cannot read vm nics / vif list");
               }
            } else {
               $logger->warn("$ls  cannot read vm list or no vms exist");
               $retc=0;
            }
         }
         
         unless ($retc) {
            $logger->info("$ll  read host list parameters ...");
            $retc = get_xenmulti( $poolmaster, \%hosthash, "xe host-list params=" );
            unless ($retc) {
               if ( $logger->is_trace() ) {
                  my $dumpout = Dumper( \%hosthash );
                  $logger->trace("$ll XenPool Host List Dump: $dumpout");
               }
               $retc = writejsonfile( "$poolpath/info.hosts", \%hosthash );
            } ## end unless ($retc)
         } ## end unless ($retc)
      
         unless ($retc) {
            $logger->info("$ll  read storage list parameter ...");
            $retc = get_xenmulti( $poolmaster, \%srhash, "xe sr-list params=" );
            unless ($retc) {
               if ( $logger->is_trace() ) {
                  my $dumpout = Dumper( \%srhash );
                  $logger->trace("$ll XenPool SR List Dump: $dumpout");
               }
               $retc = writejsonfile( "$poolpath/info.srs", \%srhash );
            } ## end unless ($retc)
         } ## end unless ($retc)
      
         unless ($retc) {
            $logger->info("$ll  read network list parameter ...");
            $retc = get_xenmulti( $poolmaster, \%nethash, "xe network-list params=" );
            unless ($retc) {
               if ( $logger->is_trace() ) {
                  my $dumpout = Dumper( \%nethash );
                  $logger->trace("$ll XenPool Network List Dump: $dumpout");
               }
               $retc = writejsonfile( "$poolpath/info.net", \%nethash );
            } ## end unless ($retc)
         } ## end unless ($retc)
      
         unless ($retc) {
            $logger->info("$ll  read master parameter ...");
            $retc = get_masterconfig( $poolmaster, \%masterhash );
            unless ($retc) {
               if ( $logger->is_trace() ) {
                  my $dumpout = Dumper( \%masterhash );
                  $logger->trace("$ll XenPool Master Dump: $dumpout");
               }
               $retc = writejsonfile( "$poolpath/info.master", \%masterhash );
            } ## end unless ($retc)
         } ## end unless ($retc)
      
         unless ($retc) {
            $logger->info("$ll  read master parameter list ...");
            $retc = get_xensingle( $poolmaster, \%xenhash, "xe host-param-list uuid=\\\$(xe host-list name-label=$poolmaster --minimal)" );
            unless ($retc) {
               if ( $logger->is_trace() ) {
                  my $dumpout = Dumper( \%xenhash );
                  $logger->trace("$ll XenPool Poolmaster List Dump: $dumpout");
               }
               $retc = writejsonfile( "$poolpath/info.xen", \%xenhash );
            } ## end unless ($retc)
         } ## end unless ($retc)
   
      }

   }
  
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
}
 

sub get_pool_lvmohba {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");

   my $xenpool=shift();
   my $tasklog=shift();

   my $retc=0;
   my $poolpath="";
   my $xentyp="";
   my $poolmaster="";
   my %lunhash;

   unless ( defined $xenpool ) {
      $logger->error("no xenserver pool for lvmohba scan given");
      $retc=99;
   } else {
      $logger->info("$ll  get xenserver pool [$xenpool]");
   }
      
   unless ( $retc ) {
      $poolmaster = get_master_db_file($xenpool);
      if ( "$poolmaster" eq "" ) {
         $logger->warn("$ll  no master in db, try to run findmaster");
         $poolmaster = get_master($xenpool);
         if ( "$poolmaster" eq "" ) {
            $logger->warn("$ll  cannot get poolmaster from pool [$xenpool]");
            $retc=98;
         }
      }
   }
      
   unless ( $retc ) {
      $xentyp=db_get_typ_srv($poolmaster);
      if ( "$xentyp" eq "" ) {
         $logger->error("cannot get xen type for server [$poolmaster]");
         $retc=97;
      } else {
         $logger->trace("$ll  typ: [$xentyp]");
      }
   }

   unless ( $retc ) {
      $poolpath   = "$global{'fsiinstdir'}/$xentyp/ks/pool/$xenpool";
      $logger->trace("$ll  poolpath: $poolpath");
   }
         
   unless ($retc) {
      $logger->info("$ll  probe for new fibre channel luns ...");
      
      my $command = "$global{'toolsdir'}/rmc -q -l ${tasklog}.log -s $poolmaster -j \'fsicrlsr --quiet --do print\' ";
      $logger->trace("$ll  cmd: [$command]");
      my $probexml = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ( $retc ) {
         $logger->trace("$ll  analyse fc probe now ...");

         $probexml =~ s/\t|\r|\n//g;                                                                                                               # kill \n\t\r in probexml return
         my $devlist=substr($probexml, index($probexml, '<Devlist>'));

         my $devref = XMLin($devlist, KeyAttr => { BlockDevice => 'SCSIid' }, ForceArray => [ 'BlockDevice' ]);
         my %devhash=%$devref;
         
         if ( $logger->is_trace() ) {
            my $dumpout = Dumper( \%devhash );
            $logger->trace("$ll new fc lun dump: $dumpout");
         }
         $retc = writejsonfile( "$poolpath/info.srsnew", \%devhash );
         if ($retc) {
            $logger->error("cannot write json file [$poolpath/info.srsnew]");
         }
      } else {
         $logger->error("cannot probe for new fibre channel [$probexml]");
      }
   }
         
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
}
  
sub get_pool_srs {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");

   my $xenpool=shift();

   my $retc=0;
   my $poolpath="";
   my $xentyp="";
   my $poolmaster="";
   my %srhash;

   unless ( defined $xenpool ) {
      $logger->error("no xenserver pool for srs scan given");
      $retc=99;
   } else {
      $logger->info("$ll  get xenserver pool [$xenpool]");
   }
      
   unless ( $retc ) {
      $poolmaster = get_master_db_file($xenpool);
      if ( "$poolmaster" eq "" ) {
         $logger->warn("$ll  no master in db, try to run findmaster");
         $poolmaster = get_master($xenpool);
         if ( "$poolmaster" eq "" ) {
            $logger->warn("$ll  cannot get poolmaster from pool [$xenpool]");
            $retc=98;
         }
      }
   }
      
   unless ( $retc ) {
      $xentyp=db_get_typ_srv($poolmaster);
      if ( "$xentyp" eq "" ) {
         $logger->error("cannot get xen typ for server [$poolmaster]");
         $retc=97;
      } else {
         $logger->trace("$ll  typ: [$xentyp]");
      }
   }

   unless ( $retc ) {
      $poolpath   = "$global{'fsiinstdir'}/$xentyp/ks/pool/$xenpool";
      $logger->trace("$ll  poolpath: $poolpath");
   }

   unless ($retc) {
      $logger->info("$ll  read storage list parameter ...");
      $retc = get_xenmulti( $poolmaster, \%srhash, "xe sr-list params=" );
      unless ($retc) {
         if ( $logger->is_trace() ) {
            my $dumpout = Dumper( \%srhash );
            $logger->trace("$ll XenPool SR List Dump: $dumpout");
         }
         $retc = writejsonfile( "$poolpath/info.srs", \%srhash );
      } ## end unless ($retc)
   } ## end unless ($retc)
         
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
}


sub get_pool_data_fork {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $xenpool    = shift();

   my $retc       = 0;
   my $xentyp     = "";
   my $poolpath   = "";
   my $pooltaskid = 0;
   my $fh;
   my $errmsg;

   if ( "$xenpool" eq "" ) {
      $errmsg = "no xenpool to read data given";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
      $retc = 99;
   } else {
      $xentyp=db_get_typ_pool($xenpool);
      if ( "$xentyp" eq "" ) {
         $errmsg = "no xenver for reading xen pool data found";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc = 98;
      } else {
         $logger->trace("$ll xentyp: $xentyp / pool: $xenpool");
         $poolpath   = "$global{'fsiinstdir'}/$xentyp/ks/pool/$xenpool";
         
         my $not_reading=no_reading("xp","$xenpool");
         $logger->trace("$ll  already reading: $not_reading");
         if ( $not_reading ) {
            $retc = db_set_info( "xp", $xenpool, "reading", TimeStamp(11) );

            my $poollastfile = "$poolpath/info.last";
            unless ( unlink($poollastfile) ) {
               $logger->debug("$ll  $poollastfile does not exist - do not need to delete!");
            } else {
               $logger->debug("$ll  $poollastfile deleted!");
            }


            # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
            my $addcmd = 'xenpool get data ' . $xenpool . ',running data collector routine for pool: ' . $xenpool . ',' . session('user') . ',myShowTask,TASKID,' . $xenpool . ',xp,no';
            $logger->debug("$ll  no pool blockade for cmd: [$addcmd]");
            my $pooltaskid = task_add( $addcmd, 'force' );

            if ($pooltaskid) {
               $logger->trace("$ll  fork now to id ($pooltaskid)");
               fork and return $retc;
               my $tasklog = $global{'logdir'} . "/task-" . $pooltaskid;
               $logger->trace("$ll  task log: $tasklog");
               $retc = tasklog_add($tasklog);

               $retc=get_pool_data($xenpool);

               my $fintime = TimeStamp(11);
               $retc = db_set_info( "xp", $xenpool, "finish", $fintime );

               unless ( unlink($poollastfile) ) {
                  $logger->debug("$ll  $poollastfile does not exist - do not need to delete!");
               } else {
                  $logger->debug("$ll  $poollastfile deleted!");
               }

               open $fh, '>', $poollastfile or $retc = 88;
               if ($retc) {
                  $errmsg = "Cannot open $poollastfile";
                  $logger->error("$ll $errmsg");
                  set_flash("!E:$errmsg");
               } else {
                  print $fh $fintime;
                  close($fh);
               }

               $logger->debug("$ll  delete task - with blocking");
               $retc = task_del( $pooltaskid, 'yes' );
               $logger->trace("$ll  delete task log file");
               $logger->trace("$ll  task log: $tasklog");
               $retc = tasklog_remove($tasklog);
               exit;                                                                                                               # if fork than exit here

            } else {
               $logger->info("$ll pool [$xenpool] already reading");
            }
         } ## end if ( no_reading( "xp", "$xenpool" ) )
      } ## 
   } ## end else [ if ( "$xenpool" eq "" ) ]

   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $retc;
} ## end sub fork_get_pool_data

sub get_pool_srs_fork {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $xenpool    = shift();

   my $retc       = 0;
   my $xentyp     = "";
   my $poolpath   = "";
   my $pooltaskid = 0;
   my $fh;
   my $errmsg;

   if ( "$xenpool" eq "" ) {
      $errmsg = "no xenpool to read data given";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
      $retc = 99;
   } else {
      $xentyp=db_get_typ_pool($xenpool);
      if ( "$xentyp" eq "" ) {
         $errmsg = "no xenver for reading xen pool data found";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc = 98;
      } else {
         $logger->trace("$ll xentyp: $xentyp / pool: $xenpool");
         $poolpath   = "$global{'fsiinstdir'}/$xentyp/ks/pool/$xenpool";

         my $not_reading=no_reading("srs","$xenpool");
         $logger->trace("$ll  already reading srs: $not_reading");
         if ( $not_reading ) {
            $retc = db_set_info( "srs", $xenpool, "reading", TimeStamp(11) );
            my $poollastfile = "$poolpath/lunlistreload.last";
            unless ( unlink($poollastfile) ) {
               $logger->debug("$ll  $poollastfile does not exist - do not need to delete!");
            } else {
               $logger->debug("$ll  $poollastfile deleted!");
            }
            

            # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
            my $addcmd = 'xenpool get data ' . $xenpool . ',running data collector routine for pool: ' . $xenpool . ',' . session('user') . ',myShowTask,TASKID,' . $xenpool . ',xp,no';
            $logger->debug("$ll  no pool blockade for cmd: [$addcmd]");
            my $pooltaskid = task_add( $addcmd, 'force' );

            if ($pooltaskid) {
               $logger->trace("$ll  fork now to id ($pooltaskid)");
               fork and return $retc;
               my $tasklog = $global{'logdir'} . "/task-" . $pooltaskid;
               $logger->trace("$ll  task log: $tasklog");
               $retc = tasklog_add($tasklog);

               $retc=get_pool_srs($xenpool);

               my $fintime = TimeStamp(11);
               $retc = db_set_info( "srs", $xenpool, "finish", $fintime );

               unless ( unlink($poollastfile) ) {
                  $logger->debug("$ll  $poollastfile does not exist - do not need to delete!");
               } else {
                  $logger->debug("$ll  $poollastfile deleted!");
               }

               open $fh, '>', $poollastfile or $retc = 88;
               if ($retc) {
                  $errmsg = "Cannot open $poollastfile";
                  $logger->error("$ll $errmsg");
                  set_flash("!E:$errmsg");
               } else {
                  print $fh $fintime;
                  close($fh);
               }
               
               $logger->debug("$ll  delete task - with blocking");
               $retc = task_del( $pooltaskid, 'yes' );
               $logger->trace("$ll  delete task log file");
               $logger->trace("$ll  task log: $tasklog");
               $retc = tasklog_remove($tasklog);
               exit;                                                                                                               # if fork than exit here

            } else {
               $logger->info("$ll pool [$xenpool] already reading");
            }
         } ## end if ( no_reading( "xp", "$xenpool" ) )
      } ## 
   } ## end else [ if ( "$xenpool" eq "" ) ]

   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $retc;
} ## end sub fork_get_pool_data

sub srs_destroy_fork {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");

   my $xenpool  = shift();
   my $uuids    = shift();

   my $retc       = 0;
   my $errmsg;

   if ( "$uuids" eq "" ) {
      $errmsg = "no sr uuids given - abort destroying sr";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
      $retc = 99;
   }
   
   unless ( $retc ) {
      if ( "$xenpool" eq "" ) {
         $errmsg = "xenpool to destroy srs not given";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc = 99;
      }
   }

   unless ( $retc ) {
      $xentyp=db_get_typ_pool($xenpool);
      if ( "$xentyp" eq "" ) {
         $errmsg = "no xenver / typ for reading xen pool data found";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc = 98;
      }
   }
   
   unless ( $retc ) {
      $logger->trace("$ll xentyp: $xentyp / pool: $xenpool");

      # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
      my $addcmd = 'destroy srs in pool ' . $xenpool . ',destroy existing fibre channel lun srs in pool: ' . $xenpool . ',' . session('user') . ',myShowTask,TASKID,' . $xenpool . ',xp,no';
      $logger->debug("$ll  no pool blockade for cmd: [$addcmd]");
      my $pooltaskid = task_add( $addcmd, 'force' );

      if ($pooltaskid) {
         $logger->trace("$ll  fork now to id ($pooltaskid)");
         fork and return $retc;
         my $tasklog = $global{'logdir'} . "/task-" . $pooltaskid;
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_add($tasklog);

         $retc=srs_destroy($tasklog,$xenpool,$uuids);

         unless ( $retc ) {
            $retc=get_pool_srs($xenpool);
         }
         unless ( $retc ) {
            $retc=get_pool_lvmohba($xenpool,$tasklog);
         }

         $logger->debug("$ll  delete task - with blocking");
         $retc = task_del( $pooltaskid, 'yes' );
         $logger->trace("$ll  delete task log file");
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_remove($tasklog);
         exit;                                                                                                               # if fork than exit here
      }
   } 

   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $retc;
}


sub srs_create_fork {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");

   my $xenpool  = shift();
   my $uuids    = shift();

   my $retc       = 0;
   my $errmsg;

   if ( "$uuids" eq "" ) {
      $errmsg = "no sr uuids given - abort creating sr";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
      $retc = 99;
   }
   
   unless ( $retc ) {
      if ( "$xenpool" eq "" ) {
         $errmsg = "xenpool to create srs not given";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc = 99;
      }
   }

   unless ( $retc ) {
      $xentyp=db_get_typ_pool($xenpool);
      if ( "$xentyp" eq "" ) {
         $errmsg = "no xenver / typ for reading xen pool data found";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc = 98;
      }
   }
   
   unless ( $retc ) {
      $logger->trace("$ll xentyp: $xentyp / pool: $xenpool");

      # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
      my $addcmd = 'create srs in pool ' . $xenpool . ',create new fibre channel lun srs in pool: ' . $xenpool . ',' . session('user') . ',myShowTask,TASKID,' . $xenpool . ',xp,no';
      $logger->debug("$ll  no pool blockade for cmd: [$addcmd]");
      my $pooltaskid = task_add( $addcmd, 'force' );

      if ($pooltaskid) {
         $logger->trace("$ll  fork now to id ($pooltaskid)");
         fork and return $retc;
         my $tasklog = $global{'logdir'} . "/task-" . $pooltaskid;
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_add($tasklog);

         $retc=srs_create($tasklog,$xenpool,$uuids);
         
         unless ( $retc ) {
            $retc=get_pool_srs($xenpool);
         }
         unless ( $retc ) {
            $retc=get_pool_lvmohba($xenpool,$tasklog);
         }

         $logger->debug("$ll  delete task - with blocking");
         $retc = task_del( $pooltaskid, 'yes' );
         $logger->trace("$ll  delete task log file");
         $logger->trace("$ll  task log: $tasklog");
         $retc = tasklog_remove($tasklog);
         exit;                                                                                                               # if fork than exit here
      }
   } 

   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $retc;
}



sub srs_create {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");

   my $logf     = shift();
   my $xenpool  = shift();
   my $uuids    = shift();

   my $retc       = 0;
   my $errmsg;
   my $poolmaster;

   unless ( defined $uuids ) {
      $errmsg = "no sr uuids given - abort creating sr";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
      $retc = 99;
   }

   unless ( $retc ) {
      unless ( defined $xenpool ) {
         $errmsg = "xenpool to create srs not given";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc = 99;
      }
   }
   
   unless ( $retc ) {
      unless ( defined $logf ) {
         $logf="$global{'logfile'}.log";
      }
   }
   
   unless ( $retc ) {
      $logger->info("$ll  get master from pool [$xenpool] ....");
      $poolmaster = get_master_db_file($xenpool);
      if ( "$poolmaster" eq "" ) {
         $logger->warn("$ll  no master in db, try to run findmaster");
         $poolmaster = get_master($xenpool);
         if ( "$poolmaster" eq "" ) {
            $logger->warn("$ll  cannot get poolmaster from pool [$xenpool]");
            $retc=98;
         }
      }
   }

   unless ( $retc ) {
      $logger->info("$ll  create fc lun srs in pool [$xenpool] on master [$poolmaster] ...");
      
      my $command = "$global{'toolsdir'}/rmc -l ${logf}.log -s $poolmaster -j \'fsicrlsr --do create --uuid " . $uuids . "' ";
      $logger->trace("$ll  cmd: [$command]");
      my $probexml = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      if ($retc) {
         $errmsg = "during rmc call on $poolmaster [$xenpool] with fsicrlsr $uuids";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc = 99;
      } else {
         $errmsg = "Creating fc lun srs ok in pool $xenpool";
         $logger->info("$ll $errmsg");
         set_flash("!I:$errmsg");
      }
   }

   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $retc;
}

sub srs_destroy {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");

   my $logf     = shift();
   my $xenpool  = shift();
   my $uuids    = shift();

   my $retc       = 0;
   my $errmsg;
   my $poolmaster;

   unless ( defined $uuids ) {
      $errmsg = "no sr uuids given - abort destroying sr";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
      $retc = 99;
   }
   
   unless ( $retc ) {
      unless ( defined $xenpool ) {
         $errmsg = "xenpool to destroy srs not given";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc = 99;
      }
   }

   unless ( $retc ) {
      unless ( defined $logf ) {
         $logf="$global{'logfile'}.log";
      }
   }
   
   unless ( $retc ) {
      $logger->info("$ll  get master from pool [$xenpool] ....");
      $poolmaster = get_master_db_file($xenpool);
      if ( "$poolmaster" eq "" ) {
         $logger->warn("$ll  no master in db, try to run findmaster");
         $poolmaster = get_master($xenpool);
         if ( "$poolmaster" eq "" ) {
            $logger->warn("$ll  cannot get poolmaster from pool [$xenpool]");
            $retc=98;
         }
      }
   }

   unless ( $retc ) {
      $logger->info("$ll  destroy fc lun srs in pool [$xenpool] on master [$poolmaster] ...");
      
      my $command = "$global{'toolsdir'}/rmc -l ${logf}.log -s $poolmaster -j \'fsicrlsr --do destroy --uuid " . $uuids . "' ";
      $logger->trace("$ll  cmd: [$command]");
      my $probexml = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      if ($retc) {
         $errmsg = "during rmc call on $poolmaster [$xenpool] with fsicrlsr $uuids";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc = 99;
      } else {
         $errmsg = "Destroying fc lun srs ok in pool $xenpool";
         $logger->info("$ll $errmsg");
         set_flash("!I:$errmsg");
      }
   }

   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $retc;
}

sub get_pool_lvmohba_fork {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $xenpool    = shift();

   my $retc       = 0;
   my $xentyp     = "";
   my $poolpath   = "";
   my $pooltaskid = 0;
   my $fh;
   my $errmsg;

   if ( "$xenpool" eq "" ) {
      $errmsg = "no xenpool to read data given";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
      $retc = 99;
   } else {
      $xentyp=db_get_typ_pool($xenpool);
      if ( "$xentyp" eq "" ) {
         $errmsg = "no xenver / typ for reading xen pool data found";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc = 98;
      } else {
         $logger->trace("$ll xentyp: $xentyp / pool: $xenpool");
         $poolpath   = "$global{'fsiinstdir'}/$xentyp/ks/pool/$xenpool";
         
         my $not_reading=no_reading("lvmohba","$xenpool");
         $logger->trace("$ll  already reading lvmohba: $not_reading");
         if ( $not_reading ) {
            $retc = db_set_info( "lvmohba", $xenpool, "reading", TimeStamp(11) );

            my $poollastfile = "$poolpath/lunnewlist.last";
            unless ( unlink($poollastfile) ) {
               $logger->debug("$ll  $poollastfile does not exist - do not need to delete!");
            } else {
               $logger->debug("$ll  $poollastfile deleted!");
            }

            # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
            my $addcmd = 'xenpool get data ' . $xenpool . ',running data collector routine for pool: ' . $xenpool . ',' . session('user') . ',myShowTask,TASKID,' . $xenpool . ',xp,no';
            $logger->debug("$ll  no pool blockade for cmd: [$addcmd]");
            my $pooltaskid = task_add( $addcmd, 'force' );

            if ($pooltaskid) {
               $logger->trace("$ll  fork now to id ($pooltaskid)");
               fork and return $retc;
               my $tasklog = $global{'logdir'} . "/task-" . $pooltaskid;
               $logger->trace("$ll  task log: $tasklog");
               $retc = tasklog_add($tasklog);

               $retc=get_pool_lvmohba($xenpool,$tasklog);

               my $fintime = TimeStamp(11);
               $retc = db_set_info( "lvmohba", $xenpool, "finish", $fintime );
               
               unless ( unlink($poollastfile) ) {
                  $logger->debug("$ll  $poollastfile does not exist - do not need to delete!");
               } else {
                  $logger->debug("$ll  $poollastfile deleted!");
               }

               open $fh, '>', $poollastfile or $retc = 88;
               if ($retc) {
                  $errmsg = "Cannot open $poollastfile";
                  $logger->error("$ll $errmsg");
                  set_flash("!E:$errmsg");
               } else {
                  print $fh $fintime;
                  close($fh);
               }

               $logger->debug("$ll  delete task - with blocking");
               $retc = task_del( $pooltaskid, 'yes' );
               $logger->trace("$ll  delete task log file");
               $logger->trace("$ll  task log: $tasklog");
               $retc = tasklog_remove($tasklog);
               exit;                                                                                                               # if fork than exit here

            } else {
               $logger->info("$ll pool [$xenpool] already reading lvmohba");
            }
         } ## end if ( no_reading( "xp", "$xenpool" ) )
      } ## 
   } ## end else [ if ( "$xenpool" eq "" ) ]

   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $retc;
} ## end sub fork_get_pool_data

sub status_last_2old {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc     = 0;
   my $statusfile = shift();
   my $last2old = 0;                                                                                                               # info.last to old
   my $errmsg;
   my $fh;

   if ( -f $statusfile ) {
      open $fh, '<', $statusfile or $retc = 88;
      if ($retc) {
         $errmsg = "Cannot open $statusfile";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
      } else {
         my $firstline = <$fh>;
         close($fh);
         $logger->trace("$ll read date/time: $firstline");
         my $parser   = DateTime::Format::Strptime->new( pattern => '%H:%M:%S - %d.%m.%Y' );
         my $dtfile   = $parser->parse_datetime($firstline);
         my $dtnow    = DateTime->now( time_zone => 'local' )->set_time_zone('floating');
         my $timediff = $dtnow->subtract_datetime($dtfile);
         $logger->trace("$ll  time difference: [$timediff->minutes]");

         if ( $timediff->minutes > $global{'readtimediff'} ) {
            $last2old = 1;                                                                                                         # older than
         }
      } ## end else [ if ($retc) ]
   } else {
      $errmsg = "cannot find file $statusfile";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
   }

   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $last2old;
} ## end sub status_last_2old




sub get_master_db_file {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc   = 0;
   my $pool   = shift();
   my $master = "";                                                                                                                # no master found

   if ( "$pool" eq "" ) {
      $logger->error("no pool given - abort");
   } else {
      my $dbh    = db_connect();
      my $sql    = "SELECT db_srv FROM $global{'dbt_ov'} WHERE ( s_xenmaster = 'M' AND db_controltyp = 'xp' AND db_control = '$pool' )";
      $logger->trace("$ll  sql: $sql");
      my $sth = $dbh->prepare($sql) or die $dbh->errstr;
      $sth->execute or die $sth->errstr;
      my $lastid = $sth->rows;
   
      if ( $lastid > 1 ) {
         $logger->error("$ll  $lastid master flags for pool $pool => abort");
         $rc = 99;
      } elsif ( $lastid == 1 ) {
         my @control = $sth->fetchrow_array;
         $logger->trace("$ll master: $control[0]");
         $master=$control[0];
      } else {
         $logger->trace("$ll  no master found in db for $pool");
      }
      $sth->finish();
      $retc = db_disconnect($dbh);
   }

   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $master;
} ## end sub get_master_db_file


sub set_auth {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   
   my ( $xenpool, $authmode ) = @_;
   $authmode=~ tr/A-ZÄÖÜ/a-zäöü/;

   if ( "$xenpool" eq "" ) {
      $errmsg = "no xenpool to read data given";
      $logger->error("$ll $errmsg");
      set_flash("!E:$errmsg");
      $retc = 99;
   } else {
      if ( ( "$authmode" eq "ad" ) || ( "$authmode" eq "loc" ) ) {
         $logger->trace("$ll  change pool [$xenpool] to $authmode");
   
   
   
         # parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
         my $addcmd = 'xenpool ' . $xenpool . ' to ' . $authmode . ',set xenpool ' . $xenpool . ' authentication to ' . $authmode . ',' . session('user') . ',myShowTask,TASKID,' . $xenpool . ',xp,no';
         $logger->debug("$ll  no pool blockade for cmd: [$addcmd]");
         my $pooltaskid = task_add( $addcmd, 'force' );

         if ($pooltaskid) {
            $logger->trace("$ll  fork now to id ($pooltaskid)");
            fork and return $retc;
            my $tasklog = $global{'logdir'} . "/task-" . $pooltaskid;
            $logger->trace("$ll  task log: $tasklog");
            $retc = tasklog_add($tasklog);
   
            # start fork tasks
            my $poolmaster = get_master_db_file($xenpool);
            if ( "$poolmaster" eq "" ) {
               $logger->warn("$ll  no master in db, try to run findmaster");
               $poolmaster = get_master($xenpool);
               if ( "$poolmaster" eq "" ) {
                  $logger->warn("$ll  cannot get poolmaster from pool [$xenpool]");
                  $retc=98;
               }
            }

            unless ($retc) {
               $logger->info("$ll  change pool [$xenpool] auth to [$authmode] ...");
               my $command = "$global{'toolsdir'}/rmc -l " . $global{'logfile'} . ".log -s $poolmaster -j 'fsipoolauth -s " . $authmode . "'";
               $logger->trace("$ll  cmd: [$command]");
               my $poolmaster = qx($command  2>&1);
               $retc = $?;
               $retc = $retc >> 8 unless ( $retc == -1 );
               $logger->trace("$ll  rc=$retc");
            
               unless ($retc) {
                  $logger->info("$ll changed pool [$xenpool] auth to [$authmode] successful");
                  set_flash("!I:changed pool [$xenpool] auth to [$authmode] successful");
               } else {
                  $errmsg = "cannot change pool [$xenpool] auth to [$authmode]";
                  $logger->error("$ll $errmsg");
                  set_flash("!E:$errmsg");
                  $retc=90;
               }
            }

            $logger->debug("$ll  delete task - with blocking");
            $retc = task_del( $pooltaskid, 'yes' );
            $logger->trace("$ll  delete task log file");
            $logger->trace("$ll  task log: $tasklog");
            $retc = tasklog_remove($tasklog);
            exit;                                                                                                               # if fork than exit here

         } else {
            $logger->error("cannot start pool [$xenpool] auth change to [$authmode] ");
            $retc=97;
         }
         
      } else {
         $errmsg = "unsupported pool auth mode [$authmode]";
         $logger->error("$ll $errmsg");
         set_flash("!E:$errmsg");
         $retc=99;
      }
   }

   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $retc;
} 




sub get_master {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $pool = shift();
   my $master;
   $logger->debug("$ll call findmaster");
   my $command = "$global{'toolsdir'}/findmaster -q -9 " . length($ll) . " -l " . $global{'logfile'} . ".log -p $pool -s";
   $logger->trace("$ll  cmd: [$command]");
   my $poolmaster = qx($command  2>&1);
   $retc = $?;
   $retc = $retc >> 8 unless ( $retc == -1 );
   $poolmaster =~ s/^\s+//;
   $poolmaster =~ s/\s+$//;
   $poolmaster =~ s/\n//;
   $logger->trace("$ll  rc=$retc / master: [$poolmaster]");

   unless ($retc) {
      if ( "$poolmaster" ne "" ) {
         $logger->info("$ll  found master [$poolmaster]");
         $master = $poolmaster;
      } else {
         $logger->warn("$ll  no master found or standalone server");
         $master = "";
      }
   } else {
      $logger->error("failed find master");
      $master = "";
   }
   $logger->trace("$ll func end: [$fc] rc=$retc");
   $flvl--;
   return $master;
} ## end sub get_master


sub vmxen {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $cmd  = shift();
   $logger->trace("$ll  cmd: $cmd");
   my ( $job, $srv, $uuid, $host, $vm, $user ) = split( ',', $cmd );

   unless ($retc) {
      if ( not defined $job ) {
         $logger->error("no job command given");
         $retc = 31;
      } else {
         $logger->trace("$ll  job: $job");
      }
   } ## end unless ($retc)
   unless ($retc) {
      if ( not defined $srv ) {
         $logger->error("no xen master given");
         $retc = 31;
      } elsif ( "$srv" eq "" ) {
         $logger->error("no xen master given");
         $retc = 31;
      } else {
         $logger->trace("$ll  xen master: $srv");
      }
   } ## end unless ($retc)
   unless ($retc) {
      if ( not defined $uuid ) {
         $logger->error("no vm uuid given");
         $retc = 31;
      } elsif ( "$uuid" eq "" ) {
         $logger->error("no vm uuid given");
         $retc = 31;
      } else {
         $logger->trace("$ll  uuid: $uuid");
      }
   } ## end unless ($retc)
   unless ($retc) {
      if ( not defined $host ) {
         $logger->trace("$ll  host server of vm not given - take master $srv");
         $host = $srv;
      } elsif ( "$host" eq "" ) {
         $logger->trace("$ll  host server of vm not given - take master $srv");
         $host = $srv;
      } else {
         $logger->trace("$ll  vm host: $host");
      }
   } ## end unless ($retc)
   unless ($retc) {
      if ( not defined $vm ) {
         $logger->trace("$ll  no vm name given");                                                                                  # ToDo: try to find vm name with uuid
      } elsif ( "$vm" eq "" ) {
         $logger->trace("$ll  no vm name given");                                                                                  # ToDo: try to find vm name with uuid
      } else {
         $logger->trace("$ll  vm: $vm");
      }
   } ## end unless ($retc)
   unless ($retc) {
      if ( not defined $user ) {
         $logger->trace("$ll  no user given - take cdb");
         $user = "cdb";
      } elsif ( "$user" eq "" ) {
         $logger->trace("$ll  no user given - take cdb");
         $user = "cdb";
      } else {
         $logger->trace("$ll  user: $user");
      }
   } ## end unless ($retc)
   my $cmdscript = "$global{'progdir'}../tools/rmc -q ";
   my $cmdpar;
   if ( "$job" eq "shutdown" ) {
      $cmdpar = " -s $srv -j \"xe vm-shutdown uuid=$uuid \" ";
   } elsif ( "$job" eq "stop" ) {
      $cmdpar = " -s $srv -j \"xe vm-shutdown uuid=$uuid --force\" ";
   } elsif ( "$job" eq "reboot" ) {
      $cmdpar = " -s $srv -j \"xe vm-reboot uuid=$uuid \" ";
   } elsif ( "$job" eq "reset" ) {
      $cmdpar = " -s $srv -j \"xe vm-reboot uuid=$uuid --force\" ";
   } elsif ( "$job" eq "start" ) {
      $cmdpar = " -s $srv -j \"xe vm-start uuid=$uuid \" ";
   } else {
      $logger->error("unknown job [$job] - abort");
      $retc = 99;
   }
   if ( task_ok($srv) ) {
      $addcmd = "$job vm $vm,Do $job with vm $vm on host $host," . $user . ',myShowTask,TASKID,' . $srv . ',vm,no';
      $logger->trace("$ll  cmd: $addcmd");
      my $taskid = task_add( $addcmd, 'force' );
      if ($taskid) {
         my $tasklog = $global{'logdir'} . "/task-" . $taskid;
         $logger->trace("$ll  task log: $tasklog");
         my $command = "$cmdscript -l $tasklog $cmdpar";
         $logger->trace("$ll  start cmd: [$command]");
         my $out = qx($command  2>&1);
         $retc = $?;
         $retc = $retc >> 8 unless ( $retc == -1 );
         $logger->trace("$ll  end cmd: [$command][$retc]");

         unless ($retc) {
            $logger->trace("$ll  ok");
         } else {
            $logger->error("failed [$out]");
         }
         $logger->debug("$ll  delete task [$taskid]");
         $retc = task_del( $taskid, 'no' );
         $logger->trace("$ll  delete task log file [$tasklog]");
         $retc = tasklog_remove($tasklog);
      } else {
         $logger->error("Cannot get new task id for [$job vm $vm on $host with master $srv]");
         $retc = 99;
      }
   } else {
      $logger->error("Cannot add new task id for [$job vm $vm on $host with master $srv]");
      $retc = 99;
   }
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
} ## end sub vmxen



1;

