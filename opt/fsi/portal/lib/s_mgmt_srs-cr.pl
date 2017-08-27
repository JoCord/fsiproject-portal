any [ 'get', 'post' ] => '/mgmt_srs-create/:pool' => sub {
   my $weburl = '/mgmt_srs-create';
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

               if ( -f "$poolpath/lunnewlist.last" ) {
                  $logger->info("$ll  pool srsnew info exist - read it");
                  $srnewhash_ref=readjsonfile("$poolpath/info.srsnew");
                  if ( $global{'logprod'} < 10000 ) {
                     my $dumpout = Dumper( $srnewhash_ref );
                     $logger->trace("$ll Pool srs new dump: $dumpout");
                  }
                  
                  my @markedsr = split( " ", session('srarray') );
                  if ( $global{'logprod'} < 10000 ) {
                     my $dumpout = Dumper( @markedsr);
                     $logger->trace("$ll Marked sr uuid list: $dumpout");
                  }
                  
                  my $marksrhash = {};
                  
                  my $srcount = $#markedsr + 1;
                  foreach my $x (@markedsr) {
                     $marksrhash->{$x} = $srnewhash_ref->{'BlockDevice'}{$x};
                  }
                  if ( $global{'logprod'} < 10000 ) {
                     my $dumpout = Dumper( $marksrhash );
                     $logger->trace("$ll New srs dump: $dumpout");
                  }

                  template 'mark/mgmt_srs-create.tt',{
                      'msg'      => get_flash(),
                      'vitemp'   => $host,
                      'vienv'    => $global{'vienv'},
                      'version'  => $ver,
                      'srs'      => $marksrhash,
                      'pool'     => $xenpool,
                      'rzconfig' => \%rzconfig,};
               }
            }
         }

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
         } elsif ( params->{'OK'} ) {
            my $sess_back = backurl_getlast("$sess_reload");
            $logger->debug("$ll  create srs in pool [" . params->{'OK'} . "]  [" . session('user') . "]");
            my $sruuids = session('srarray');
            $sruuids =~ s/ /,/g;
            $logger->trace("$ll    uuids: $sruuids");

            $retc = srs_create_fork( params->{'OK'}, $sruuids );
            if ($retc) {
               $errmsg = "fork creating srs in pool [" . params->{'OK'} ."] failed";
               $logger->warn("$errmsg  [" . session('user') . "]");
               set_flash("!E:$errmsg");
            }
            
            $logger->debug("$ll  go back to $sess_back  [" . session('user') . "]");
            return redirect $sess_back;
         } else {
            set_flash("!W:Abort creating fibre channel lun srs");
            my $sess_back = backurl_getlast("$sess_reload");
            return redirect $sess_back;
         }
      } else {
         template 'error', {
             'msg'     => "unknown method in $weburl",
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'}, };
      } 
   }
};
