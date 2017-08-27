any [ 'get', 'post' ] => '/showportallog' => sub {
   my $weburl = '/showportallog';
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

         my $logdatei   = param('log');
         my $tailformat = "no";
         $tailformat = param('tail');

         my $sess_reload = $weburl;
         $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
         session 'reload' => $sess_reload;

         my $sess_back = backurl_getlast("");
         $logger->trace("$ll  => url back set to $sess_back  [" . session('user') . "]");
         $retc = backurl_add("$sess_back");

         if ( -f "$global{'logdir'}/$logdatei" ) {
            template 'show_portallog.tt',
              {
                'msg'     => get_flash(),
                'version' => $ver,
                'pfad'    => "$global{'logdir'}/",
                'file'    => $logdatei,
                'vitemp'  => $host,
                'tail'    => $tailformat,
                'vienv'   => $global{'vienv'}, };
         } else {
            template 'error',
              {
                'msg'     => "file $global{'logdir'}/$datei does not exist",
                'version' => $ver,
                'vitemp'  => $host,
                'vienv'   => $global{'vienv'}, };
         } ## end else [ if ( -f "$global{'logdir'}/$logdatei" ) ]
      } elsif ( request->method() eq "POST" ) {
         $logger->debug("$ll  POST Section  [" . session('user') . "]");
         my %params = params;

         use Data::Dumper;

         if ( $logger->is_trace() ) {
            my $dumpout = Dumper( \%params );
            $logger->trace("$ll Overview-Dump: $dumpout");
         }

         my $sess_reload = session('reload');
         $logger->trace("$ll  Session reload: [$sess_reload]  [" . session('user') . "]");

         my $sess_back = backurl_getlast("$sess_reload");
         $logger->trace("$ll  Session back: [$sess_back]  [" . session('user') . "]");

         if ( params->{'Logout'} ) {
            $logger->info("$ll  logout  [" . session('user') . "]");
            return redirect '/logout';
         } elsif ( params->{'Back'} ) {
            $logger->trace("$ll  go back to [$sess_back]  [" . session('user') . "]");
            return redirect $sess_back;
         } elsif ( params->{'Reload'} ) {
            my $new_session = $sess_reload . "?" . params->{'Reload'};
            $logger->trace("$ll  reload to [$new_session]  [" . session('user') . "]");
            $retc = backurl_add("$sess_back");
            return redirect $sess_reload . '?' . params->{'Reload'};
         } elsif ( params->{'options'} ) {
            my $new_session = $sess_reload . "?" . params->{'options'};
            $logger->trace("$ll  reload to [$new_session]  [" . session('user') . "]");
            $retc = backurl_add("$sess_back");
            return redirect $sess_reload . '?' . params->{'options'};
         } else {
            return redirect $sess_back;
         }
      } else {
         template 'error',
           {
             'msg'     => "unknown method in /admin",
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'}, };
      } ## end else [ if ( request->method() eq "GET" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
