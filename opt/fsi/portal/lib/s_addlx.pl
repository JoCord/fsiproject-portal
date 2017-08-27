any [ 'get', 'post' ] => '/addlx' => sub {
   my $weburl = '/addlx';
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
      if ( request->method() eq "POST" ) {
         $logger->trace("$ll  start input from linux input site  [" . session('user') . "]");
         my %params;
         %params = params;
         my $reload = session('reload');
         my $back   = backurl_getlast("$reload");
         if ( params->{'OK'} ) {
            if ( $global{'logprod'} < 10000 ) {
               my $dump = Dumper( \%params );
               $logger->trace("$ll  Parameter Dump: [$dump]");
            }
            $logger->trace("$ll  params = OK  [" . session('user') . "]");
            my $retc = 0;

            $retc = add_lx( $scriptcall, $params{'Server'} );
            unless ($retc) {
               set_flash("!S:Add linux server $params{'Server'} ok!");
            } else {
               set_flash("!E:Error adding server $params{'Server'} - [$errmsg]");
            }
            return redirect "/$back";
         } elsif ( params->{'Back'} ) {
            $logger->trace("$ll  params back = $back  [" . session('user') . "]");
            return redirect "$back";
         } elsif ( params->{'Abort'} ) {
            set_flash("!W:User abort Linux add server!");
            return redirect "$back";
         }
      } elsif ( request->method() eq "GET" ) {
         $logger->trace("$ll  show linux input site  [" . session('user') . "]");
         $flvl--;
         if ( $global{'logprod'} < 10000 ) {
            my $dump = Dumper( \%rzconfig );
            $logger->trace("$ll  Parameter Dump: [$dump]  [" . session('user') . "]");
         }
         my $sess_reload = $weburl;
         $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
         $retc = backurl_add("$sess_reload");
         template 'addlx.tt',
           {
             'msg'      => get_flash(),
             'version'  => $ver,
             'vitemp'   => $host,
             'rzlist'   => \@rzlist,
             'rzconfig' => \%rzconfig,
             'vienv'    => $global{'vienv'}, };
      } else {
         template 'error',
           {
             'msg'     => "unknown method in /admin",
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'}, };
      } ## end else [ if ( request->method() eq "POST" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
