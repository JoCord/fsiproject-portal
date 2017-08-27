any [ 'get', 'post' ] => '/xenvm/:job?' => sub {
   my $weburl = '/xenvm';
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
      my $c = 1;
      my @markedvm = split( " ", session('vmarray') );
      $logger->trace("$ll  marked vm list: @markedvm  [" . session('user') . "]");
      my $vmcount = $#markedvm + 1;
      my $vmnames = "";

      if ( request->method() eq "POST" ) {
         $logger->debug("$ll  POST Section  [" . session('user') . "]");
         my %params = params;

         my $sess_reload = session('reload');
         my $sess_back   = backurl_getlast("$sess_reload");

         if ( params->{'OK'} ) {
            my $job        = param('OK');
            my $poolmaster = get_master($xenpool);
            if ( -z $poolmaster ) {
               $errmsg = "Error getting poolmaster";
               $logger->error("$errmsg  [" . session('user') . "]");
               set_flash("!E:$errmsg");
               $retc = 99;
            } else {
               $logger->trace("$ll  OK Button  [" . session('user') . "]");
               foreach (@markedvm) {
                  my ( $name, $host, $uuid ) = split( ':', $_ );
                  $logger->trace("$ll  $job vm: $name   [" . session('user') . "]");
                  $vmnames = "$vmnames $name";
                  $logger->debug("$ll  vm $name do $job on $host with master $poolmaster - uuid $uuid  [" . session('user') . "]");
                  my $user = session('user');
                  sleep int( rand(4) ) + 1;
                  $pid = fork();
                  if ( $pid < 0 ) {
                     $logger->error("Failed to fork process - abort  [" . session('user') . "]");
                     $retc = 99;
                  } elsif ( $pid == 0 ) {                                                                                          #child process
                     $logger->debug("$ll  CHILD PROCESS [$pid]  [" . session('user') . "]");
                     $global{'newport'} = 6432;
                     my $parameter = "$job,$poolmaster,$uuid,$host,$name,$user";
                     $logger->trace("$ll   vm param [$parameter]  [" . session('user') . "]");
                     $retc = vmxen($parameter);
                     unless ($retc) {
                        $logger->trace("$ll  ok  [" . session('user') . "]");
                     } else {
                        $logger->error("failed cmd [$eo]  [" . session('user') . "]");
                        $errmsg = "Cannot start job for $name";
                     }
                     exit $retc;
                  } else {                                                                                                         #execute rest of parent}
                     $logger->trace("$ll  PARENT PROCESS - go on after fork ($pid)  [" . session('user') . "]");
                  }
               } ## end foreach (@markedvm)
               unless ($retc) {
                  set_flash("!S:$job vms successful: $vmnames");
               } else {
                  set_flash("!E:$errmsg");
               }
            } ## end else [ if ( -z $poolmaster ) ]
         } else {
            foreach (@markedvm) {
               my ( $name, $host, $uuid ) = split( ':', $_ );
               $vmnames = "$vmnames $name";
            }
            my $job = param('Abort');
            set_flash("!W:Abort $job vms: $vmnames");
         } ## end else [ if ( params->{'OK'} ) ]
         redirect $sess_back;
      } else {                                                                                                                     # get - Darstellung Liste ausgewählter VMs
         $logger->debug("$ll  GET Section  [" . session('user') . "]");
         my $job = param('job');
         $logger->trace("$ll func start: /xenvm with $job  [" . session('user') . "]");

         my $sess_reload = $weburl;
         $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
         $retc = backurl_add("$sess_reload");

         template 'xenvm',
           {
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'},
             'job'     => $job,
             'vms'     => \@markedvm, };
      } ## end else [ if ( request->method() eq "POST" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
