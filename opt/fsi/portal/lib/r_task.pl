# task functions
sub task_status {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $statdb = db_connect();

   if ($statdb) {
      $logger->trace("$ll  connect: $statdb");
      my $sql = "SELECT id, short, long, jobuser, logdatei, control, ctyp, block FROM $global{'dbt_stat'} ORDER BY id DESC";
      my $sth = $statdb->prepare($sql);
      $logger->trace("$ll prep: $sth");

      # or die $db->errstr;
      $sth->execute;
      $logger->trace("$ll  exec: $sth");

      # or die $sth->errstr;
      my $statushash_p = $sth->fetchall_hashref('id');
      foreach my $id ( keys %{$statushash_p} ) {
         $statushash_p->{$id}{'vitemp'} = $host;
      }
      print Dumper( \$statushash_p );
      $rc = db_disconnect($statdb);
   } ## end if ($statdb)
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub task_status

sub task_list {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $statdb = db_connect();
   if ($statdb) {
      $logger->trace("$ll  connect: $statdb");
      my $sql = "SELECT id, short, long, jobuser, url, logdatei, control, ctyp, block FROM $global{'dbt_stat'} ORDER BY id DESC";
      my $sth = $statdb->prepare($sql);
      $logger->trace("$ll prep: $sth");

      # or die $db->errstr;
      $sth->execute;
      $logger->trace("$ll  exec: $sth");

      # or die $sth->errstr;
      my $statushash_p = $sth->fetchall_hashref('id');
      my $urlstr       = "#";
      printf " %-5s %-30s %-40s %-15s %-25s %-6s %-6s %s \n", "ID", "Short", "Long", "User", "Control", "C.Typ", "Block", "url";
      print "---------------------------------------------------------------------------------------------------------------------------------------------------------\n";
      foreach my $id ( keys %{$statushash_p} ) {
         printf " %-5s %-30s %-40s %-15s %-25s %-6s %-6s %s \n", $id, $statushash_p->{$id}{'short'}, $statushash_p->{$id}{'long'}, $statushash_p->{$id}{'jobuser'}, $statushash_p->{$id}{'control'}, $statushash_p->{$id}{'ctyp'}, $statushash_p->{$id}{'block'}, $statushash_p->{$id}{'url'} . $urlstr . $statushash_p->{$id}{'logdatei'};
      }
      my $taskid = task_getid($statdb);
      print "Next task id: $taskid\n";
      $rc = db_disconnect($statdb);
   } ## end if ($statdb)
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub task_list

sub get_ctyp {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc      = 0;
   my $typ     = "undef";
   my $whattyp = shift();
   my $dbh     = db_connect();
   if ($dbh) {
      $logger->trace("$ll  connect: $dbh");
      if ( "$typ" eq "undef" ) {
         my $sql = "SELECT id FROM entries WHERE db_srv = \'$whattyp\'";
         $logger->trace("$ll  sql: $sql");
         my $sth = $dbh->prepare($sql) or die $dbh->errstr;
         $sth->execute or die $sth->errstr;
         my $lastid = $sth->rows;
         $logger->trace("$ll  rows: $lastid");
         if ( $lastid == 1 ) {
            $logger->debug("$ll  found $whattyp as server");
            $typ = "srv";
         } elsif ( $lastid == 0 ) {
            $logger->debug("$ll  found nothing - no server");
         } else {
            $logger->error("no or more than 1 found, not possible for server - abort");
            $rc = 99;
         }
      } ## end if ( "$typ" eq "undef" )
      if ( "$typ" eq "undef" ) {
         my $sql = "SELECT id, db_controltyp FROM entries WHERE db_control = \'$whattyp\'";
         $logger->trace("$ll  sql: $sql");
         my $sth = $dbh->prepare($sql) or die $dbh->errstr;
         $sth->execute or die $sth->errstr;
         my $lastid = $sth->rows;
         $logger->trace("$ll  rows: $lastid");
         if ( $lastid >= 1 ) {
            $logger->debug("$ll  found $whattyp as control");
            my $serverhash = $sth->fetchall_hashref('id');
            foreach my $id ( keys %{$serverhash} ) {
               $typ = $serverhash->{$id}{'db_controltyp'};
               $logger->trace("$ll  id: $id - typ: $typ");
            }
         } else {
            $logger->debug("$ll  no pool or vc found");
         }
      } ## end if ( "$typ" eq "undef" )
      unless ($rc) {
         $rc = db_disconnect($dbh);
      }
   } ## end if ($dbh)
   if ($rc) {
      $logger->error("error in func - set return to false");
      $typ = "undef";
   }
   $logger->trace("$ll func end: [$fc] rc=$rc");
   $flvl--;
   $logger->level($llback);
   return $typ;
} 


sub task_ok {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc   = 0;
   my $ok   = 1;                                                                                                                   # yes we can :)
   my $what = shift();
   $logger->trace("$ll  task control for: $what");
   my $typ = get_ctyp($what);
   $logger->trace("$ll  control typ: [$typ]");

   if ( "$typ" ne "undef" ) {
      $logger->debug("$ll  found $what in db - test if new task ok");
      my $dbh = db_connect();
      if ($dbh) {
         $logger->trace("$ll  connect: $dbh");
         if ( ( "$typ" eq "xp" ) || ( "$typ" eq "vc" ) ) {
            my $sql = "SELECT id, db_controltyp FROM entries WHERE ( db_control = \'$what\' AND s_block = \'B\' ) ";
            $logger->trace("$ll  sql: $sql");
            my $sth = $dbh->prepare($sql) or die $dbh->errstr;
            $sth->execute or die $sth->errstr;
            my $lastid = $sth->rows;
            $logger->trace("$ll  rows: $lastid");
            if ( $lastid >= 1 ) {
               $logger->debug("$ll  found $what [$typ] with blockade flag");
               $ok = 0;
            } else {
               $logger->debug("$ll  no pool or vc found with blockade flag");
            }
            $sth->finish();
         } ## end if ( ( "$typ" eq "xp" ) || ( "$typ" eq "vc" ) )
         ### teste bei server ob blockade b - if blockade B maybe override !"!!!!   überprüfen ob: force
         if ( "$typ" eq "srv" ) {
            my $sql = "SELECT id, db_controltyp FROM entries WHERE ( db_srv = \'$what\' AND ( s_block = \'b\' OR s_block = \'B\') ) ";
            $logger->trace("$ll  sql: $sql");
            my $sth = $dbh->prepare($sql) or die $dbh->errstr;
            $sth->execute or die $sth->errstr;
            my $lastid = $sth->rows;
            $logger->trace("$ll  rows: $lastid");
            if ( $lastid >= 1 ) {
               $logger->debug("$ll  found $what [$typ] with blockade flag");
               $ok = 0;
            } else {
               $logger->debug("$ll  no pool or vc found with blockade flag");
            }
            $sth->finish();
         } ## end if ( "$typ" eq "srv" )
         unless ($rc) {
            $rc = db_disconnect($dbh);
         }
      } else {
         $logger->error("cannot connect to db - abort");
         $rc = 99;
      }
   } else {
      $logger->debug("$ll  cannot find $what in db - task is ok, because is new");
   }
   if ($rc) {
      $logger->error("error in func - set return to false");
      $ok = 0;
   }
   $logger->trace("$ll func end: [$fc] rc=$rc");
   $flvl--;
   $logger->level($llback);
   return $ok;
} ## end sub task_ok

sub task_findid {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc      = 0;
   my $control = shift();                                                                                                          # which task delete
   my $block   = shift();
   my $id      = 0;
   if ( defined $block ) {

      if ( $block eq "no" ) {
         $logger->debug("$ll  search task which do not block");
         $block = 0;
      } elsif ( $block eq "yes" ) {
         $logger->debug("$ll  search task which block");
         $block = 1;
      } else {
         $logger->debug("$ll  unknown block status - use yes");
         $block = 0;
      }
   } else {
      $logger->debug("$ll  undef block status - use yes");
      $block = 0;
   }
   if ( defined $control ) {
      my $dbh = db_connect();
      if ($dbh) {
         $logger->trace("$ll  connect: $dbh - now search for task $control");
         my $quoted_name = $dbh->quote_identifier( $global{'dbt_stat'} );
         my $sql         = "SELECT id, block FROM $global{'dbt_stat'} WHERE control = '$control' ORDER BY id DESC";
         my $sth         = $dbh->prepare($sql);
         $logger->trace("$ll  sql: $sql");
         $sth->execute;
         my $lastid = $sth->rows;
         $logger->trace("$ll  rows: $lastid");

         if ( $lastid == 1 ) {
            my $taskhash_p = $sth->fetchall_hashref('id');
            $id = (%$taskhash_p)[ 0 ];                                                                                             # first hash element
            $logger->debug("$ll  found $id in tasklist");
            my $fblock = $taskhash_p->{$id}{'block'};
            $logger->debug("$ll  control:  $control");
            $logger->trace("$ll  block: $block");
            if ( ( "$fblock" eq "yes" ) && ($block) ) {
               $logger->trace("$ll  task $id has right block status");
            } elsif ( ( "$fblock" eq "no" ) && ( !$block ) ) {
               $logger->trace("$ll  task $id has right no block status");
            } else {
               $logger->trace("$ll  different block status - ignore");
               $id = 0;
            }
         } elsif ( $lastid == 0 ) {
            $logger->debug("$ll  found nothing - no task");
            $id = 0;
         } else {
            $logger->error("more than 1 found, not possible for task search - abort");
            $id = 0;
         }
      } ## end if ($dbh)
      unless ($rc) {
         $rc = db_disconnect($dbh);
      }
   } else {
      $logger->error("no control search given");
      $rc = 44;
   }
   if ($rc) {
      $logger->warn("$ll  something wrong - reset id");
      $id = 0;
   }
   $logger->trace("$ll func end: [$fc] rc=$rc");
   $flvl--;
   $logger->level($llback);
   return $id;
} ## end sub task_findid

sub task_getid {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $taskid = 0;
   my $statdb = shift();
   if ($statdb) {
      $logger->trace("$ll  connect: $statdb");
      my $sql = "SELECT id FROM $global{'dbt_stat'} ORDER BY id DESC";
      my $sth = $statdb->prepare($sql);
      $logger->trace("$ll  prep: $sth");

      # or die $db->errstr;
      $sth->execute;
      $logger->trace("$ll  exec: $sth");

      # or die $sth->errstr;
      my $statushash_p = $sth->fetchall_hashref('id');
      my $maxid        = 0;
      foreach my $id ( keys %{$statushash_p} ) {
         if ( $maxid < $id ) {
            $maxid = $id;
         }
      }
      $logger->trace("$ll  max id: $maxid");
      $taskid = $maxid + 1;
      $logger->trace("$ll  task id: $taskid");
   } ## end if ($statdb)
   $logger->trace("$ll func end: [$fc] rc=$rc");
   $flvl--;
   $logger->level($llback);
   return $taskid;
} ## end sub task_getid

sub task_add {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc       = 0;
   my $taskparm = shift();
   my $force    = shift();
   if ( defined $force ) {

      if ( $force eq "force" ) {
         $logger->debug("$ll  do not check if blocked");
         $force = 1;
      } else {
         $logger->debug("$ll  check if blocked");
         $force = 0;
      }
   } else {
      $logger->debug("$ll  not defined - check if blocked");
      $force = 0;
   }
   my @taskparam  = split( ',', $taskparm );
   my $long       = "";
   my $jobuser    = "";
   my $url        = "";
   my $logdatei   = "";
   my $control    = "";
   my $controltyp = "";
   my $block      = "no";
   my $newid      = 0;
   $logger->trace("$ll  parameter: $taskparm");

   #  parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
   if ( ( !defined $taskparam[ 1 ] ) || ( $taskparam[ 1 ] eq "" ) ) {
      $logger->trace("$ll  no long description definded");
      $long = "no detail descr.";
   } else {
      $long = $taskparam[ 1 ];
      $long =~ s/^\s+//;
      $long =~ s/\s+$//;
      $long =~ s/\n//;
      $logger->trace("$ll  long: [$long]");
   } ## end else [ if ( ( !defined $taskparam[ 1 ] ) || ( $taskparam[ 1 ] eq "" ) ) ]
   if ( ( !defined $taskparam[ 2 ] ) || ( $taskparam[ 2 ] eq "" ) ) {
      $logger->trace("$ll  no jobuser definded = take system");
      $jobuser = "System";
   } else {
      $jobuser = $taskparam[ 2 ];
      $jobuser =~ s/^\s+//;
      $jobuser =~ s/\s+$//;
      $jobuser =~ s/\n//;
      $logger->trace("$ll  jobuser: [$jobuser]");
   } ## end else [ if ( ( !defined $taskparam[ 2 ] ) || ( $taskparam[ 2 ] eq "" ) ) ]
   if ( ( !defined $taskparam[ 3 ] ) || ( $taskparam[ 3 ] eq "" ) ) {
      $logger->trace("$ll  no url definded = take overview");
      $url = "overview";
   } else {
      $url = $taskparam[ 3 ];
      $url =~ s/^\s+//;
      $url =~ s/\s+$//;
      $url =~ s/\n//;
      $logger->trace("$ll  url: [$url]");
   } ## end else [ if ( ( !defined $taskparam[ 3 ] ) || ( $taskparam[ 3 ] eq "" ) ) ]
   if ( ( !defined $taskparam[ 4 ] ) || ( $taskparam[ 4 ] eq "" ) ) {
      $logger->trace("$ll  no log file definded");
      $logdatei = "no";
   } else {
      $logdatei = $taskparam[ 4 ];
      $logdatei =~ s/^\s+//;
      $logdatei =~ s/\s+$//;
      $logdatei =~ s/\n//;
      $logger->trace("$ll  log: [$logdatei]");
   } ## end else [ if ( ( !defined $taskparam[ 4 ] ) || ( $taskparam[ 4 ] eq "" ) ) ]
   if ( ( !defined $taskparam[ 5 ] ) || ( $taskparam[ 5 ] eq "" ) ) {
      $logger->trace("$ll  no control parameter definded");
      $control = "undef";
   } else {
      $control = $taskparam[ 5 ];
      $control =~ s/^\s+//;
      $control =~ s/\s+$//;
      $control =~ s/\n//;
      $logger->trace("$ll  control: [$control]");
   } ## end else [ if ( ( !defined $taskparam[ 5 ] ) || ( $taskparam[ 5 ] eq "" ) ) ]
   $controltyp = "undef";
   if ( ( !defined $taskparam[ 6 ] ) || ( $taskparam[ 6 ] eq "" ) ) {
      $logger->trace("$ll  no control type definded");
      if ( $control eq "undef" ) {
         $logger->warn("$ll  no control nor controltyp defined");
      } else {
         if ( "$control" eq "undef" ) {
            $logger->warn("$ll  no control and control typ given - maybe new");
         } else {
            $controltyp = get_ctyp($control);
            if ( "$controltyp" eq "undef" ) {
               $logger->debug("$ll  control typ or control not found in db - maybe new");
            } else {
               $logger->trace("$ll  control type found for $control is [$controltyp]");
            }
         } ## end else [ if ( "$control" eq "undef" ) ]
      } ## end else [ if ( $control eq "undef" ) ]
   } else {
      if ( "$control" eq "undef" ) {
         $controltyp = $taskparam[ 6 ];
         $controltyp =~ s/^\s+//;
         $controltyp =~ s/\s+$//;
         $controltyp =~ s/\n//;
         $logger->trace("$ll  control typ: [$controltyp]");
      } else {
         my $l_controltyp = $taskparam[ 6 ];
         $l_controltyp =~ s/^\s+//;
         $l_controltyp =~ s/\s+$//;
         $l_controltyp =~ s/\n//;
         $controltyp = get_ctyp($control);
         if ( "$taskparam[6]" eq "$controltyp" ) {
            $logger->trace("$ll  control typ: [$controltyp]");
         } elsif ( "$controltyp" eq "undef" ) {
            $logger->debug("$ll  control typ or control not found in db - maybe new");
            $controltyp = $l_controltyp;
         } else {
            $logger->warn("$ll  different control typ [$l_controltyp]/[$controltyp] - take found, not given");
         }
      } ## end else [ if ( "$control" eq "undef" ) ]
   } ## end else [ if ( ( !defined $taskparam[ 6 ] ) || ( $taskparam[ 6 ] eq "" ) ) ]
   if ( ( !defined $taskparam[ 7 ] ) || ( $taskparam[ 7 ] eq "" ) ) {
      $logger->trace("$ll  no block parameter definded");
   } else {
      $block = $taskparam[ 7 ];
      $block =~ tr/A-ZÄÖÜ/a-zäöü/;
      $block =~ s/^\s+//;
      $block =~ s/\s+$//;
      $block =~ s/\n//;
      $logger->trace("$ll  block: [$block]");
   } ## end else [ if ( ( !defined $taskparam[ 7 ] ) || ( $taskparam[ 7 ] eq "" ) ) ]
   if ( task_ok($control) || $force ) {
      $logger->info("$ll  add task [$taskparam[0]] to tasklist");
      my $statdb = db_connect( $global{'newport'} );
      if ($statdb) {
         if ( "$block" eq "yes" ) {
            $logger->trace("$ll  start blockade of $control");
            if ( ( "$controltyp" eq "xp" ) || ( "$controltyp" eq "vc" ) ) {
               $logger->debug("$ll  blockade pool or vc");
               $rc = set_flag_pool( $statdb, "s_block",    $control, "B" );
               $rc = set_flag_pool( $statdb, "block_user", $control, $jobuser );
            } elsif ( "$controltyp" eq "srv" ) {
               $logger->debug("$ll  blockade only one server");
               $rc = set_flag( $statdb, "s_block",    $control, "b" );
               $rc = set_flag( $statdb, "block_user", $control, $jobuser );
            } else {
               $logger->warn("$ll  unknown control typ $controltyp");
            }
         } ## end if ( "$block" eq "yes" )
         $logger->trace("$ll  connect: $statdb");
         my $tryagain = 1;
         do {
            $logger->trace("$ll  get new task id");
            $newid = task_getid($statdb);
            if ($newid) {
               if ( $logdatei eq "TASKID" ) {
                  $logger->debug("$ll  generate log file with id + fsi logdefault");
                  $logdatei = "task-" . $newid . ".log";
                  $logger->debug("$ll  generated log: [$logdatei]");
               } else {
                  $logger->trace("$ll  normal log: [$logdatei]");
               }
               my $sql = "insert into $global{'dbt_stat'} (id, short, long, jobuser, url, logdatei, control, ctyp, block) values (?,?,?,?,?,?,?,?,?)";
               $logger->trace("$ll  sql: $sql");
               my $sth = $statdb->prepare($sql) or die $statdb->errstr;
               $logger->trace("$ll  add: $newid, $taskparam[0], $long, $jobuser, $url, $logdatei, $control, $controltyp, $block");
               $sth->execute( $newid, $taskparam[ 0 ], $long, $jobuser, $url, $logdatei, $control, $controltyp, $block );
               my $fehler = $sth->errstr;
               if ($fehler) {

                  if ( $fehler =~ m/Unique-Constraint »task_status«/ ) {
                     $logger->warn("$ll  ID doppelt ($newid)");
                  } elsif ( $fehler =~ m/Schlüsselwert verletzt Unique-Constraint/ ) {
                     $logger->warn("$ll  ID doppelt ($newid)");
                  } else {
                     $logger->error("DB Meldung: [$fehler]");
                     $rc = 99;
                  }
                  $logger->warn("$ll  retry adding task");                                                                         # ToDo: Abbruch wenn zu oft versucht wurde
                  sleep int( rand(4) ) + 1;
               } else {
                  $logger->info("$ll  task $taskparam[ 0 ] added");
                  $tryagain = 0;
               }
            } else {
               $logger->error("cannot get new task id");
               $rc = 66;
            }
            if ($rc) {
               $tryagain = 0;
            }
         } while ($tryagain);
      } ## end if ($statdb)
      unless ($rc) {
         $rc = db_disconnect($statdb);
      }
   } else {
      $logger->warn("$ll  cannot add task [$taskparam[0]] to tasklist - $control is blockade");
      $rc    = 99;
      $newid = 0;
   }
   $logger->trace("$ll func end: [$fc] rc=$rc");
   $flvl--;
   $logger->level($llback);
   return $newid;
} ## end sub task_add

sub task_del {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc      = 0;
   my $id      = shift();                                                                                                          # which task delete
   my $unblock = shift();
   if ( defined $unblock ) {
      if ( $unblock eq "no" ) {
         $logger->debug("$ll  do not unblock task");
         $unblock = 0;
      } else {
         $logger->debug("$ll  unblock if task blocked");
         $unblock = 1;
      }
   } else {
      $logger->debug("$ll  unblock if task blocked");
      $unblock = 1;
   }
   if ( defined $id && $id !~ m/\D/ ) {
      my $dbh = db_connect();
      if ($dbh) {
         $logger->trace("$ll  connect: $dbh - now search for task $id");
         my $quoted_name = $dbh->quote_identifier( $global{'dbt_stat'} );
         my $sql         = "SELECT id, control, ctyp, block FROM $global{'dbt_stat'} WHERE id = $id ORDER BY id DESC";
         my $sth         = $dbh->prepare($sql);
         $sth->execute;
         my $lastid = $sth->rows;
         $logger->trace("$ll  rows: $lastid");
         if ( $lastid == 1 ) {
            $logger->debug("$ll  found $id in tasklist");
            my $taskhash_p = $sth->fetchall_hashref('id');
            my $control    = $taskhash_p->{$id}{'control'};
            my $block      = $taskhash_p->{$id}{'block'};
            my $controltyp = $taskhash_p->{$id}{'ctyp'};
            $logger->debug("$ll  srv:  $control");
            $logger->trace("$ll  block: $block");
            if ( ( "$block" eq "yes" ) && ($unblock) ) {
               $logger->trace("$ll  end blockade of $control");
               if ( ( "$controltyp" eq "xp" ) || ( "$controltyp" eq "vc" ) ) {
                  $logger->debug("$ll  blockade pool or vc");
                  $rc = $retc = del_flag_dbcontrol( $dbh, "s_block",    $control );
                  $rc = $retc = del_flag_dbcontrol( $dbh, "block_user", $control );
               } elsif ( "$controltyp" eq "srv" ) {
                  $logger->debug("$ll  blockade only one server");
                  $rc = del_flag_srv( $dbh, "s_block",    $control );
                  $rc = del_flag_srv( $dbh, "block_user", $control );
               } else {
                  $logger->warn("$ll  unknown control typ $controltyp");
               }
            } else {
               $logger->trace("$ll  no blocking or not remove blocking");
            }
            unless ($rc) {
               $logger->debug("$ll  delete from task list");
               my $updatecmd = "DELETE FROM $quoted_name WHERE id = $id ";
               my $updsth = $dbh->prepare($updatecmd) or die $dbh->errstr;
               $logger->trace("$ll  $updatecmd");
               $updsth->execute();
               my $fehler = $updsth->errstr;
               if ($fehler) {
                  $logger->error("DB Meldung: $fehler");
                  $retc = 88;
               } else {
                  $logger->debug("$ll  ok");
                  $updsth->finish();
                  $rc = 0;
               }
            } ## end unless ($rc)
         } elsif ( $lastid == 0 ) {
            $logger->debug("$ll  found nothing - no task");
         } else {
            $logger->error("no or more than 1 found, not possible for server - abort");
            $rc = 99;
         }
      } ## end if ($dbh)
      unless ($rc) {
         $rc = db_disconnect($dbh);
      }
   } else {
      $logger->error("no task number given");
      $rc = 44;
   }
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub task_del

sub tasklog_add {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc   = ( caller(0) )[ 3 ];
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   $flvl++;
   my $logfile = shift();

   if ( defined $logfile ) {
      $logfile = $logfile . ".log";
      $logger->trace("$ll  remove old log file - if exist");
      if ( -e $logfile ) {
         unless ( unlink($logfile) ) {
            $logger->error( "deleting " . $logfile . "[$!]" );
            $retc = 99;
         } else {
            $logger->trace("$ll  $logfile deleted!");
         }
      } else {
         $logger->trace("$ll  $tasklog not found ???");
      }
      unless ($retc) {
         my $name = basename( $logfile, '.log' );
         $logger->trace("$ll  appender name: $name");
         my $pattern = "%d{yyyy.MM.dd-HH:mm:ss} : %-6P - %-19F{1} %-6p : %m %n";
         my $layout  = Log::Log4perl::Layout::PatternLayout->new($pattern);
         my $tasklog = Log::Log4perl::Appender->new(
                                                     "Log::Log4perl::Appender::File",
                                                     name     => $name,
                                                     filename => $logfile
                                                     );
         $tasklog->layout($layout);
         $tasklog->threshold('INFO');
         $logger->add_appender($tasklog);
         $logger->trace("$ll  new tasklog activate");
      } ## end unless ($retc)
   } ## end if ( defined $logfile )
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub tasklog_add

sub tasklog_remove {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc   = ( caller(0) )[ 3 ];
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   $flvl++;
   my $logfile = shift();
   $logger->trace("$ll  logfile:$logfile");

   if ( defined $logfile ) {
      $logfile = $logfile . ".log";
      my $name = basename( $logfile, '.log' );
      $logger->debug("$ll  remove log appender [$name] for tasklog");
      $logger->trace("$ll  check if appender exist");
      my $tempappender = Log::Log4perl->appender_by_name("$name");
      if ($tempappender) {
         $logger->debug("$ll appender exist - remove: $tempappender");
         $logger->remove_appender($name);
      } else {
         $logger->trace("$ll no appender");
      }
   } ## end if ( defined $logfile )
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub tasklog_remove

sub add2history {
   my $llback = $logger->level();

   # $logger->level( $global{'logprod'} );
   my $fc   = ( caller(0) )[ 3 ];
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   $flvl++;

   my ( $action, $descr ) = @_;

   if ( defined $logfile ) {
      $logfile = $logfile . ".log";
      my $name = basename( $logfile, '.log' );
      $logger->debug("$ll  remove log appender [$name] for tasklog");
      $logger->trace("$ll  check if appender exist");
      my $tempappender = Log::Log4perl->appender_by_name("$name");
      if ($tempappender) {
         $logger->debug("$ll appender exist - remove: $tempappender");
         $logger->remove_appender($name);
      } else {
         $logger->trace("$ll no appender");
      }
   } ## end if ( defined $logfile )



   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $retc;
} ## end sub add2history


# workstat db functions
sub worker_del {
   my $llback = $logger->level();
   #$logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc  = 0;
   my $tempdel = shift();
   my ($typ,$who) = split(",",$tempdel);
   if ( ! defined $who ) {
      $logger->error("no who given - abort");
      $rc=99;
   } elsif ( ! defined $typ ) {
      $logger->error("no typ given - abort");
      $rc=99;
   }
   
   unless ( $rc ) {
      if ( ( "$typ" ne "" ) && ( "$who" ne "" ) ) {
         $logger->debug("$ll   start deleting worker status entry for [$typ] / [$who] ");
         my $dbh = db_connect();
         if ($dbh) {
            $logger->trace("$ll  connect: $dbh - now search for worker entry");
            my $quoted_name = $dbh->quote_identifier( $global{'dbt_worker'} );
            my $sql         = "SELECT typ, who, status, info FROM " . $quoted_name . " WHERE ( typ = \'" . $typ . "\' AND who = \'" . $who . "\' )";
            my $sth         = $dbh->prepare($sql);
            $sth->execute;
            my $fehler = $sth->errstr;
            if ($fehler) {
               $logger->error("DB Meldung: $fehler");
               $retc = 88;
            } else {               
               my $foundentries = $sth->rows;
               $sth->finish();

               $logger->trace("$ll  found entries: $foundentries");
               if ( $foundentries == 0 ) {
                  $logger->warn("$ll  found nothing - no worker entry exist");
               } else {
                  $logger->debug("$ll  found in tasklist");
                  $logger->info("$ll  delete from worker entry");
                  my $updatecmd = "DELETE FROM " . $quoted_name . " WHERE ( typ = \'" . $typ . "\' AND who = \'" . $who . "\' )";
                  my $updsth = $dbh->prepare($updatecmd) or die $dbh->errstr;
                  $logger->trace("$ll  $updatecmd");
                  $updsth->execute();
                  my $fehler = $updsth->errstr;
                  if ($fehler) {
                     $logger->error("DB Meldung: $fehler");
                     $retc = 88;
                  } else {
                     $logger->debug("$ll  ok");
                     $rc = 0;
                  }
                  $logger->trace("$ll  finish updsth handle");
                  $updsth->finish();
               } ## end unless ($rc)
               unless ( $rc ) {
                  $logger->trace("$ll  disconnet db handle");
                  $rc = db_disconnect($dbh);
               }
            }
         } else {
            $logger->error("cannot connect to db");
            $retc=98;
         }
      } else {
         $logger->error("at least one parameter is wrong or empty = typ:[$typ] who:[$who]");
         $rc=99;
      }
   }

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
} ## end sub task_del

sub worker_list {
   my $llback = $logger->level();
   $logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   my $statdb = db_connect();
   if ($statdb) {
      $logger->trace("$ll  connect: $statdb");
      my $sql = "SELECT typ, who, status, info FROM $global{'dbt_worker'} ORDER BY who DESC";
      my $sth = $statdb->prepare($sql);
      $logger->trace("$ll prep: $sth");

      # or die $db->errstr;
      $sth->execute;
      $logger->trace("$ll  exec: $sth");

      # or die $sth->errstr;
      my $statushash_p = $sth->fetchall_hashref('who');
      my $urlstr       = "#";
      printf " %-5s %-30s %-40s %s \n", "Typ", "Who", "Status", "Info";
      print "---------------------------------------------------------------------------------------------------------------------------------------------------------\n";
      foreach my $id ( keys %{$statushash_p} ) {
         printf " %-5s %-30s %-40s %s \n", $statushash_p->{$id}{'typ'}, $id, $statushash_p->{$id}{'status'}, $statushash_p->{$id}{'info'};
      }
      $rc = db_disconnect($statdb);
   } ## end if ($statdb)
   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   $logger->level($llback);
   return $rc;
}

sub worker_add {
   my $llback = $logger->level();
   #$logger->level( $global{'logprod'} );
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc       = 0;
   my $tempparm = shift();
   
   if ( defined $tempparm ) {
      $logger->trace("$ll  add $tempparm");
      my ($typ,$who,$status,$info)  = split( ',', $tempparm );
      
      if ( ! defined $who ) {
         $logger->error("no who given - abort");
         $rc=99;
      } elsif ( ! defined $typ ) {
         $logger->error("no typ given - abort");
         $rc=99;
      } elsif ( ! defined $status ) {
         $logger->error("no status given - abort");
         $rc=99;
      } elsif ( ! defined $info ) {
         $logger->error("no info given - abort");
         $rc=99;
      }
      
      unless ( $rc ) {
         my $dbh = db_connect();
         if ($dbh) {
            my $quoted_name = $dbh->quote_identifier( $global{'dbt_worker'} );
            my $sql = "insert into $quoted_name (typ, who, status, info) values (?,?,?,?)";
            $logger->trace("$ll  sql: $sql");
            my $sth = $dbh->prepare($sql) or die $dbh->errstr;
            $logger->trace("$ll  add: $typ, $who, $status, $info");
            $sth->execute( $typ, $who, $status, $info );
            my $fehler = $sth->errstr;
            if ($fehler) {
               if ( $fehler =~ m/Schlüsselwert verletzt Unique-Constraint/ ) {
                  $logger->warn("$ll  entry already exist in worker db");
               } elsif ( $fehler =~ m/duplicate key value violates unique/ ) {
                  $logger->warn("$ll  entry already exist in worker db");
               } else {
                  $logger->error("DB Meldung: [$fehler]");
                  $rc = 99;
               }
            } else {
               $logger->info("$ll $typ, $who, $status, $info added");
            }
            unless ($rc) {
               $rc = db_disconnect($dbh);
               if ( $rc ) {
                  $logger->error("cannot disconnect db handle");
               }
            }
         }  else {
            $logger->error("cannot connect to db");
            $retc=98;
         }
      }
      
   } else {
      $logger->error("no parameter given to add to worker db");
      $rc=99;
   }
   
   $logger->trace("$ll func end: [$fc] rc=$rc");
   $flvl--;
   $logger->level($llback);
   return $rc;
}



1;
