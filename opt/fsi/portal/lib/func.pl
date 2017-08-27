#
#   sub-func - global function file
#
#   This program is free software; you can redistribute it and/or modify it under the
#   terms of the GNU General Public License as published by the Free Software Foundation;
#   either version 3 of the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
#   without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#   See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License along with this program;
#   if not, see <http://www.gnu.org/licenses/>.
#
# use File::Path;
#
#

our %color = (                                               
               "green"  => "\033[32;1m", 
               "red"    => "\033[31;1m",
               "cyan"   => "\033[36;1m",
               "white"  => "\033[37;1m",
               "normal" => "\033[m",
               "bold"   => "\033[1m",
               "nobold" => "\033[0m",
                );                

sub create_path {
   my $fc   = ( caller(0) )[ 3 ];
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   $flvl++;
   my ( $path, $mask ) = @_;
   if ( "$mask" eq "" ) {
      $mask = "0711";
   }
   $logger->trace("$ll path mode [$mask]");
   $logger->trace("$ll try to create path [$path]");
   if ( -d $path ) {
      $logger->debug("$ll path [$path] exist - nothing to do");
   } else {
      my $save_u = umask();
      umask(0);
      eval( mkpath( $path, 0, $mask ) );
      if (@$) {
         $logger->error("problem creating [$path]");
         $logger->error("error: [@$]");
         $retc = 98;
      } else {
         $logger->debug("$ll path [$path] created sucessful");
      }
      umask($save_u);
   } ## end else [ if ( -d $path ) ]
   $flvl--;
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   return ($retc);
} ## end sub create_path

sub delete_path {
   my $fc   = ( caller(0) )[ 3 ];
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   $flvl++;
   my $path = shift();
   $logger->trace("$ll try to delete path [$path]");
   if ( -d $path ) {
      $logger->debug("$ll path [$path] exist - delete");
      eval { rmtree($path) };
      if ($@) {
         $logger->error("problem deleting [$path]");
         $logger->error("error: [$@]");
         $retc = 98;
      } else {
         $logger->debug("$ll path [$path] deleted sucessful");
      }
   } else {
      $logger->debug("$ll path does not exist");
   }
   $flvl--;
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   return ($retc);
} ## end sub delete_path

sub read_config {                                                                                                                  # $retc=read_config($cfgfile,\%g_cfg);
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my ( $configfile, $config_ref ) = @_;
   $logger->debug("$ll find config file [$configfile]");
   if ( -e $configfile ) {
      $logger->debug("$ll found config file - try to open ..");
      open CONFIG, "$configfile" or $retc = 99;
      if ($retc) {
         $logger->error("cannot open config file [$configfile]");
      } else {
         $logger->debug("$ll open ok");
      }
   } else {
      $logger->error("cannot find config file [$configfile]");
      $retc = 88;
   }
   unless ($retc) {
      $logger->debug("$ll Read config file ..");
      while (<CONFIG>) {
         chomp;                                                                                                                    # no newline
         s/#.*//;                                                                                                                  # no comments
         s/^\s+//;                                                                                                                 # no leading white
         s/\s+$//;                                                                                                                 # no trailing white
         next unless length;                                                                                                       # anything left?
         my ( $var, $value ) = split( /\s*=\s*/, $_, 2 );
         if ( defined($value) ) {
            $value =~ s/^'//;                                                                                                      # remove starting '
            $value =~ s/'$//;                                                                                                      # remove ending '
            $value =~ s/^"//;                                                                                                      # remove starting "
            $value =~ s/"$//;                                                                                                      # remove ending "
            ${$config_ref}{$var} = $value;
            $logger->trace("$ll  ==> key: [$var] = [$value]");
         } else {
            $logger->trace("$ll  var: [$var] without value");
         }
      } ## end while (<CONFIG>)
      $logger->debug("$ll all read");
      $logger->debug("$ll close config file");
      close CONFIG;
   } ## end unless ($retc)
                                                                                                                                   #print Dumper( \$config_ref );
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
} ## end sub read_config

our $ipre = qr/
    2(?:5[0-5] | [0-4]\d)
    |
    1\d\d
    |
    [1-9]?\d
/x;

