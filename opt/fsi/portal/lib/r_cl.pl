my $counter = 0;
$loglevel = $DEBUG;
## Command line parsing ------------------------------------------------------------------------------------------------
for ( $counter = 0 ; $counter < $numargv ; $counter++ ) {

   # print("Argument: $ARGS[$counter]");
   if ( $ARGS[ $counter ] =~ /^-h$/i ) {
      help();
   } elsif ( $ARGS[ $counter ] eq "" ) {                                                                                           # Ignore null arguments
      ## Do nothing
   } elsif ( $ARGS[ $counter ] =~ m/^-q$/ ) {
      $quietmode = "yes";
   } elsif ( $ARGS[ $counter ] =~ /^\/h$/i ) {
      help();
   } elsif ( $ARGS[ $counter ] =~ /^--help$/ ) {
      help();
   } elsif ( $ARGS[ $counter ] =~ /^--deldb$/ ) {
      $job = "deldb";
   } elsif ( $ARGS[ $counter ] =~ /^--chkon$/ ) {
      $job = "chkon";
   } elsif ( $ARGS[ $counter ] =~ /^--chkcfg$/ ) {
      $job = "chkcfg";
   } elsif ( $ARGS[ $counter ] =~ /^--chkonsrv$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --chkonsrv was not valid server name\n\n");
         help();
      }
      $job = "chkonsrv";
   } elsif ( $ARGS[ $counter ] =~ /^--chkall$/ ) {
      $job = "chkall";
   } elsif ( $ARGS[ $counter ] =~ /^--taskstat$/ ) {
      $job = "taskstat";
   } elsif ( $ARGS[ $counter ] =~ /^--chkpoolrun$/ ) {
      $job = "chkpoolrun";
   } elsif ( $ARGS[ $counter ] =~ /^--sub$/ ) {
      $counter++;
      $flvl = 0;
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($flvl) { $flvl .= " "; }
            $flvl .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($flvl);
         $flvl =~ s/\n|\r//g;
         $ll = " " x $flvl;
      } else {
         print("ERROR: The argument after --sub was not valid\n\n");
         help();
      }
   } elsif ( $ARGS[ $counter ] =~ /^--vmxen$/ ) {
      $counter++;
      $vmcmd = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($vmcmd) { $vmcmd .= " "; }
            $vmcmd .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($vmcmd);
         $vmcmd =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --xenvm was not valid\n\n");
         help();
      }
      $job = "vmxen";
   } elsif ( $ARGS[ $counter ] =~ /^--workerlist$/ ) {
      $job = "workerlist";
   } elsif ( $ARGS[ $counter ] =~ /^--tasklist$/ ) {
      $job = "tasklist";
   } elsif ( $ARGS[ $counter ] =~ /^--taskadd$/ ) {
      $counter++;
      $taskopt = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($taskopt) { $taskopt .= " "; }
            $taskopt .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($taskopt);
         $taskopt =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --taskadd was not valid\n\n");
         help();
      }
      $job = "taskadd";
   } elsif ( $ARGS[ $counter ] =~ /^--workeradd$/ ) {
      $counter++;
      $taskopt = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($taskopt) { $taskopt .= " "; }
            $taskopt .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($taskopt);
         $taskopt =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --workeradd was not valid\n\n");
         help();
      }
      $job = "workeradd";
   } elsif ( $ARGS[ $counter ] =~ /^--taskfind$/ ) {
      $counter++;
      $taskopt = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($taskopt) { $taskopt .= " "; }
            $taskopt .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($taskopt);
         $taskopt =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --taskfind was not valid\n\n");
         help();
      }
      $job = "taskfind";
   } elsif ( $ARGS[ $counter ] =~ /^--workerdel$/ ) {
      $counter++;
      $taskopt = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($taskopt) { $taskopt .= " "; }
            $taskopt .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($taskopt);
         $taskopt =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --workerdel was not valid\n\n");
         help();
      }
      $job = "workerdel";
   } elsif ( $ARGS[ $counter ] =~ /^--taskdel$/ ) {
      $counter++;
      $taskopt = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($taskopt) { $taskopt .= " "; }
            $taskopt .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($taskopt);
         $taskopt =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --taskdel was not valid\n\n");
         help();
      }
      $job = "taskdel";
   } elsif ( $ARGS[ $counter ] =~ /^--taskok$/ ) {
      $counter++;
      $taskopt = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($taskopt) { $taskopt .= " "; }
            $taskopt .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($taskopt);
         $taskopt =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --taskok was not valid\n\n");
         help();
      }
      $job = "taskok";
   } elsif ( $ARGS[ $counter ] =~ /^--chklog$/ ) {
      $job = "chklog";
   } elsif ( $ARGS[ $counter ] =~ /^--block$/ ) {
      $taskblock = "yes";
   } elsif ( $ARGS[ $counter ] =~ /^--delsrv$/ ) {
      $counter++;
      $delsrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($delsrv) { $delsrv .= " "; }
            $delsrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($delsrv);
         $delsrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --delid was not valid id number\n\n");
         help();
      }
      $job = "delsrv";
   } elsif ( $ARGS[ $counter ] =~ /^--dpcd$/ ) {
      $counter++;
      $pool = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($pool) { $pool .= " "; }
            $pool .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($pool);
         $pool =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --dpcd was not valid pool name\n\n");
         help();
      }
      $job = "dpcd";
   } elsif ( $ARGS[ $counter ] =~ /^--dprd$/ ) {
      $counter++;
      $pool = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($pool) { $pool .= " "; }
            $pool .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($pool);
         $pool =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --dprd was not valid pool name\n\n");
         help();
      }
      $job = "dprd";
   } elsif ( $ARGS[ $counter ] =~ /^--haon$/ ) {
      $counter++;
      $pool = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($pool) { $pool .= " "; }
            $pool .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($pool);
         $pool =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --haon was not valid pool name\n\n");
         help();
      }
      $job = "haon";
   } elsif ( $ARGS[ $counter ] =~ /^--haoff$/ ) {
      $counter++;
      $pool = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($pool) { $pool .= " "; }
            $pool .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($pool);
         $pool =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --haoff was not valid pool name\n\n");
         help();
      }
      $job = "haoff";
   } elsif ( $ARGS[ $counter ] =~ /^--chkha$/ ) {
      $counter++;
      $pool = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($pool) { $pool .= " "; }
            $pool .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($pool);
         $pool =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --chkha was not valid pool name\n\n");
         help();
      }
      $job = "chkha";
   } elsif ( $ARGS[ $counter ] =~ /^--delid$/ ) {
      $counter++;
      $delsrvid = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($delsrvid) { $delsrvid .= " "; }
            $delsrvid .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($delsrvid);
         $delsrvid =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --delid was not valid id number\n\n");
         help();
      }
      $job = "delid";
   } elsif ( $ARGS[ $counter ] =~ /^--set$/ ) {
      $counter++;
      $flagcontent = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($flagcontent) { $flagcontent .= " "; }
            $flagcontent .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($flagcontent);
         $flagcontent =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --set was not valid input for a flag\n\n");
         help();
      }
   } elsif ( $ARGS[ $counter ] =~ /^--server$/ ) {
      $counter++;
      $server = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($server) { $server .= " "; }
            $server .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($server);
         $server =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --srv was not valid server name\n\n");
         help();
      }
   } elsif ( $ARGS[ $counter ] =~ /^--pool$/ ) {
      $counter++;
      $pool = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($pool) { $pool .= " "; }
            $pool .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($pool);
         $pool =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --pool was not valid pool name\n\n");
         help();
      }
   } elsif ( $ARGS[ $counter ] =~ /^--setflag$/ ) {
      $counter++;
      $flag = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($flag) { $flag .= " "; }
            $flag .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($flag);
         $flag =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --setflag was not valid flag\n\n");
         help();
      }
      $job = "setflag";
   } elsif ( $ARGS[ $counter ] =~ /^--delflag$/ ) {
      $counter++;
      $flag = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($flag) { $flag .= " "; }
            $flag .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($flag);
         $flag =~ s/\n|\r//g;
      } else {
         $flag = "";
         $counter--;
      }
      $job = "delflag";
   } elsif ( $ARGS[ $counter ] =~ /^--chkiae$/ ) {
      $job = "chkiae";
   } elsif ( $ARGS[ $counter ] =~ /^--chkiend$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --chkiend was not valid server name\n\n");
         help();
      }
      $job = "chkiend";
   } elsif ( $ARGS[ $counter ] =~ /^--autoreboot$/ ) {
      $autoreboot = "yes";
   } elsif ( $ARGS[ $counter ] =~ /^--upd$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --upd was not valid server name\n\n");
         help();
      }
      $job = "upd";


   } elsif ( $ARGS[ $counter ] =~ /^--delsym$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --delsym was not valid server name\n\n");
         help();
      }
      $job = "delsym";
   } elsif ( $ARGS[ $counter ] =~ /^--setsym$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --setsym was not valid server name\n\n");
         help();
      }
      $job = "setsym";
   } elsif ( $ARGS[ $counter ] =~ /^--install$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --install was not valid server name\n\n");
         help();
      }
      $job = "install";
   } elsif ( $ARGS[ $counter ] =~ /^--abort$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --on was not valid server name\n\n");
         help();
      }
      $job = "abort";
   } elsif ( $ARGS[ $counter ] =~ /^--srvon$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --srvon was not valid server name\n\n");
         help();
      }
      $job = "srvon";
   } elsif ( $ARGS[ $counter ] =~ /^--srvoff$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --on was not valid server name\n\n");
         help();
      }
      $job = "srvoff";
   } elsif ( $ARGS[ $counter ] =~ /^--bootnic$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --on was not valid server name\n\n");
         help();
      }
      $job = "bootnic";
   } elsif ( $ARGS[ $counter ] =~ /^--chkpatch$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --on was not valid server name\n\n");
         help();
      }
      $job = "chkpatch";
   } elsif ( $ARGS[ $counter ] =~ /^--chkpatchp$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --on was not valid server name\n\n");
         help();
      }
      $job = "chkpatchp";
   } elsif ( $ARGS[ $counter ] =~ /^--boothd$/ ) {
      $counter++;
      $chksrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($chksrv) { $chksrv .= " "; }
            $chksrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($chksrv);
         $chksrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --on was not valid server name\n\n");
         help();
      }
      $job = "boothd";
   } elsif ( $ARGS[ $counter ] =~ /^--dbport$/ ) {
      $counter++;
      my $dbport = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($dbport) { $dbport .= " "; }
            $dbport .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($dbport);
         $dbport =~ s/\n|\r//g;
         if ( $dbport + 0 eq $dbport ) {
            $global{'newport'} = $dbport;
         } else {
            print("ERROR: The argument after --dbport was no integer for postgresql port");
            help();
         }
      } else {
         print("ERROR: The argument after --dbport was not valid server name\n\n");
         help();
      }
   } elsif ( $ARGS[ $counter ] =~ /^--new$/ ) {
      $job = "new";
   } elsif ( $ARGS[ $counter ] =~ /^--update$/ ) {
      $job = "update";
   } elsif ( $ARGS[ $counter ] =~ /^--showall$/ ) {
      $job     = "show";
      $showsrv = "all";
   } elsif ( $ARGS[ $counter ] =~ /^--showsrv$/ ) {
      $counter++;
      $showsrv = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($showsrv) { $showsrv .= " "; }
            $showsrv .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($showsrv);
         $showsrv =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --showsrv was not valid id number\n\n");
         help();
      }
      $job = "show";
   } elsif ( $ARGS[ $counter ] =~ /^--sym$/ ) {
      $job = "sym";
   } elsif ( $ARGS[ $counter ] =~ /^--daemon$/ ) {

      # screen log ausschalten
      $global{'daemon'} = 1;
   } elsif ( $ARGS[ $counter ] =~ /^--xpc$/ ) {
      $job = "xpc";
   } elsif ( $ARGS[ $counter ] =~ /^--chkmaster$/ ) {
      $counter++;
      $pool = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($pool) { $pool .= " "; }
            $pool .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($pool);
         $pool =~ s/\n|\r//g;
      } else {
         $pool = "";
         $counter--;
      }
      $job = "chkmaster";
   } elsif ( $ARGS[ $counter ] =~ /^--pooloff$/ ) {
      $counter++;
      $pool = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($pool) { $pool .= " "; }
            $pool .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($pool);
         $pool =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --pooloff was not valid pool name\n\n");
         help();
      }
      $job = "pooloff";
   } elsif ( $ARGS[ $counter ] =~ /^--getmac$/ ) {
      $counter++;
      $server = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($server) { $server .= " "; }
            $server .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($server);
         $server =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --getmac was not valid server name\n\n");
         help();
      }
      $job = "getmac";
   } elsif ( $ARGS[ $counter ] =~ /^--gettyp$/ ) {
      $counter++;
      $server = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($server) { $server .= " "; }
            $server .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($server);
         $server =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --gettyp was not valid server name\n\n");
         help();
      }
      $job = "gettyp";
   } elsif ( $ARGS[ $counter ] =~ /^--getctrl$/ ) {
      $counter++;
      $server = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($server) { $server .= " "; }
            $server .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($server);
         $server =~ s/\n|\r//g;
      } else {
         print("ERROR: The argument after --getctrl was not valid server name\n\n");
         help();
      }
      $job = "getcontrol";
   } elsif ( $ARGS[ $counter ] =~ /^--sortid$/ ) {
      $job = "sortid";
   } elsif ( $ARGS[ $counter ] =~ m/^-1$/ ) {
      $loglevel = $DEBUG;
   } elsif ( $ARGS[ $counter ] =~ m/^--debug$/ ) {
      $loglevel = $DEBUG;
   } elsif ( $ARGS[ $counter ] =~ m/^--off$/ ) {
      $loglevel = $OFF;
   } elsif ( $ARGS[ $counter ] =~ m/^-0$/ ) {
      $loglevel = $INFO;
   } elsif ( $ARGS[ $counter ] =~ m/^--info$/ ) {
      $loglevel = $INFO;
   } elsif ( $ARGS[ $counter ] =~ m/^--trace$/ ) {
      $loglevel = $TRACE;
   } elsif ( $ARGS[ $counter ] =~ m/^-2$/ ) {
      $loglevel = $TRACE;
   } elsif ( $ARGS[ $counter ] =~ /^-l$/ ) {
      $counter++;
      $global{'logfile'} = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ( $global{'logfile'} ) { $global{'logfile'} .= " "; }
            $global{'logfile'} .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp( $global{'logfile'} );
         $global{'logfile'} =~ s/\n|\r//g;

         # print("Logfile: [$global{'logfile'}]\n");
      } else {
         print("ERROR: The argument after -l was no log file name\n\n");
         exit(100);
      }
   } else {
      print("\nUnknown option [$ARGS[$counter]]- ignore\n");
   }
} ## end for ( $counter = 0 ; $counter < $numargv ; $counter++ )
1;
