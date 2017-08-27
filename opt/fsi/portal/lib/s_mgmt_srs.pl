any [ 'get', 'post' ] => '/mgmt_srs/:pool' => sub {
   my $weburl = '/mgmt_srs';
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
         my $xenpool = param('pool');

         if ( "$xenpool" eq "" ) {
            $looger->error("cannot detect xen pool  [" . session('user') . "]");
            set_flash("!E:cannot detect xen pool");
            return redirect '/overview';
         } else {
            my $srhash_ref;
            my $srnewhash_ref;
            
            
            $logger->trace("$ll  pool: [$xenpool]  [" . session('user') . "]");

            my $sess_reload = $weburl . '/' . $xenpool;
            $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
            session 'reload' => $sess_reload;
            $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
            $retc = backurl_add("$sess_reload");

            $retc = db_reload();
            if ($retc) {
               $looger->error("cannot reload db for xen pool $xenpool  [" . session('user') . "]");
               set_flash("!E:cannot reload db for xen pool $xenpool");
               return redirect '/overview';
            } else {
               my $xenver = db_get_typ_pool($xenpool);
               my $poolpath="$global{'fsiinstdir'}/$xenver/ks/pool/$xenpool";

               unless ( -f "$poolpath/lunlistreload.last" ) {
                  $logger->debug("$ll no pool srs info exist  [" . session('user') . "]");
                  $retc = get_pool_srs_fork( $xenpool );
                  if ($retc) {
                     $errmsg = "fork getting pool [$xenpool] srs failed";
                     $logger->warn("$errmsg  [" . session('user') . "]");
                     set_flash("!E:$errmsg");
                  }
               } else {
                  $logger->info("$ll  pool srs info exist - read it");
                  $srhash_ref=readjsonfile("$poolpath/info.srs");
                  if ( $global{'logprod'} < 10000 ) {
                     my $dumpout = Dumper( $srhash_ref );
                     $logger->trace("$ll Pool srs dump: $dumpout");
                  }
               }

               unless ( -f "$poolpath/lunnewlist.last" ) {
                  $logger->debug("$ll no pool srs new info exist  [" . session('user') . "]");
                  $retc = get_pool_lvmohba_fork( $xenpool );
                  if ($retc) {
                     $errmsg = "fork getting pool [$xenpool] new srs failed";
                     $logger->warn("$errmsg  [" . session('user') . "]");
                     set_flash("!E:$errmsg");
                  }
               } else {
                  $logger->info("$ll  pool srsnew info exist - read it");
                  $srnewhash_ref=readjsonfile("$poolpath/info.srsnew");
                  if ( $global{'logprod'} < 10000 ) {
                     my $dumpout = Dumper( $srnewhash_ref );
                     $logger->trace("$ll Pool srs new dump: $dumpout");
                  }
               }

               template 'mgmt_srs.tt',
                 {
                   'msg'      => get_flash(),
                   'version'  => $ver,
                   'file'     => $datei,
                   'vitemp'   => $host,
                   'srs'      => $srhash_ref,
                   'srs_new'  => $srnewhash_ref,
                   'entries'  => $serverhash_p,
                   'pool'     => $xenpool,
                   'rzconfig' => \%rzconfig,
                   'vienv'    => $global{'vienv'}, };
            }

         } ## end else [ if ( "$xenpool" eq "" ) ]

      } elsif ( request->method() eq "POST" ) {
         $logger->debug("$ll  POST Section  [" . session('user') . "]");
         my %params      = params;
         my $sess_reload = session('reload');
         $retc = backurl_add("$sess_reload");

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
            $logger->debug("$ll  reload xen pool view [$sess_reload]  [" . session('user') . "]");
            redirect $sess_reload;
         } elsif ( params->{'LUNNEWLIST'} ) {
            $logger->debug("$ll  reload sr new list in pool [" . params->{'LUNNEWLIST'} . "]  [" . session('user') . "]");
            my $xenver = db_get_typ_pool(params->{'LUNNEWLIST'} );
            my $poolpath="$global{'fsiinstdir'}/$xenver/ks/pool/" . params->{'LUNNEWLIST'};
            my $poollastfile = "$poolpath/lunnewlist.last";
            if ( -f "$poollastfile" ) {
               unless ( unlink($poollastfile) ) {
                  my $errmsg="can't delete $poollastfile [" . session('user') . "]";
                  $logger->error("$warnmsg");
                  set_flash("!E:$warnmsg");
               } else {
                  $logger->debug("$ll  $poollastfile deleted!");
               }
            }
            redirect $sess_reload;
         } elsif ( params->{'LUNLISTRELOAD'} ) {
            $logger->debug("$ll  reload sr current attached luns list in pool [" . params->{'LUNLISTRELOAD'} . "]  [" . session('user') . "]");
            my $xenver = db_get_typ_pool(params->{'LUNLISTRELOAD'} );
            my $poolpath="$global{'fsiinstdir'}/$xenver/ks/pool/" . params->{'LUNLISTRELOAD'};
            my $poollastfile = "$poolpath/lunlistreload.last";
            if ( -f "$poollastfile" ) {
               unless ( unlink($poollastfile) ) {
                  my $errmsg="can't delete $poollastfile [" . session('user') . "]";
                  $logger->error("$warnmsg");
                  set_flash("!E:$warnmsg");
               } else {
                  $logger->debug("$ll  $poollastfile deleted!");
               }
            }
            redirect $sess_reload;
         } elsif ( params->{'DELLUNSRS'} ) {
            $logger->debug("$ll  delete lun srs in pool [" . params->{'DELLUNSRS'} . "]  [" . session('user') . "]");
            @markedsr = ();
            if ( ref $params{'MarkedSR'} eq 'ARRAY' ) {
               $logger->trace("$ll  more than one sr marked  [" . session('user') . "]");
               foreach my $marksr ( @{ $params{'MarkedSR'} } ) {
                  if ( $marksr ne "0" && $marksr ne "on" ) {
                     @markedsr = ( @markedsr, $marksr );
                  }
               }
               session 'srarray' => "@markedsr";
               redirect '/mgmt_srs-delete/' . params->{'DELLUNSRS'};
            } else {
               $logger->trace("$ll   MarkedSR: [" . $params{'MarkedSR'} . "]");
               if ( $params{'MarkedSR'} eq '' ) {
                  $logger->trace("$ll  no sr marked  [" . session('user') . "]");
                  my $warnmsg="no sr marked to delete in xenserver pool [" . params->{'DELLUNSRS'} . "] ";
                  $logger->warn("$warnmsg [" . session('user') . "]");
                  set_flash("!W:$warnmsg");
               } elsif ( $params{'MarkedSR'} ne "on" ) {
                  $logger->trace("$ll  only one sr marked  [" . session('user') . "]");
                  @markedsr = ( @markedsr, $params{'MarkedSR'} );
                  session 'srarray' => "@markedsr";
                  redirect '/mgmt_srs-delete/' . params->{'DELLUNSRS'};
               } else {
                  $logger->trace("$ll  no sr marked  [" . session('user') . "]");
                  my $warnmsg="no sr marked to delete in xenserver pool [" . params->{'DELLUNSRS'} . "] ";
                  $logger->warn("$warnmsg [" . session('user') . "]");
                  set_flash("!W:$warnmsg");
               }
            }
            redirect $sess_reload;

         } elsif ( params->{'CREATELUNSRS'} ) {
            $logger->debug("$ll  create lun srs in pool [" . params->{'CREATELUNSRS'} . "]  [" . session('user') . "]");
            @markedsr = ();
            if ( ref $params{'MarkedLUN'} eq 'ARRAY' ) {
               $logger->trace("$ll  more than one sr to create marked  [" . session('user') . "]");
               foreach my $marksr ( @{ $params{'MarkedLUN'} } ) {
                  if ( $marksr ne "0" && $marksr ne "on" ) {
                     @markedsr = ( @markedsr, $marksr );
                     $logger->debug("$ll  create lun sr with uuid [$marksr] [" . session('user') . "]");
                  }
               }
               $logger->trace("$ll   save list of lun uuids in session file");
               session 'srarray' => "@markedsr";
               $logger->trace("$ll   redirect to create overview of fc lun srs");
               redirect '/mgmt_srs-create/' . params->{'CREATELUNSRS'};
            } else {
               $logger->trace("$ll   MarkedSR: [" . $params{'MarkedSR'} . "]");
               if ( $params{'MarkedLUN'} eq '' ) {
                  $logger->trace("$ll  no lun marked  [" . session('user') . "]");
                  my $warnmsg="no lun marked to create sr in xenserver pool [" . params->{'CREATELUNSRS'} . "] ";
                  $logger->warn("$warnmsg [" . session('user') . "]");
                  set_flash("!W:$warnmsg");
               } elsif ( $params{'MarkedLUN'} ne "on" ) {
                  $logger->trace("$ll  only one sr marked  [" . session('user') . "]");
                  @markedsr = ( @markedsr, $params{'MarkedLUN'} );
                  session 'srarray' => "@markedsr";
                  redirect '/mgmt_srs-create/' . params->{'CREATELUNSRS'};
               } else {
                  $logger->trace("$ll  no lun marked  [" . session('user') . "]");
                  my $warnmsg="no lun marked to create sr in xenserver pool [" . params->{'CREATELUNSRS'} . "] ";
                  $logger->warn("$warnmsg [" . session('user') . "]");
                  set_flash("!W:$warnmsg");
               }
            }
            redirect $sess_reload;

        } else {
            $logger->error("unknown method for fsi  [" . session('user') . "]");
            template 'error',
              {
                'msg'     => "unknown method in /showxp",
                'version' => $ver,
                'vitemp'  => $host,
                'vienv'   => $global{'vienv'}, };
         } ## end else [ if ( params->{'Overview'} ) ]
      } else {
         template 'error',
           {
             'msg'     => "unknown method in /showxp",
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'}, };
      } ## end else [ if ( request->method() eq "GET" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
