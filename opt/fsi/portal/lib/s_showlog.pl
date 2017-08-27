any [ 'get', 'post' ] => '/showlog/:tail' => sub {
   my $weburl = '/showlog';
   session 'now' => $weburl;
   local *__ANON__ = "dance: $weburl";                                                                                             # default if no function for caller sub
   $flvl=2;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: $weburl");
   my $retc   = 0;
   my $errmsg = "";

   my $tail   = params->{tail};                                                                                                     # in url mode
   $logger->trace("$ll  tail: [$tail]");

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
            my $sess_reload = $weburl . "/" . $tail;
            $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
            session 'reload' => $sess_reload;
            $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
   
            my $srvid = session('srvid');
            $logger->trace("$ll  server id: $srvid  [" . session('user') . "]");
            my $db_typ = $serverhash_p->{$srvid}{'db_typ'};
            my $datei  = $serverhash_p->{$srvid}{'db_srv'};
            if ( $datei =~ /((.+?)|(.*?))\./ ) {
               $datei = $1;
            }
            my $server = $datei;
            $logger->trace("$ll  host: $datei  [" . session('user') . "]");
            $logger->trace("$ll  db_typ: $db_typ  [" . session('user') . "]");
   
            my $pfad = $db_typ . "/ks/log/";
            $logger->trace("$ll  path: $pfad  [" . session('user') . "]");
            $datei = $datei . ".log";
            $logger->trace("$ll  file: $datei  [" . session('user') . "]");
            if ( -f "$global{'fsiinstdir'}/$pfad$datei" ) {
               $retc = backurl_add("$sess_reload");
               $logger->debug("$ll  show log website  [" . session('user') . "]");
               template 'show_log.tt',
                 {
                   'msg'     => get_flash(),
                   'version' => $ver,
                   'path'    => "/fsi/$pfad",
                   'file'    => $datei,
                   'server'  => $server,
                   'vitemp'  => $host,
                   'tail'    => $tail,
                   'vienv'   => $global{'vienv'}, };
            } else {
               template 'error',
                 {
                   'msg'     => "file $pfad$datei does not exist",
                   'version' => $ver,
                   'vitemp'  => $host,
                   'vienv'   => $global{'vienv'}, };
            } ## end else [ if ( -f "$global{'fsiinstdir'}/$pfad$datei" ) ]
         }
         
      } elsif ( request->method() eq "POST" ) {
         $logger->trace("$ll  POST Section  [" . session('user') . "]");
         my %params = params;

         if ($logger->is_trace()) {
            my $dumpout=Dumper(\%params);
            $logger->trace("$ll Showlog POST Dump: $dumpout");  
         }

         my $sess_reload = session('reload');
         my $sess_back   = backurl_getlast("$sess_reload");
         
         if ( params->{'Back'} ) {
            return redirect $sess_back;
         } elsif ( params->{'Reload'} ) {
            $retc = backurl_add("$sess_reload");
            return redirect $sess_reload;
         } elsif ( params->{'tail'} ) {
            $logger->trace("$ll change [" . params->{'tailmode'} . "] display  [" . session('user') . "]");
            $retc = backurl_add("$sess_back");
            if ( params->{'tailmode'} eq "tail" ) {
               return redirect '/showlog/tail';
            } else {
               return redirect '/showlog/notail';
            }
         } else {
            $retc = backurl_add("$sess_back");
            return redirect '/showlog/notail';
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
