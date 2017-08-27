any [ 'get', 'post' ] => '/editfile' => sub {
   my $weburl = '/editfile';
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
      my $file = session('edit_file');
      if ( $file eq "" ) {
         $logger->warn("$ll  unknown call - without file name  [" . session('user') . "]");
         return redirect '/';
      }
      my $ctrl        = session('edit_ctrl');
      my $forwhat     = session('edit_what');
      my $fileformat  = session('edit_format');
      my $sess_method = request->method();
      $logger->trace("$ll  => method: $sess_method   [" . session('user') . "]");
      if ( request->method() eq "GET" ) {
         my $sess_reload = "/editfile";
         $logger->trace("$ll  set reload: $sess_reload  [" . session('user') . "]");
         session 'reload' => $sess_reload;
         $logger->trace("$ll  => url back set to $sess_reload  [" . session('user') . "]");
         $retc = backurl_add("$sess_reload");
         if ( $forwhat eq "" ) {
            $ctrl    = "none";
            $forwhat = "none";
            $logger->trace("$ll   only edit file - not for server or pool  [" . session('user') . "]");
         } elsif ( $ctrl eq "" ) {
            $ctrl = "srv";
            $logger->trace("$ll   no control found - take default srv  [" . session('user') . "]");
         }
         if ( $fileformat eq "" ) {
            $fileformat = "text";
         }
         $logger->trace("$ll   file: $file  [" . session('user') . "]");
         $logger->trace("$ll   control: $ctrl  [" . session('user') . "]");
         $logger->trace("$ll   what file: $forwhat  [" . session('user') . "]");
         $logger->trace("$ll   file format: $fileformat  [" . session('user') . "]");
         if ( -f "$file" ) {
            my $inhalt = read_file($file);
            template 'edit_file.tt',
              {
                'msg'      => get_flash(),
                'version'  => $ver,
                'file'     => $file,
                'filemode' => $fileformat,
                'inhalt'   => $inhalt,
                'server'   => $server,
                'vitemp'   => $host,
                'vienv'    => $global{'vienv'}, };
         } else {
            template 'error',
              {
                'msg'     => "file $file does not exist",
                'version' => $ver,
                'vitemp'  => $host,
                'vienv'   => $global{'vienv'}, };
         } ## end else [ if ( -f "$file" ) ]
      } elsif ( request->method() eq "POST" ) {
         my %params      = params;
         my $sess_reload = session('reload');
         my $sess_back   = backurl_getlast("$sess_reload");
         if ( $global{'logprod'} < 10000 ) {
            my $dumpout = Dumper( \%params );
            $logger->trace("$ll Overview-Dump: $dumpout");
         }
         my $file = session('edit_file');
         if ( $file eq "" ) {
            my $errmsg = "cannot get file name - do not know where I can save changes - abort";
            $logger->error("$ll  $errmsg  [" . session('user') . "]");
            set_flash("!E:ERROR: $errmsg");
            return redirect '/';
         } ## end if ( $file eq "" )
         if ( params->{'Abort'} ) {
            $logger->debug("$ll   abort edit file $file  [" . session('user') . "]");
            return redirect $sess_back;
         } elsif ( params->{'Save'} ) {
            $logger->debug("$ll   save changes in file $file  [" . session('user') . "]");
            my $newinhalt = params->{'fileinhalt'};
            if ( "$newinhalt" eq "" ) {
               $logger->debug("$ll   no changes made in file - ignore save  [" . session('user') . "]");
               set_flash("!W:no changes made");
            } else {
               $logger->debug("$ll   changes made in file  [" . session('user') . "]");
               my $dest1 = "$file.webbak";
               my ( $filename, $dirs, $suffix ) = fileparse($file);
               my $dest2 = "$global{'rubbishdir'}" . "/$filename" . "$suffix-" . TimeStamp(13);
               $logger->trace("$ll   additional copy to $dest2  [" . session('user') . "]");
               if ( -f $file ) {
                  my $cpok = copy( $file, $dest1 );
                  unless ($cpok) {
                     my $errmsg = $!;
                     $logger->error("backup $file to $dest2  [" . session('user') . "]");
                     $logger->error("$errmsg  [" . session('user') . "]");
                     set_flash("!E:Error backup $file - abort");
                  } else {
                     $cpok = copy( $file, $dest2 );
                     unless ($cpok) {
                        my $errmsg = $!;
                        $logger->error("backup $file  [" . session('user') . "]");
                        $logger->error("$errmsg  [" . session('user') . "]");
                        set_flash("!E:Error backup $file - abort");
                     } else {
                        $logger->info("$ll  $file backuped - write back actual changes  [" . session('user') . "]");
                        $newinhalt =~ s/\r\n/\n/g;
                        write_file( $file, $newinhalt );
                        set_flash("!S:changes written to $file");
                     }
                  } ## end else
               } else {
                  $logger->error("cannot find $file - abort  [" . session('user') . "]");
                  set_flash("!E:Cannot find file $file to write back changes - abort");
               }
            } ## end else [ if ( "$newinhalt" eq "" ) ]
            return redirect $sess_back;
         } elsif ( params->{'Reload'} ) {
            $logger->debug("$ll   reload original file $file  [" . session('user') . "]");
            $retc = backurl_add("$sess_back");
            redirect $sess_reload;
         } else {
            $retc = backurl_add("$sess_back");
            redirect $sess_reload;
         }
      } else {
         template 'error',
           {
             'msg'     => "unknown method in /editfile",
             'version' => $ver,
             'vitemp'  => $host,
             'vienv'   => $global{'vienv'}, };
      } ## end else [ if ( request->method() eq "GET" ) ]
   } ## end else [ if ( !session('logged_in') ) ]
};