our $dnsre=qr/^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]))*$/;
our $dnsipre = qr/^(((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|((([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])))$/;


## For printing colors to the console
our ${colorRed}    = "\033[31;1m";
our ${colorGreen}  = "\033[32;1m";
our ${colorCyan}   = "\033[36;1m";
our ${colorWhite}  = "\033[37;1m";
our ${colorNormal} = "\033[m";
our ${colorBold}   = "\033[1m";
our ${colorNoBold} = "\033[0m";

sub TimeStamp {
   my ($format) = $_[ 0 ];
   unless ( defined $format ) { $format = 0; }
   my ($rettime);
   ( my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst ) = localtime();
   $year = $year + 1900;
   $mon  = $mon + 1;
   if    ( length($mon) == 1 )  { $mon     = "0$mon"; }
   if    ( length($mday) == 1 ) { $mday    = "0$mday"; }
   if    ( length($hour) == 1 ) { $hour    = "0$hour"; }
   if    ( length($min) == 1 )  { $min     = "0$min"; }
   if    ( length($sec) == 1 )  { $sec     = "0$sec"; }
   if    ( $format == 1 )       { $rettime = "$year\-$mon\-$mday $hour\:$min\:$sec"; }
   elsif ( $format == 2 )       { $rettime = $mon . $mday . $year; }
   elsif ( $format == 3 ) { $rettime = substr( $year, 2, 2 ) . $mon . $mday; }
   elsif ( $format == 4 ) { $rettime = $mon . $mday . substr( $year, 2, 2 ); }
   elsif ( $format == 5 ) { $rettime = $year . $mon . $mday . $hour . $min . $sec; }
   elsif ( $format == 6 ) { $rettime = $year . $mon . $mday; }
   elsif ( $format == 7 ) { $rettime = $mday . '/' . $mon . '/' . $year . ' ' . $hour . ':' . $min . ':' . $sec; }
   elsif ( $format == 8 ) { $rettime = $year . $mon . $mday . $hour . $min; }
   elsif ( $format == 9 ) { $rettime = $mday . '/' . $mon . '/' . $year; }
   elsif ( $format == 10 ) { $rettime = "$hour\:$min\:$sec"; }
   elsif ( $format == 11 ) { $rettime = "$hour\:$min\:$sec - $mday.$mon.$year"; }
   elsif ( $format == 12 ) { $rettime = "$year.$mon.$mday $hour:$min:$sec"; }
   elsif ( $format == 13 ) { $rettime = "$year$mon$mday$hour$min"; }
   elsif ( $format == 14 ) { $rettime = "$year.$mon.$mday-$hour:$min:$sec"; }
   else                    { $rettime = "5.8.1972"; }
   return $rettime;
} ## end sub TimeStamp

sub set_daemon {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my ( $dbh, $daemon, $status ) = @_;
   
   $logger->trace("$ll  set daemon [$daemon] to status [$status]");

   my $sql = "SELECT status FROM $global{'dbt_daemon'} WHERE daemon = \'$daemon\'";
   my $sth = $dbh->prepare($sql) or die $dbh->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid     = $sth->rows;
   if ( $lastid == 0 ) {
      $logger->trace("$ll add new $daemon in daemon stat table");
      
      my $sqladd = 'INSERT INTO ' . $global{'dbt_daemon'} . ' (daemon, status ) values (?,?)';
      my $sthadd = $dbh->prepare($sqladd) or die $dbh->errstr;
      $sthadd->execute( $daemon, $status );
      my $fehler = $sthadd->errstr;
      if ($fehler) {
         $logger->error("DB message: $fehler");
         $retc = 99;
      } else {
         $sthadd->finish();
      }
   } else {
      $logger->trace("$ll change $daemon in daemon stat table");

      my $updatecmd = "UPDATE $global{'dbt_daemon'} SET status = '$status'  WHERE daemon = '$daemon' ";
      my $updsth = $dbh->prepare($updatecmd) or die $dbh->errstr;
      $logger->trace("$ll  $updatecmd");
      $updsth->execute();
      my $fehler = $sth->errstr;
      if ($fehler) {
         $logger->error("DB Meldung: $fehler");
      } else {
         $updsth->finish();
      }
   }

   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub read_daemon {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my ( $dbh, $daemon ) = @_;
   my %pid_file;
   my $pid_nr;
   my $pid_run;
   my $fh;
   
   my $status="off";
   $logger->trace("$ll  read daemon [$daemon] status ");
   
   my $sql    = "SELECT status FROM $global{'dbt_daemon'} WHERE daemon = \'$daemon\'";
   $logger->trace("$ll  sql: $sql");
   my $sth = $dbh->prepare($sql) or die $dbh->errstr;
   $sth->execute or die $sth->errstr;
   my $lastid = $sth->rows;

   if ( $lastid > 1 ) {
      $logger->error("find more than one daemon entry [$daemon] - that`s not possible, abort");
      $retc = 99;
   } elsif ( $lastid == 1 ) {
      my @status_a = $sth->fetchrow_array;
      $logger->trace("$ll Status: $status_a[0]");
      $status = $status_a[ 0 ];
   } else {
      $logger->error("daemon entry [$daemon] not found - take default = off");
   }
   $sth->finish();
   
   if ( "$status" ne "off" ) {
      $pid_file{'online'}="/var/run/fsichkon.pid";
      $pid_file{'all'}="/var/run/fsid.pid";
      
      if ( -s $pid_file{$daemon} ) {
         open( $fh, "<", $pid_file{$daemon} ) || do {
            $retc=99;
            $logger->error("cannot open [$pid_file{$daemon}] - but file exist - ignore");
         };
      
         unless ($retc) {
            ( $pid_nr ) = <$fh>; 
            chomp $pid_nr; 
            close $fh;
            $pid_run = kill 0, $pid_nr;
         }
         
         unless ( $pid_run ) {
            $logger->trace("$ll  daemon [$daemon] was killed - wrong status in db, change to off");
            $status="off";
         }
      } else {
         $logger->trace("$ll daemon [$daemon] has no pid file - change status to off");
         $status="off";
      }
   }

   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($status);
}

return 1;
