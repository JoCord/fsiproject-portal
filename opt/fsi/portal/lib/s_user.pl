any [ 'get', 'post' ] => '/user' => sub {
   my $weburl = '/user';
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
      my $sess_reload = $weburl;
      $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
      session 'reload' => $sess_reload;
      my $fsimsg;
      my $userconf = new Config::General("$global{'userxml'}");
      my %users    = $userconf->getall;
      if ( $logger->is_trace() ) {
         my $dumpout = Dumper( \%users );
         $logger->trace("$ll User-Dump:$dumpout");
      }


      if ( request->method() eq "POST" ) {
         $logger->debug("$ll  POST Section  [" . session('user') . "]");
         my %params = params;
         if ( $logger->is_trace() ) {
            my $dumpout = Dumper( \%params );
            $logger->trace("$ll Params-Dump: $dumpout");
         }
         my $sess_reload = session('reload');
         my $sess_back   = backurl_getlast("$sess_reload");
         if ( ( params->{'Save'} ) || ( params->{'lu_UserDel'} ) || ( params->{'du_UserDel'} ) || ( params->{'dg_GroupDel'} ) || ( params->{'UserAdd'} ) || ( params->{'GroupAdd'} ) || ( params->{'DomUserAdd'} ) ) {
            $retc = 0;
            my $user;
            my $group;
            my %lu_newusers;
            my %du_newusers;
            my %dg_newgroups;
            my $lu_deluser    = "none";
            my $du_deluser    = "none";
            my $dg_delgroup   = "none";
            my $lu_emptyexist = 0;
            my $du_emptyexist = 0;
            my $dg_emptyexist = 0;

            ### check if something to delete
            if ( params->{'lu_UserDel'} ) {
               $lu_deluser = params->{'lu_UserDel'};
               $logger->trace("$ll   ==> user del action started for $lu_deluser  [" . session('user') . "]");
            } elsif ( params->{'dg_GroupDel'} ) {
               $dg_delgroup = params->{'dg_GroupDel'};
               $logger->trace("$ll   ==> domain group del action started for $dg_delgroup  [" . session('user') . "]");
            } elsif ( params->{'du_UserDel'} ) {
               $du_deluser = params->{'du_UserDel'};
               $logger->trace("$ll   ==> domain user del action started for $du_deluser  [" . session('user') . "]");
            }

            ### check all return values
            foreach my $wert ( keys %params ) {                                                                                    # %{params} willned
               $logger->trace("$ll  wert: $wert  [" . session('user') . "]");
               if ( ref $params{$wert} eq 'ARRAY' ) {                                                                              # first check if role array
                  if ( "$wert" =~ m/^lu_role_/ ) {                                                                                 # local user role
                     $user = $wert;
                     $user =~ s/^lu_role_//g;
                     $logger->trace("$ll   found local user role setting => $user  [" . session('user') . "]");
                     if ( "$lu_deluser" ne "$user" ) {
                        if ( "$user" eq "-empty-" ) {
                           $lu_emptyexist = 1;
                        }
                        foreach my $role ( @{ $params{$wert} } ) {
                           $logger->trace("$ll    user $user role: $role  [" . session('user') . "]");
                           $lu_newusers{$user}{'role'}{$role} = {};
                        }
                     } else {
                        $logger->debug("$ll   ignore user due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^du_role_/ ) {                                                                            # domain user role
                     $user = $wert;
                     $user =~ s/^du_role_//g;
                     $logger->trace("$ll   found domain user role setting => $user  [" . session('user') . "]");
                     if ( "$du_deluser" ne "$user" ) {
                        if ( "$user" eq "-empty-" ) {
                           $du_emptyexist = 1;
                        }
                        foreach my $role ( @{ $params{$wert} } ) {
                           $logger->trace("$ll    domain user $user role: $role  [" . session('user') . "]");
                           $du_newusers{$user}{'role'}{$role} = {};
                        }
                     } else {
                        $logger->debug("$ll   ignore domain user due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^dg_role_/ ) {                                                                            # domain group role
                     $group = $wert;
                     $group =~ s/^dg_role_//g;
                     $logger->trace("$ll   found domain group role setting => $group  [" . session('user') . "]");
                     if ( "$dg_delgroup" ne "$group" ) {
                        if ( "$group" eq "-empty-" ) {
                           $dg_emptyexist = 1;
                        }
                        foreach my $role ( @{ $params{$wert} } ) {
                           $logger->trace("$ll    domain group $group role: $role  [" . session('user') . "]");
                           $dg_newgroups{$group}{'role'}{$role} = {};
                        }
                     } else {
                        $logger->debug("$ll   ignore domain group due to remove action  [" . session('user') . "]");
                     }
                  } else {
                     $logger->error("unknown hash setting in $wert  [" . session('user') . "]");
                     $retc = 76;
                  }
               } else {                                                                                                            # check all other parameter
                  if ( "$wert" =~ m/^lu_role_/ ) {
                     $user = $wert;
                     $user =~ s/^lu_role_//g;
                     $logger->trace("$ll   user => $user  [" . session('user') . "]");
                     if ( "$lu_deluser" ne "$user" ) {
                        if ( "$user" eq "-empty-" ) {
                           $lu_emptyexist = 1;
                        }
                        $logger->trace("$ll    role $user: $params{$wert}  [" . session('user') . "]");
                        $lu_newusers{$user}{'role'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore user due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^du_role_/ ) {
                     $user = $wert;
                     $user =~ s/^du_role_//g;
                     $logger->trace("$ll   domain user => $user  [" . session('user') . "]");
                     if ( "$du_deluser" ne "$user" ) {
                        if ( "$user" eq "-empty-" ) {
                           $du_emptyexist = 1;
                        }
                        $logger->trace("$ll    role $user: $params{$wert}  [" . session('user') . "]");
                        $du_newusers{$user}{'role'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore domain user due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^dg_role_/ ) {
                     $group = $wert;
                     $group =~ s/^dg_role_//g;
                     $logger->trace("$ll   domain group => $group  [" . session('user') . "]");
                     if ( "$dg_delgroup" ne "$group" ) {
                        if ( "$group" eq "-empty-" ) {
                           $dg_emptyexist = 1;
                        }
                        $logger->trace("$ll    role $group: $params{$wert}  [" . session('user') . "]");
                        $dg_newgroups{$group}{'role'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore domain group due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^lu_pw_/ ) {                                                                              # password only for local user
                     $user = $wert;
                     $user =~ s/^lu_pw_//g;
                     $logger->trace("$ll   user => $user  [" . session('user') . "]");
                     if ( "$lu_deluser" ne "$user" ) {
                        my $textpw = $params{$wert};
                        if ( "$user" eq "-empty-" ) {
                           $lu_emptyexist = 1;
                        }
                        if ( $textpw eq "" ) {
                           $cryptpw = $users{'user'}{$user}{'pw'};
                           $logger->trace("$ll    use old pw for user $user pw: $cryptpw  [" . session('user') . "]");
                        } else {
                           $logger->trace("$ll    use new pw for user $user and crypt it.  [" . session('user') . "]");
                           my $csh = Crypt::SaltedHash->new( algorithm => 'SHA-1' );
                           $csh->add($textpw);
                           $cryptpw = $csh->generate;
                           $logger->trace("$ll  pw hash: [$cryptpw]  [" . session('user') . "]");
                        } ## end else [ if ( $textpw eq "" ) ]
                        $lu_newusers{$user}{'pw'} = $cryptpw;
                     } else {
                        $logger->debug("$ll   ignore user due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^du_domain_/ ) {                                                                          # domain user domain name
                     $user = $wert;
                     $user =~ s/^du_domain_//g;
                     $logger->trace("$ll   domain user => $user  [" . session('user') . "]");
                     if ( "$du_deluser" ne "$user" ) {
                        if ( "$user" eq "-empty-" ) {
                           $du_emptyexist = 1;
                        }
                        $du_newusers{$user}{'domain'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore domain user due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^dg_domain_/ ) {                                                                          # domain group domain name
                     $group = $wert;
                     $group =~ s/^dg_domain_//g;
                     $logger->trace("$ll   domain group => $group  [" . session('user') . "]");
                     if ( "$dg_delgroup" ne "$group" ) {
                        if ( "$group" eq "-empty-" ) {
                           $dg_emptyexist = 1;
                        }
                        $dg_newgroups{$group}{'domain'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore domain user due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^du_ignore_/ ) {                                                                          # domain user ignore groups
                     $user = $wert;
                     $user =~ s/^du_ignore_//g;
                     $logger->trace("$ll   domain user => $user  [" . session('user') . "]");
                     if ( "$du_deluser" ne "$user" ) {
                        if ( "$user" eq "-empty-" ) {
                           $du_emptyexist = 1;
                        }
                        $du_newusers{$user}{'ignore'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore domain group due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^lu_login_/ ) {                                                                           # login user or group name
                     $user = $wert;
                     $user =~ s/^lu_login_//g;
                     $logger->trace("$ll   user => $user  [" . session('user') . "]");
                     if ( "$lu_deluser" ne "$user" ) {
                        if ( "$user" eq "-empty-" ) {
                           $lu_emptyexist = 1;
                        }
                        $lu_newusers{$user}{'name'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore user due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^du_login_/ ) {
                     $user = $wert;
                     $user =~ s/^du_login_//g;
                     $logger->trace("$ll   domain user => $user  [" . session('user') . "]");
                     if ( "$du_deluser" ne "$user" ) {
                        if ( "$user" eq "-empty-" ) {
                           $du_emptyexist = 1;
                        }
                        $du_newusers{$user}{'name'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore domain user due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^dg_group_/ ) {
                     $group = $wert;
                     $group =~ s/^dg_group_//g;
                     $logger->trace("$ll   domain group => $group  [" . session('user') . "]");
                     if ( "$dg_delgroup" ne "$group" ) {
                        if ( "$group" eq "-empty-" ) {
                           $dg_emptyexist = 1;
                        }
                        $dg_newgroups{$group}{'name'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore domain group due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^lu_active_/ ) {                                                                          # active config
                     $user = $wert;
                     $user =~ s/^lu_active_//g;
                     $logger->trace("$ll   user => $user  [" . session('user') . "]");
                     if ( "$lu_deluser" ne "$user" ) {
                        if ( "$user" eq "-empty-" ) {
                           $lu_emptyexist = 1;
                        }
                        $lu_newusers{$user}{'active'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore user due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^du_active_/ ) {
                     $user = $wert;
                     $user =~ s/^du_active_//g;
                     $logger->trace("$ll   domain user => $user  [" . session('user') . "]");
                     if ( "$du_deluser" ne "$user" ) {
                        if ( "$user" eq "-empty-" ) {
                           $du_emptyexist = 1;
                        }
                        $du_newusers{$user}{'active'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore domain user due to remove action  [" . session('user') . "]");
                     }
                  } elsif ( "$wert" =~ m/^dg_active_/ ) {
                     $group = $wert;
                     $group =~ s/^dg_active_//g;
                     $logger->trace("$ll   domain group => $group  [" . session('user') . "]");
                     if ( "$dg_delgroup" ne "$group" ) {
                        if ( "$group" eq "-empty-" ) {
                           $dg_emptyexist = 1;
                        }
                        $dg_newgroups{$group}{'active'} = $params{$wert};
                     } else {
                        $logger->debug("$ll    ignore domain group due to remove action  [" . session('user') . "]");
                     }


                     ## actions
                  } elsif ( "$wert" eq "lu_UserDel" ) {
                     $logger->trace("$ll  ==> command - local user del  [" . session('user') . "]");
                     $fsimsg .= " action: del local user [$params{$wert};]";
                  } elsif ( "$wert" eq "du_UserDel" ) {
                     $logger->trace("$ll  ==> command - domain user del  [" . session('user') . "]");
                     $fsimsg .= " action: del domain user [$params{$wert};]";
                  } elsif ( "$wert" eq "dg_GroupDel" ) {
                     $logger->trace("$ll  ==> command - domain group del  [" . session('user') . "]");
                     $fsimsg .= " action: del domain group [$params{$wert};]";
                  } elsif ( "$wert" eq "Save" ) {
                     $logger->trace("$ll  ==> command - user change  [" . session('user') . "]");
                     $fsimsg .= " action: save config";
                  } elsif ( "$wert" eq "UserAdd" ) {
                     $logger->trace("$ll  ==> command - local user add  [" . session('user') . "]");
                     $fsimsg .= " action: add new local user";
                  } elsif ( "$wert" eq "GroupAdd" ) {
                     $logger->trace("$ll  ==> command - domain group add  [" . session('user') . "]");
                     $fsimsg .= " action: add new domain group";
                  } elsif ( "$wert" eq "DomUserAdd" ) {
                     $logger->trace("$ll  ==> command - domain user add  [" . session('user') . "]");
                     $fsimsg .= " action: add new domain user";

                  } else {
                     $logger->error("unknown parameter [$wert] - something wrong.  [" . session('user') . "]");
                     $retc = 97;
                  }
               } ## end else [ if ( ref $params{$wert} eq 'ARRAY' ) ]
            } ## end foreach my $wert ( keys %params )


            ### add new user line
            unless ($retc) {
               if ( params->{'UserAdd'} ) {
                  if ($lu_emptyexist) {
                     $fsimsg = "Empty user already exist - please edit this one before add new user!";
                     $logger->debug("$ll   $fsimsg  [" . session('user') . "]");
                     $retc = 51;
                  } else {
                     $logger->trace("$ll   ==> user add action started  [" . session('user') . "]");
                     $lu_newusers{'-empty-'}{'name'}   = "-empty-";
                     $lu_newusers{'-empty-'}{'pw'}     = "you must change this";
                     $lu_newusers{'-empty-'}{'role'}   = {};
                     $lu_newusers{'-empty-'}{'active'} = "no";
                  } ## end else [ if ($lu_emptyexist) ]
               } elsif ( params->{'DomUserAdd'} ) {
                  if ($du_emptyexist) {
                     $fsimsg = "Empty domain user already exist - please edit this one before add new user!";
                     $logger->debug("$ll   $fsimsg  [" . session('user') . "]");
                     $retc = 52;
                  } else {
                     $logger->trace("$ll   ==> domain user add action started  [" . session('user') . "]");
                     $du_newusers{'-empty-'}{'name'}   = "-empty-";
                     $du_newusers{'-empty-'}{'domain'} = {};
                     $du_newusers{'-empty-'}{'role'}   = {};
                     $du_newusers{'-empty-'}{'active'} = "no";
                     $du_newusers{'-empty-'}{'ignore'} = "no";
                  } ## end else [ if ($du_emptyexist) ]
               } elsif ( params->{'GroupAdd'} ) {
                  if ($du_emptyexist) {
                     $fsimsg = "Empty domain group already exist - please edit this one before add new user!";
                     $logger->debug("$ll   $fsimsg  [" . session('user') . "]");
                     $retc = 53;
                  } else {
                     $logger->trace("$ll   ==> domain group add action started  [" . session('user') . "]");
                     $dg_newgroups{'-empty-'}{'name'}   = "-empty-";
                     $dg_newgroups{'-empty-'}{'role'}   = {};
                     $dg_newgroups{'-empty-'}{'domain'} = {};
                     $dg_newgroups{'-empty-'}{'active'} = "no";
                  } ## end else [ if ($du_emptyexist) ]
               } ## end elsif ( params->{'GroupAdd'} )
            } ## end unless ($retc)


            if ( $logger->is_trace() ) {
               my $dumpout = Dumper( \%lu_newusers );
               $logger->trace("$ll New local user Dump: $dumpout  [" . session('user') . "]");
            }
            if ( $logger->is_trace() ) {
               my $dumpout = Dumper( \%du_newusers );
               $logger->trace("$ll New domain user Dump: $dumpout  [" . session('user') . "]");
            }
            if ( $logger->is_trace() ) {
               my $dumpout = Dumper( \%dg_newgroups );
               $logger->trace("$ll New domain group Dump: $dumpout  [" . session('user') . "]");
            }



            ### backup user config
            unless ($retc) {
               if ( -e $global{'userxml'} ) {
                  $logger->debug("$ll  copy $global{'userxml'}  [" . session('user') . "]");
                  unless ( copy( "$global{'userxml'}", "$global{'userxml'}" . "_bak" ) ) {
                     $fsimsg = "copy $global{'userxml'} [$!]";
                     $logger->error("$ll   $fsimsg  [" . session('user') . "]");
                     $retc = 99;
                  } else {
                     $logger->debug("$ll  delete $global{'userxml'}  [" . session('user') . "]");
                     unless ( unlink( $global{'userxml'} ) ) {
                        $fsimsg = "deleting $global{'userxml'} [$!]";
                        $logger->error("$ll   $fsimsg  [" . session('user') . "]");
                        $retc = 98;
                     } else {
                        $logger->debug("$ll  old $global{'userxml'} deleted!  [" . session('user') . "]");
                     }
                  } ## end else
               } else {
                  $logger->debug("$ll  no $global{'userxml'} found  [" . session('user') . "]");
               }
            } ## end unless ($retc)


            ### write new access config file
            unless ($retc) {
               $logger->trace("$ll  write new access config file  [" . session('user') . "]");
               my $fh;
               open $fh, '>', $global{'userxml'} or $retc = 88;
               if ($retc) {
                  $fsimsg = "Cannot open $file";
                  $logger->error("$ll   $fsimsg  [" . session('user') . "]");
               } else {
                  my $changedate = TimeStamp(14);
                  print $fh "# fsi portal user configuration\n#\n# date changed: $changedate by admin user config site\n#";

                  ### local user
                  print $fh "\n\n# local user config";
                  foreach my $login ( keys %{lu_newusers} ) {
                     my $loginname;
                     $logger->trace("$ll   ==> work for local user login: $login  [" . session('user') . "]");
                     if ( "$login" eq $lu_newusers{$login}{'name'} ) {
                        $logger->debug("$ll  add old user name login $login  [" . session('user') . "]");
                        $loginname = $login;
                     } else {
                        $logger->debug("$ll  add new user name login $lu_newusers{$login}{'name'}  [" . session('user') . "]");
                        $loginname = $lu_newusers{$login}{'name'};
                     }
                     print $fh "\n<user $loginname>";
                     print $fh "\n  active $lu_newusers{$login}{'active'}";
                     print $fh "\n  pw $lu_newusers{$login}{'pw'}";
                     if ( ref $lu_newusers{$login}{'role'} eq 'HASH' ) {                                                           # a hash - not array
                        foreach my $role ( %{ $lu_newusers{$login}{'role'} } ) {
                           unless ( ref $role eq 'HASH' ) {                                                                        # ToDo: wieso ist jeder zweite Eintrag ein HASH ?
                              $logger->trace("$ll   add new role $role  [" . session('user') . "]");
                              print $fh "\n  <role $role>";
                              print $fh "\n  </role>";
                           }
                        } ## end foreach my $role ( %{ $lu_newusers{$login}{'role'} } )
                     } else {
                        if ( defined $lu_newusers{$login}{'role'} ) {
                           $logger->trace("$ll   add new role $lu_newusers{$login}{'role'}  [" . session('user') . "]");
                           print $fh "\n  <role $lu_newusers{$login}{'role'}>";
                           print $fh "\n  </role>";
                        } else {
                           $logger->trace("$ll  no role defined = view only user  [" . session('user') . "]");
                        }
                     } ## end else [ if ( ref $lu_newusers{$login}{'role'} eq 'HASH' ) ]
                     print $fh "\n</user>";
                  } ## end foreach my $login ( keys %{lu_newusers} )


                  ### domain user
                  print $fh "\n\n# domain user config";
                  foreach my $login ( keys %{du_newusers} ) {
                     my $loginname;
                     $logger->trace("$ll   ==> work for domain user login: $login  [" . session('user') . "]");
                     if ( "$login" eq $lu_newusers{$login}{'name'} ) {
                        $logger->debug("$ll  add old user name login $login  [" . session('user') . "]");
                        $loginname = $login;
                     } else {
                        $logger->debug("$ll  add new user name login $du_newusers{$login}{'name'}  [" . session('user') . "]");
                        $loginname = $du_newusers{$login}{'name'};
                     }
                     print $fh "\n<domuser $loginname>";
                     print $fh "\n  active $du_newusers{$login}{'active'}";
                     print $fh "\n  domain $du_newusers{$login}{'domain'}";
                     print $fh "\n  ignore $du_newusers{$login}{'ignore'}";

                     if ( ref $du_newusers{$login}{'role'} eq 'HASH' ) {                                                           # a hash - not array
                        foreach my $role ( %{ $du_newusers{$login}{'role'} } ) {
                           unless ( ref $role eq 'HASH' ) {                                                                        # ToDo: wieso ist jeder zweite Eintrag ein HASH ?
                                                                                                                                   # print "\n $role";
                              $logger->trace("$ll   add new role $role  [" . session('user') . "]");
                              print $fh "\n  <role $role>";
                              print $fh "\n  </role>";
                           } ## end unless ( ref $role eq 'HASH' )
                        } ## end foreach my $role ( %{ $du_newusers{$login}{'role'} } )
                     } else {
                        if ( defined $du_newusers{$login}{'role'} ) {
                           $logger->trace("$ll   add new role $du_newusers{$login}{'role'}  [" . session('user') . "]");
                           print $fh "\n  <role $du_newusers{$login}{'role'}>";
                           print $fh "\n  </role>";
                        } else {
                           $logger->trace("$ll  no role defined = view only domain user  [" . session('user') . "]");
                        }
                     } ## end else [ if ( ref $du_newusers{$login}{'role'} eq 'HASH' ) ]
                     print $fh "\n</domuser>";
                  } ## end foreach my $login ( keys %{du_newusers} )


                  ### domain groups
                  print $fh "\n\n# domain group config";
                  foreach my $group ( keys %{dg_newgroups} ) {
                     my $logingroup;
                     $logger->trace("$ll   ==> work for domain group: $group  [" . session('user') . "]");
                     if ( "$group" eq $lu_newgroups{$group}{'name'} ) {
                        $logger->debug("$ll  add old group name login $group  [" . session('user') . "]");
                        $logingroup = $group;
                     } else {
                        $logger->debug("$ll  add new group name login $dg_newgroups{$group}{'name'}  [" . session('user') . "]");
                        $logingroup = $dg_newgroups{$group}{'name'};
                     }
                     print $fh "\n<domgroup $logingroup>";
                     print $fh "\n  active $dg_newgroups{$group}{'active'}";
                     print $fh "\n  domain $dg_newgroups{$group}{'domain'}";

                     if ( ref $dg_newgroups{$group}{'role'} eq 'HASH' ) {                                                          # a hash - not array
                        foreach my $role ( %{ $dg_newgroups{$group}{'role'} } ) {
                           unless ( ref $role eq 'HASH' ) {                                                                        # ToDo: wieso ist jeder zweite Eintrag ein HASH ?
                                                                                                                                   # print "\n $role";
                              $logger->trace("$ll   add new role $role  [" . session('user') . "]");
                              print $fh "\n  <role $role>";
                              print $fh "\n  </role>";
                           } ## end unless ( ref $role eq 'HASH' )
                        } ## end foreach my $role ( %{ $dg_newgroups{$group}{'role'} } )
                     } else {
                        if ( defined $dg_newgroups{$group}{'role'} ) {
                           $logger->trace("$ll   add new role $dg_newgroups{$group}{'role'}  [" . session('user') . "]");
                           print $fh "\n  <role $dg_newgroups{$group}{'role'}>";
                           print $fh "\n  </role>";
                        } else {
                           $logger->trace("$ll  no role defined = view only domain group  [" . session('user') . "]");
                        }
                     } ## end else [ if ( ref $dg_newgroups{$group}{'role'} eq 'HASH' ) ]
                     print $fh "\n</domgroup>";
                  } ## end foreach my $group ( keys %{dg_newgroups} )
                  $logger->trace("$ll  close file  [" . session('user') . "]");
                  close($fh) or $retc = 88;
                  unless ($retc) {
                     $fsimsg = "!S:Access configuration changes accepted: $fsimsg";
                  } else {
                     $fsimsg = "!E:ERROR updating access configuration: $fsimsg";
                     $retc   = 77;
                     $logger->error("$ll   $fsimsg  [" . session('user') . "]");
                  }
               } ## end else [ if ($retc) ]
            } ## end unless ($retc)

            set_flash("$fsimsg");
            $retc = backurl_add("$sess_back");
            return redirect $sess_reload;


         } elsif ( params->{'Abort'} ) {
            $retc   = 0;
            $fsimsg = "Abort user administration - all changes since last takeover were lost";
            $logger->debug("$ll  $fsimsg  [" . session('user') . "]");
            set_flash("!W:$fsimsg");
            return redirect $sess_back;
         } elsif ( params->{'Reload'} ) {
            $logger->info("$ll  reload user menu  [" . session('user') . "]");
            return redirect $sess_reload;
         } elsif ( params->{'Logout'} ) {
            $logger->info("$ll  logout  [" . session('user') . "]");
            return redirect '/logout';
         } elsif ( params->{'Back'} ) {
            return redirect $sess_back;
         } else {
            $retc = 99;
            template 'error',
              {
                'msg'     => "unknown method in /admin",
                'version' => $ver,
                'vitemp'  => $host,
                'vienv'   => $global{'vienv'}, };
         } ## end else [ if ( ( params->{'Save'} ) || ( params->{'lu_UserDel'} ) || ( params->{'du_UserDel'} ) || ( params->{'dg_GroupDel'} ) || ( params->{'UserAdd'} ) || ( params->{'GroupAdd'} ) || ( params->{'DomUserAdd'} ) ) ]
      } ## end if ( request->method() eq "POST" )

      if ( request->method() eq "GET" ) {
         my $sess_reload = $weburl;
         $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
         $retc = backurl_add("$sess_reload");

         if ( $logger->is_trace() ) {
            my $dumpout = Dumper( \%users );
            $logger->trace("$ll Access user.xml Dump: $dumpout  [" . session('user') . "]");
         }


         template 'user.tt',
           {
             'msg'      => get_flash(),
             'version'  => $ver,
             'vitemp'   => $host,
             'users'    => \%users,
             'rzconfig' => \%rzconfig,
             'vienv'    => $global{'vienv'}, };
      } ## end if ( request->method() eq "GET" )
   } ## end else [ if ( !session('logged_in') ) ]
};


any [ 'get', 'post' ] => '/useredit' => sub {
   my $weburl = '/useredit';
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
      my $sess_reload = "/useredit";
      $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
      session 'reload' => $sess_reload;
      if ( request->method() eq "POST" ) {
         my %params      = params;
         my $sess_reload = session('reload');
         my $sess_back   = backurl_getlast("$sess_reload");
         if ( params->{'ChangePassword'} ) {
            my $newpasswort = params->{'Password'};
            if ( "$newpasswort" ne "" ) {
               $logger->trace("$ll  new password entered - change in config file  [" . session('user') . "]");
               my $csh = Crypt::SaltedHash->new( algorithm => 'SHA-1' );
               $csh->add($newpasswort);
               my $cryptpw   = $csh->generate;
               my $inputfile = "$global{'userxml'}" . "_temp";

               # ToDo: set change flag - test if flag exist from other user or admin
               $logger->trace("$ll  backup old user config file  [" . session('user') . "]");
               unless ( copy( "$global{'userxml'}", $inputfile ) ) {
                  $logger->error("copy $global{'userxml'} [$!]  [" . session('user') . "]");
                  set_flash("!E:ERROR - cannot copy user config file!");
               } else {
                  $logger->debug("$ll  delete old user config file $global{'userxml'}  [" . session('user') . "]");
                  unless ( unlink( $global{'userxml'} ) ) {
                     $logger->error("deleting $global{'userxml'} [$!]  [" . session('user') . "]");
                     set_flash("!E:ERROR - cannot delete user config file!");
                  } else {
                     $logger->debug("$ll  Change user password now ...  [" . session('user') . "]");
                     my $inf_fh;
                     my $out_fh;
                     $logger->trace("$ll  open old user config file for comparison  [" . session('user') . "]");
                     open $in_fh, '<', $inputfile or $retc = 99;
                     unless ($retc) {
                        $logger->trace("$ll  open new user config file  [" . session('user') . "]");
                        open $out_fh, '>', $global{'userxml'} or $retc = 88;
                        unless ($retc) {
                           my $foundmylogin = 0;                                                                                   # search user record
                           my $user         = session('user');
                           $logger->trace("$ll   Search user [$user] record to change password  [" . session('user') . "]");
                           while ( my $line = <$in_fh> ) {

                              # $logger->trace("$ll   line: $line");
                              if ( "$line" =~ m/\<user $user\>/ ) {
                                 $logger->trace("$ll  found record for user in user config file  [" . session('user') . "]");
                                 print $out_fh $line;
                                 $foundmylogin = 1;
                              } elsif ( "$line" =~ m/^\# date changed:/ ) {
                                 $logger->trace("$ll  found datum on last change  [" . session('user') . "]");
                                 my $changedate = TimeStamp(14) . " by $user\n";
                                 print $out_fh "\# date changed: $changedate";
                              } elsif ( "$line" =~ m/ pw / ) {
                                 if ($foundmylogin) {
                                    $logger->trace("$ll  found pw line for user record - changed hash  [" . session('user') . "]");
                                    print $out_fh "  pw $cryptpw \n";
                                    $foundmylogin = 0;                                                                             # reset user record
                                 } else {
                                    print $out_fh $line;
                                    $logger->trace("$ll  not pw line for user [$user] record - ignore  [" . session('user') . "]");
                                 }
                              } else {
                                 print $out_fh $line;
                              }
                           } ## end while ( my $line = <$in_fh> )
                           close($in_fh)  or $retc = 77;
                           close($out_fh) or $retc = 66;
                           unless ($retc) {
                              unless ( unlink($inputfile) ) {
                                 $logger->error("deleting $inputfile [$!]  [" . session('user') . "]");
                                 set_flash("!E:ERROR - cannot delete temp user file!");
                              } else {
                                 set_flash("!S:User password changed!");
                              }
                           } else {
                              $logger->error("closing files: $inputfile / $global{'userxml'} [$!]  [" . session('user') . "]");
                              set_flash("!E:ERROR - cannot close user files!");
                           }
                        } else {
                           $logger->error("open new user config file [$!]  [" . session('user') . "]");
                           set_flash("!E:ERROR - cannot open new user config file!");
                        }
                     } else {
                        $logger->error("open old user config file [$!]  [" . session('user') . "]");
                        set_flash("!E:ERROR - cannot open old user config file!");
                     }
                  } ## end else
               } ## end else
            } else {
               set_flash("!W:Password emtpy - not changed!");
            }
            redirect '/useredit';
         } else {
            redirect $sess_back;
         }
      } ## end if ( request->method() eq "POST" )
      if ( request->method() eq "GET" ) {
         $logger->debug("$ll  GET Section  [" . session('user') . "]");
         template 'useredit.tt',
           {
             'msg'      => get_flash(),
             'version'  => $ver,
             'vitemp'   => $host,
             'users'    => \%users,
             'rzconfig' => \%rzconfig,
             'vienv'    => $global{'vienv'}, };
      } ## end if ( request->method() eq "GET" )
   } ## end else [ if ( !session('logged_in') ) ]
};


any [ 'get', 'post' ] => '/usersessions' => sub {
   my $weburl = '/usersessions';
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
      if ( request->method() eq "POST" ) {
         $logger->debug("$ll  POST Section  [" . session('user') . "]");
         my %params      = params;
         my $sess_reload = session('reload');
         my $sess_back   = backurl_getlast("$sess_reload");
         if ( params->{'SessionDel'} ) {
            my $delfile = params->{'SessionDel'};
            $logger->info("$ll  del a session ($delfile)  [" . session('user') . "]");
            if ( -f $delfile ) {
               unless ( unlink($delfile) ) {
                  $logger->error("deleting $delfile rc=[$!]  [" . session('user') . "]");
                  set_flash("!E:ERROR - deleting session with file $delfile!");
               } else {
                  $logger->debug("deleted!  [" . session('user') . "]");
                  set_flash("!S:session deleted");
               }
            } ## end if ( -f $delfile )
            $retc = backurl_add("$sess_back");
            redirect $sess_reload;
         } elsif ( params->{'Reload'} ) {
            $logger->trace("$ll  reload user session list  [" . session('user') . "]");
            $retc = backurl_add("$sess_back");
            redirect $sess_reload;
         } elsif ( params->{'Back'} ) {
            $logger->debug("$ll  go back $sess_back  [" . session('user') . "]");
            redirect $sess_back;
         } else {
            $logger->info("$ll  reload user session list  [" . session('user') . "]");
            $retc = backurl_add("$sess_back");
            redirect $sess_reload;
         }
      } ## end if ( request->method() eq "POST" )
      if ( request->method() eq "GET" ) {
         my %users;
         my $fsimsg;
         my @files = grep { -f } glob("$global{'sessiondir'}/*.yml");
         my $sess_reload = "/usersessions";
         $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
         $retc = backurl_add("$sess_reload");

         foreach my $sessfile (@files) {
            $logger->trace("$ll  work with $sessfile  [" . session('user') . "]");
            my $yaml = LoadFile($sessfile);
            if ( $global{'logprod'} < 6000 ) {
               my $dump = Dumper($yaml);
               $logger->trace("  yaml dump: [$dump]  [" . session('user') . "]");
            }

            # Dancer1: my $id       = $yaml->{'id'};
            my $id = basename( $sessfile, '.yml' );
            my $username = $yaml->{'user'};
            $logger->trace("$ll  user: $username / $id   [" . session('user') . "]");
            $users{$id}              = {};
            $users{$id}{'name'}      = $yaml->{'user'};
            $users{$id}{'back'}      = $yaml->{'back'};
            $users{$id}{'id'}        = $yaml->{'id'};
            $users{$id}{'logintime'} = $yaml->{'logintime'};
            $users{$id}{'now'}       = $yaml->{'now'};
            $users{$id}{'role'}      = $yaml->{'role'};
            $users{$id}{'last'}      = $yaml->{'last'};
            $users{$id}{'file'}      = $sessfile;
         } ## end foreach my $sessfile (@files)
         template 'usersessions.tt',
           {
             'msg'      => get_flash(),
             'version'  => $ver,
             'vitemp'   => $host,
             'users'    => \%users,
             'rzconfig' => \%rzconfig,
             'vienv'    => $global{'vienv'}, };
      } ## end if ( request->method() eq "GET" )
   } ## end else [ if ( !session('logged_in') ) ]
};

#hook 'before' => sub {
#    if (! session('user') && request->path_info !~ m{^/login}) {
#        var requested_path => request->path_info;
#        request->path_info('/login');
#    }
#};
hook before_template => sub {
   my $tokens = shift;
   session 'last' => TimeStamp(14);

#   $tokens->{'css_url'}    = request->base . 'css/style.css';
   $tokens->{'login_url'}  = uri_for('/login');
   $tokens->{'logout_url'} = uri_for('/logout');
};


any [ 'get', 'post' ] => '/' => sub {
   if ( session('logged_in') ) {
      return redirect '/overview';
   } else {
      return redirect '/logout';
   }
};


any [ 'get', 'post' ] => '/login' => sub {
   my $weburl = '/login';
   $logger->trace("$ll func start: $weburl");
   local *__ANON__ = "dance: $weburl";                                                                                             # default if no function for caller sub
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $flvl--;
   my $retc = 0;

   my $errmsg;
   my %params = params;
   if ( $logger->is_trace() ) {
      my $dumpout = Dumper( \%params );
      $logger->trace("$ll Params-Dump: $dumpout");
   }
   if ( request->method() eq "POST" ) {
      if ( params->{'abort'} ) {
         return redirect '/';
      }

      # read user db
      my $userconf = new Config::General("$global{'userxml'}");
      our %users = $userconf->getall;
      $users{'user'}{'fsi'}{'pw'}             = '{SSHA}O9zX1UHKXXuaCU9nbMosQRQKuRzl+YMC';
      $users{'user'}{'fsi'}{'role'}{'Master'} = {};
      $users{'user'}{'fsi'}{'active'}         = "yes";
      if ( $logger->is_trace() ) {
         my $userdump = Dumper( \%users );
         $logger->trace("  user dump: [$userdump]");
      }

      my $inuser = params->{'username'};
      $logger->trace("  input user: $inuser  [" . session('user') . "]");
      my $inpw  = params->{'password'};

      if ( ( $inuser =~ m{\\} ) || ( $inuser =~ m{@} ) ) {                                                                         # if login with user@lab.local or lab\user -> domain user
         $logger->debug( "$ll login user [" . $inuser . "] is a domain user" );
         my $domainuser = "none";
         my $windomain  = "none";
         my $dnsdomain  = "none";
         my $ldap;


         if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'windom'} ) {
            if ( $inuser =~ m{\\} ) {
               $logger->trace("$ll  domain\\user login  [" . session('user') . "]");
               my $regex = qr/\\/;
               ( $windomain, $domainuser ) = split( $regex, $inuser );
               $logger->trace("$ll  user [$domainuser] / domain [$windomain]  [" . session('user') . "]");
               if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$windomain} ) {
                  $logger->trace("$ll find win domain in rzenv.xml [$windomain]  [" . session('user') . "]");
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$windomain}{'dns'} ) {
                     $dnsdomain = $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$windomain}{'dns'};
                  } else {
                     $logger->error("cannot find dns domain for windomain [$windomain]  [" . session('user') . "]");
                     $errmsg = "config error: cannot find dns domain";
                     $retc   = 34;
                  }
               } else {
                  $logger->warn("$ll cannot find win domain in rzenv.xml [$windomain]  [" . session('user') . "]");
                  $errmsg = "config error: cannot find domain [$windomain]";
                  $retc   = 22;
               }
            } else {
               $logger->trace("$ll user\@lab.local login  [" . session('user') . "]");
               my $regex = qr/@/;
               ( $domainuser, $dnsdomain ) = split( $regex, $inuser );
               foreach my $netbiosdom ( keys %{ $rzconfig{'rz'}{ $global{'vienv'} }{'windom'} } ) {
                  $logger->trace("$ll  $netbiosdom: $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$netbiosdom}{'dns'} eq $dnsdomain  [" . session('user') . "]");
                  if ( "$dnsdomain" eq "$rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$netbiosdom}{'dns'}" ) {
                     $logger->trace("$ll find win domain in rzenv.xml  [" . session('user') . "]");
                     $windomain = $netbiosdom;
                     last;
                  } else {
                     $logger->warn("$ll cannot find dns domain $dnsdomain in rzenv.xml  [" . session('user') . "]");
                     $errmsg = "config error: cannot find domain [$dnsdomain]";
                     $retc   = 21;
                  }
               } ## end foreach my $netbiosdom ( keys %{ $rzconfig{'rz'}{ $global{'vienv'} }{'windom'} } )
            } ## end else [ if ( $inuser =~ m{\\} ) ]

            unless ($retc) {
               $inpw =~ s/\%([A-Fa-f0-9]{2})/pack('C',hex($1))/seg;
               $inpw =~ s/\+/ /g;

               $logger->trace("$ll create new ldap object  [" . session('user') . "]");
               $ldap = Net::LDAP->new($dnsdomain) or $retc = 99;
               if ($retc) {
                  $logger->warn("$ll  cannot connect to dns domain: $@  [" . session('user') . "]");
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$netbiosdom}{'dc'} ) {
                     $ldap = Net::LDAP->new( $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$netbiosdom}{'dc'} ) or $retc = 98;
                     if ($retc) {
                        $logger->error("cannot connect to configure dc too - abort  [" . session('user') . "]");
                        $errmsg = "cannot connect to domain nor dc";
                     }
                  } else {
                     $logger->error("cannot find dc config for domain and cannot connect to domain - abort domain user login  [" . session('user') . "]");
                     $errmsg = "Can't connect to domain and dc not configure";
                     $retc = 38;
                  }
               } ## end if ($retc)
            }

            unless ($retc) {
               $logger->trace("$ll connection to dns domain [$dnsdomain] ok, try to bind  [" . session('user') . "]");
               #my $userlogin = $domainuser . "\@" . $dnsdomain;
               #$logger->trace("$ll login user: $userlogin  [" . session('user') . "]");
               #my $mesg      = $ldap->bind( $userlogin, password => $inpw );
               $logger->trace("$ll login user: $inuser  [" . session('user') . "]");
               my $mesg      = $ldap->bind( $inuser, 
                                            password => $inpw,
                                            version => 3 );
               my $results    = sprintf( "%s", $mesg->error_text );
               $results =~ s/\n//;
               my $resultname = sprintf( "%s", $mesg->error_name );
               my $resultid   = sprintf( "%s", $mesg->mesg_id );
               my $resultdn   = sprintf( "%s", $mesg->dn );
               my $rescode    = sprintf( "%s", $mesg->code );
               $logger->trace("$ll   bind result: [$resultname]  [" . session('user') . "]");
               $logger->trace("$ll                [$results]  [" . session('user') . "]");
               $logger->trace("$ll          code: [$rescode][$resultid]  [" . session('user') . "]");
               $logger->trace("$ll            dn: [$resultdn]  [" . session('user') . "]");
               $logger->trace("$ll   check result if success  [" . session('user') . "]");
               if ( $resultname =~ /LDAP_SUCCESS/ ) {
                  $logger->debug("$ll domain [" . $inuser . "] login successfully [$results] / code: [$rescode]  [" . session('user') . "]");
               } else {
                  $logger->error("login [" . $inuser . "] unsuccessfully [$results]/ code: [$rescode]  [" . session('user') . "]");
                  $errmsg = "domain user login denied [$rescode]";
                  $retc   = 88;
               }
            } ## end unless ($retc)

            my $fsirole      = "";
            my $founduser    = 0;
            my $ignoregroups = 0;
            my $foundgroup   = 0;

            unless ($retc) {                                                                                                       # domain login ok => search for active domain user => roles
               if ( defined "$users{'domuser'}{$domainuser}" ) {
                  if ( defined "$users{'domuser'}{$domainuser}{active}" ) {
                     if ( "$users{'domuser'}{$domainuser}{active}" eq "yes" ) {
                        $founduser = 1;
                        $logger->debug("$ll found domain user in rzenv.xml and is active  [" . session('user') . "]");
                        foreach my $roleconf ( keys %{ $users{'domuser'}{$domainuser}{'role'} } ) {
                           if ( $fsirole =~ m/$roleconf/ ) {
                              $logger->debug("$ll  role config [$roleconf] double - ignore  [" . session('user') . "]");
                           } else {
                              $logger->trace("$ll  add role [$roleconf]  [" . session('user') . "]");
                              $fsirole = $fsirole . "," . $roleconf;
                           }
                        } ## end foreach my $roleconf ( keys %{ $users{'domuser'}{$domainuser}{'role'} } )

                        if ( defined "$users{'domuser'}{$domainuser}{'ignore'}" ) {
                           if ( "$users{'domuser'}{$domainuser}{'ignore'}" eq "yes" ) {
                              $logger->trace("$ll  user [$domainuser] has exclude group config  [" . session('user') . "]");
                              $ignoregroups=1;
                           } else {
                              $logger->trace("$ll   exclude config unequel yes - try to add group rights  [" . session('user') . "]");
                           }
                        } else {
                           $logger->trace("$ll   no exclude config set for this domain user - try to add group rights  [" . session('user') . "]");
                        }
                     } else {
                        $logger->trace("$ll inactive user [$domainuser] - maybe in a group  [" . session('user') . "]");
                     }
                  } else {
                     $logger->trace("$ll no active flag - maybe in a group  [" . session('user') . "]");
                  }
               } else {
                  $logger->trace("$ll no domain user found in rzenv.xml - maybe in a group  [" . session('user') . "]");
               }
            } ## end unless ($retc)

            unless ($retc) {                                                                                                       # search for groups for this user and check for active domain groups => roles
               unless ($ignoregroups) {
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$windomain}{'search'} ) {
                     $logger->trace("$ll found one search config at least  [" . session('user') . "]");
                     foreach my $base ( keys %{ $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$windomain}{'search'} } ) {
                        $logger->trace("$ll  base search config: $base  [" . session('user') . "]");
                        $logger->trace("$ll  base search: $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$windomain}{'search'}{$base}{'base'}  [" . session('user') . "]");
                        my $searchfilter = "(&(sAMAccountName=" . escape_filter_value($domainuser) . "))";
                        $logger->trace("$ll  search filter: $searchfilter  [" . session('user') . "]");
                        my $result = $ldap->search( base => $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$windomain}{'search'}{$base}{'base'}, filter => $searchfilter );
                        if ( $result->code ) {
                           $errmsg = $result->error;
                           $logger->error("$errmsg  [" . session('user') . "]");
                           $retc = 33;
                        } else {
                           my $count = $result->count;
                           $logger->trace("$ll   count: $count  [" . session('user') . "]");
                           if ( $count == 1 ) {
                              $logger->trace("$ll  found user [$domainuser] in domain [$windomain]  [" . session('user') . "]");
                              my $dn_username = "none";
   
                              foreach my $entry ( $result->entries ) {
                                 $dn_username = $entry->get_value("distinguishedName");
                              }
   
                              if ( "$dn_username" eq "none" ) {
                                 $logger->error("$ll cannot find distinguishedName - cannot use user to search groups  [" . session('user') . "]");
                                 $errmsg = "no distinguishedName found";
                                 $retc   = 38;
                              } else {
                                 $logger->trace("$ll   found dn: $dn_username  [" . session('user') . "]");
                                 $logger->trace("$ll   start searching groups ...  [" . session('user') . "]");
                                 $dn_username = escape_filter_value($dn_username);
                                 $logger->trace("$ll   found dn: $dn_username  [" . session('user') . "]");
                                 my $nestedfilter = 'member:1.2.840.113556.1.4.1941:=' . $dn_username;
                                 $logger->trace("$ll   filter [$nestedfilter]  [" . session('user') . "]");
                                 $logger->trace("$ll   search cmd: base => $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$windomain}{'search'}{$base}{'base'}, filter => $nestedfilter  [" . session('user') . "]");
                                 $result = $ldap->search( base => $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$windomain}{'search'}{$base}{'base'}, filter => "$nestedfilter" );
                                 if ( $result->code ) {
                                    $errmsg = $result->error;
                                    $logger->error("$errmsg  [" . session('user') . "]");
                                    $retc = 34;
                                 } else {
                                    my $count = $result->count;
                                    $logger->debug("$ll   found $count groups  [" . session('user') . "]");
                                    foreach my $entry ( $result->entries ) {
                                       my $founddomaingroup = $entry->get_value("cn");
                                       if ( defined $founddomaingroup ) {
                                          if ( defined $users{'domgroup'}{$founddomaingroup} ) {
                                             $logger->debug("$ll   found $founddomaingroup in access user config  [" . session('user') . "]");
                                             if ( defined "$users{'domgroup'}{$founddomaingroup}{active}" ) {
                                                if ( "$users{'domgroup'}{$founddomaingroup}{active}" eq "yes" ) {
                                                   foreach my $roleconf ( keys %{ $users{'domgroup'}{$founddomaingroup}{'role'} } ) {
                                                      if ( $fsirole =~ m/$roleconf/ ) {
                                                         $logger->debug("$ll role config [$roleconf] double - ignore  [" . session('user') . "]");
                                                      } else {
                                                         $logger->trace("$ll add role [$roleconf]  [" . session('user') . "]");
                                                         $fsirole = $fsirole . "," . $roleconf;
                                                      }
                                                   } ## end foreach my $roleconf ( keys %{ $users{'domgroup'}{$founddomaingroup}{'role'} } )
                                                   $foundgroup = 1;
                                                } else {
                                                   $logger->debug("$ll found domain group is configure but inactive  [" . session('user') . "]");
                                                }
                                             } else {
                                                $logger->debug("$ll found domain group is configure but default inactive  [" . session('user') . "]");
                                             }
                                          } else {
                                             $logger->trace("$ll   found domain group [$founddomaingroup] is not in rzenv.xml  [" . session('user') . "]");
                                          }
                                       } else {
                                          $logger->error("no group name found  [" . session('user') . "]");
                                          $errmsg = "login user not configure and no groups found";
                                       }
                                    } ## end foreach my $entry ( $result->entries )
                                    unless ($foundgroup) {
                                       $logger->debug("$ll all found groups are not configured/inactive in fsi  [" . session('user') . "]");
                                    }
                                 } ## end else [ if ( $result->code ) ]
                              } ## end else [ if ( "$dn_username" eq "none" ) ]
                           } ## end if ( $count == 1 )
                        } ## end else [ if ( $result->code ) ]
                     } ## end foreach my $base ( keys %{ $rzconfig{'rz'}{ $global{'vienv'} }{'windom'}{$windomain}{'search'} } )
                  } else {
                     $logger->error("no search base found for $windomain  [" . session('user') . "]");
                     $retc = 78;
                  }
               } else {
                  $logger->trace("$ll   user ignore groups config found - do not search for groups  [" . session('user') . "]");
               }
            } ## end unless ($retc)

            unless ($retc) {
               if ( $founduser || $foundgroup ) {
                  $logger->debug("$ll at least a active user or group config found  [" . session('user') . "]");

                  $fsirole =~ s/^.//s;                                                                                             # first char . delete
                  if ( "$fsirole" eq "" ) {
                     $logger->trace("  user [$domainuser] has only read only role  [" . session('user') . "]");
                     session 'role' => "none";
                     set_flash("!W:You are logged with read ony role.");
                  } else {
                     $logger->trace("  user [$domainuser] role: $fsirole  [" . session('user') . "]");
                     session 'role' => $fsirole;
                     set_flash("!S:You are logged in as $fsirole .");
                  }
                  if ( defined $ldap ) {
                     $logger->trace("$ll unbind session  [" . session('user') . "]");
                     $mesg = $ldap->unbind;

                     $logger->debug("$ll  domain user [$domainuser] logged in  [" . session('user') . "]");
                     session 'logged_in' => true;
                     session 'user'      => $windomain . "\\" . $domainuser;
                     session 'logintime' => TimeStamp(14);

                     $logger->trace("$ll redirect to login /  [" . session('user') . "]");
                     return redirect '/';
                  } else {
                     $logger->error("$ll no ldap session exist to unbind - why?  [" . session('user') . "]");
                  }
               } else {
                  $errmsg = "No active user or group config found";
                  $logger->debug("$ll  no active user or group config found  [" . session('user') . "]");
               }
            } ## end unless ($retc)

         } else {
            $logger->warn("$ll no domain configure in rzenv.xml - do not support domain user login  [" . session('user') . "]");
            $errmsg = "Do not support domain user login";
         }

      } else {                                                                                                                     # local login
         my $found=0;
         
         $logger->debug("$ll login is a local user  [" . session('user') . "]");

         foreach my $user ( keys %{ $users{'user'} } ) {
            $logger->trace("$ll local user active?  [" . session('user') . "]");
            if ( defined "$users{'user'}{$user}{active}" ) {
               if ( "$users{'user'}{$user}{active}" eq "yes" ) {
                  $logger->trace("  local user [$user] same as input user [$inuser] ?  [" . session('user') . "]");
                  if ( $user eq $inuser ) {
                     $logger->trace("  ==> found user  [" . session('user') . "]");
                     $found = 1;

                     # my $role=$users{'user'}{$user}{role};
                     my $pwhash = $users{'user'}{$user}{pw};
                     $logger->trace("  user pw: $pwhash  [" . session('user') . "]");
                     my $valid = Crypt::SaltedHash->validate( $pwhash, $inpw );
                     if ($valid) {
                        $logger->debug("$ll  user [$inuser] logged in  [" . session('user') . "]");
                        session 'logged_in' => true;
                        session 'user'      => $inuser;
                        session 'logintime' => TimeStamp(14);
                        my $role = "";
                        foreach my $roleconf ( keys %{ $users{'user'}{$user}{'role'} } ) {
                           $role = $role . "," . $roleconf;
                        }
                        $role =~ s/^.//s;                                                                                          # first char delete
                        if ( "$role" eq "" ) {
                           $logger->trace("  user [$user] has only read only role  [" . session('user') . "]");
                           session 'role' => "none";
                           set_flash("!W:You are logged with read ony role.");
                        } else {
                           $logger->trace("  user [$user] role: $role  [" . session('user') . "]");
                           session 'role' => $role;
                           set_flash("!S:You are logged in as $role .");
                        }
                        return redirect '/';
                     } else {
                        $logger->warn("  user enter invalid password  [" . session('user') . "]");
                        $errmsg = "Invalid password";
                     }
                     last;
                  } ## end if ( $user eq $inuser )
               } else {
                  $logger->trace("$ll inactive user [$user]  [" . session('user') . "]");
               }
            } else {
               $logger->trace("$ll no active flag = inactive user [$user]  [" . session('user') . "]");
            }

         } ## end foreach my $user ( keys %{ $users{'user'} } )
         unless ($found) {
            $logger->warn("  ==> user unknown  [" . session('user') . "]");
            $errmsg = "Invalid username";
         }
      } ## end else [ if ( ( $inuser =~ m{\\} ) || ( $inuser =~ m{@} ) ) ]

   } ## end if ( request->method() eq "POST" )
   template 'login',
     {
       'version' => $ver,
       'vitemp'  => $host,
       'err'     => $errmsg,
       'vienv'   => $global{'vienv'}, };
};


any [ 'get', 'post' ] => '/logout' => sub {
   app->destroy_session;
   set_flash('!S:You are logged out.');
   if ( request->method() eq "POST" ) {
      if ( params->{'Login'} ) {
         return redirect '/login';
      } else {
         redirect '/';
      }
   } else {
      app->destroy_session;
      template 'logout',
        {
          'version' => $ver,
          'vitemp'  => $host,
          'vienv'   => $global{'vienv'}, };
   } ## end else [ if ( request->method() eq "POST" ) ]
};
