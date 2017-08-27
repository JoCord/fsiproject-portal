#!/usr/bin/perl -w
#
#   vmcopy.pl - copy dir (orignal from copy directory - not vm specify)
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
# global vars
our $ver = '1.07.01 - 22.5.2014';
my $retc = 0;
my $flvl = 0;                                                                                                                      # function level

# color vars
my ${colorRed}    = "\033[31;1m";
my ${colorGreen}  = "\033[32;1m";
my ${colorCyan}   = "\033[36;1m";
my ${colorWhite}  = "\033[37;1m";
my ${colorNormal} = "\033[m";
my ${colorBold}   = "\033[1m";
my ${colorNoBold} = "\033[0m";

# command line arguments
my %clarg = ( "dir" => "none", );

# modules
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Config::General;
use English;

# log4perl init
use File::Spec;
use File::Basename;
my $rel_path = File::Spec->rel2abs(__FILE__);
my ( $volume, $dirs, $prg ) = File::Spec->splitpath($rel_path);
my $prgname   = basename( $prg, '.pl' );
my $loglevel  = 0;
my $conf_file = $dirs . '../etc/log4p_vmc';
my $logfile   = "none";

# script specify global vars
# ----------------------------------------------------------------------------------------------------------------
my $clonematrix = $dirs . "../etc/clonematrix";
my %t_cp;
my %s_cp;

# script modules
use File::Path;
use File::Copy;
use File::Spec;
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use Net::SCP::Expect;
use Net::SSH::Perl;
use Net::SFTP::Foreign;
use Net::SFTP::Foreign::Constants qw (:flags);

# basis functions
# ----------------------------------------------------------------------------------------------------------------
sub onlinehelp() {
   print <<EOHELP;

program   ${colorRed}$prgname ${colorNormal}
version   ${colorRed}$ver ${colorNormal}

parameter --clone <clone or vm name to copy>
           
optional  --debug
          --trace
          --log <logfile>           

EOHELP
}

sub get_args() {
   my $counter = 0;
   my @ARGS    = @ARGV;                                                                                                            ## This is so later we can re-parse the command line args later if we need to
   my $numargv = @ARGS;
   unless ($numargv) {
      onlinehelp();
      exit(1);
   }
   for ( $counter = 0 ; $counter < $numargv ; $counter++ ) {
      print("\nArgument: $ARGS[$counter]\n");
      if ( $ARGS[ $counter ] =~ /^-h$/i ) {
         onlinehelp();
         exit(1);
      } elsif ( $ARGS[ $counter ] eq "" ) {
      } elsif ( $ARGS[ $counter ] =~ /^--help/ ) {
         onlinehelp();
         exit(1);
      } elsif ( $ARGS[ $counter ] =~ /^--clone$/ ) {
         $counter++;
         $clarg{'dir'} = "";
         if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
               if ( $clarg{'dir'} ) { $clarg{'dir'} .= " "; }
               $clarg{'dir'} .= $ARGS[ $counter ];
               $counter++;
            }
            $counter--;
            chomp( $clarg{'dir'} );
            $clarg{'dir'} =~ s/\n|\r//g;
            print("VM dir to copy: [$clarg{'dir'}]\n");
         } else {
            print("${colorBold}ERROR: The argument after --clone was not valid clone vm name or directory${colorNoBold}\n\n");
            onlinhelp();
            exit(100);
         }
      } elsif ( $ARGS[ $counter ] =~ m/^--debug$/ ) {
         $loglevel = 10000;
         print("Activate debug log level");
      } elsif ( $ARGS[ $counter ] =~ m/^--trace$/ ) {
         $loglevel = 5000;
         print("Activate trace log level");
      } elsif ( $ARGS[ $counter ] =~ /^--log$/ ) {
         $counter++;
         if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            $logfile = $ARGS[ $counter ];
            print("Logfile: $logfile\n");
         } else {
            print("${colorBold}ERROR: The argument after --log was not the log file!${colorNoBold}\n\n");
            onlinehelp();
            exit(3);
         }
      } else {
         print("${colorBold}Unknown option [$ARGS[$counter]] - abort${colorNoBold}\n\n");
         onlinehelp();
         exit(2);
      }
   }
   print("\n\n");
}

sub TimeStamp {
   my ($format) = $_[ 0 ];
   my ($return);
   ( my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst ) = localtime();
   $year = $year + 1900;
   $mon  = $mon + 1;
   if ( length($mon) == 1 )  { $mon    = "0$mon"; }
   if ( length($mday) == 1 ) { $mday   = "0$mday"; }
   if ( length($hour) == 1 ) { $hour   = "0$hour"; }
   if ( length($min) == 1 )  { $min    = "0$min"; }
   if ( length($sec) == 1 )  { $sec    = "0$sec"; }
   if ( $format == 1 )       { $return = "$year\-$mon\-$mday $hour\:$min\:$sec"; }
   if ( $format == 2 )       { $return = $mon . $mday . $year; }
   if ( $format == 3 ) { $return = substr( $year, 2, 2 ) . $mon . $mday; }
   if ( $format == 4 ) { $return = $mon . $mday . substr( $year, 2, 2 ); }
   if ( $format == 5 ) { $return = $year . $mon . $mday . $hour . $min . $sec; }
   if ( $format == 6 ) { $return = $year . $mon . $mday; }
   if ( $format == 7 ) { $return = $mday . '/' . $mon . '/' . $year . ' ' . $hour . ':' . $min . ':' . $sec; }
   if ( $format == 8 ) { $return = $year . $mon . $mday . $hour . $min; }
   if ( $format == 9 ) { $return = $mday . '/' . $mon . '/' . $year; }
   if ( $format == 10 ) { $return = "$hour\:$min\:$sec"; }
   return $return;
}

# pre main
# ----------------------------------------------------------------------------------------------------------------
use Log::Log4perl qw(:no_extra_logdie_message);
unless ( -e $conf_file ) {
   print "\n ${colorBold}ERROR: cannot find config file for logs $conf_file !${colorNoBold}\n\n";
   exit(101);
}
my $go = 4123123123213;
get_args();                                                                                                                        # analyse command line arguments
if ( $logfile eq "none" ) {
   $logfile = sprintf "%s../logs/%s", $dirs, $prgname;
}
sub log4p_logfile { return $logfile }

# my $maillog = $logfile . ".txt";                                                                                                   # .txt and .xml log file only for this session - .log for all over
# my $xmllog  = $logfile . ".xml";
# unlink $xmllog;
# unlink $maillog;
Log::Log4perl->init($conf_file);
my $logger = Log::Log4perl::get_logger();

# script functions
# ----------------------------------------------------------------------------------------------------------------
sub get_basevm {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $vm   = shift();
   my $base = $vm;
   $logger->trace("$ll  vm to clone: [$vm]");
   $logger->trace("$ll  cut clone name to base vm name ...");
   $base =~ s/-.*//;
   $logger->trace("$ll  base: $base");
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($base);
}

sub read_conf {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc  = 0;
   my $usevm = shift();
   my $conf;
   my %config;
   my $vms;
   my $gefunden = 0;
   my $setok    = 0;
   $logger->debug("$ll  read config file");
   $conf = new Config::General($clonematrix);
   $logger->debug("$ll  Get all clone configurations ...");
   %config = $conf->getall;

   # use Data::Dumper;
   # print Dumper(\%config);
   $logger->trace("$ll  ==> Base VM to clone: [$usevm]");
   foreach $vms ( keys %{ $config{'VM'} } ) {
      $logger->trace("$ll  ==> VM found in config: [$vms]");
      if ( $usevm eq $vms ) {
         $logger->info("$ll  vm config [$vms] found in clone matrix");
         my $copies;
         foreach $copies ( keys %{ $config{'VM'}{$vms}{'CP'} } ) {
            $logger->debug("$ll  Found copy job for $copies");
            if ( ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_type'} ) && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_type'} ) ) {
               $t_cp{$copies}{'type'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_type'};
               $s_cp{$copies}{'type'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_type'};
               $logger->debug("$ll   source type: $s_cp{$copies}{'type'}");
               if ( "$s_cp{$copies}{'type'}" eq "nfs" ) {
                  if ( ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_srv'} ) && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_exp'} ) ) {
                     $s_cp{$copies}{'srv'}    = $config{'VM'}{$vms}{'CP'}{$copies}{'s_srv'};
                     $s_cp{$copies}{'export'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_exp'};
                     if ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_loc'} ) {
                        $s_cp{$copies}{'locdir'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_loc'};
                     } else {
                        $s_cp{$copies}{'locdir'} = "/mnt/source_" . $PID . "_" . $copies;
                     }
                     $logger->debug("$ll    source srv: $s_cp{$copies}{'srv'}");
                     $logger->debug("$ll    source export: $s_cp{$copies}{'export'}");
                     $logger->debug("$ll    source loc mount: $s_cp{$copies}{'locdir'}");
                  } else {
                     $logger->error("one or more parameter for source type nfs missing in $copies - abort");
                     $retc = 33;
                     last;
                  }
               } elsif ( "$s_cp{$copies}{'type'}" eq "sftp" ) {
                  if (    ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_srv'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_dir'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_sftpusr'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_sftppwd'} ) ) {
                     $s_cp{$copies}{'srv'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_srv'};
                     $s_cp{$copies}{'dir'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_dir'};
                     $s_cp{$copies}{'usr'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_sftpusr'};
                     $s_cp{$copies}{'pwd'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_sftppwd'};
                     $logger->debug("$ll    source srv: $s_cp{$copies}{'srv'}");
                     $logger->debug("$ll    source dir: $s_cp{$copies}{'dir'}");
                     $logger->debug("$ll    source user: $s_cp{$copies}{'usr'}");
                     $logger->debug("$ll    source password: $s_cp{$copies}{'pwd'}");
                  } else {
                     $logger->error("one or more parameter for source sftp missing - abort");
                     $retc = 34;
                     last;
                  }
               } elsif ( "$s_cp{$copies}{'type'}" eq "scp" ) {
                  if (    ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_srv'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_dir'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_scpusr'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_scppwd'} ) ) {
                     $s_cp{$copies}{'srv'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_srv'};
                     $s_cp{$copies}{'dir'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_dir'};
                     $s_cp{$copies}{'usr'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_scpusr'};
                     $s_cp{$copies}{'pwd'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_scppwd'};
                     $logger->debug("$ll    source srv: $s_cp{$copies}{'srv'}");
                     $logger->debug("$ll    source dir: $s_cp{$copies}{'dir'}");
                     $logger->debug("$ll    source user: $s_cp{$copies}{'usr'}");
                     $logger->debug("$ll    source password: $s_cp{$copies}{'pwd'}");
                  } else {
                     $logger->error("one or more parameter for source scp missing - abort");
                     $retc = 34;
                     last;
                  }
               } elsif ( "$s_cp{$copies}{'type'}" eq "dir" ) {
                  if ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'s_dir'} ) {
                     $s_cp{$copies}{'dir'} = $config{'VM'}{$vms}{'CP'}{$copies}{'s_dir'};
                     $logger->debug("$ll    source dir: $s_cp{$copies}{'dir'}");
                  } else {
                     $logger->error("dir for type dir missing - abort");
                     $retc = 35;
                     last;
                  }
               } else {
                  $logger->error("unknown source type - abort");
                  $retc = 23;
                  last;
               }
               $logger->debug("$ll   target type: $t_cp{$copies}{'type'}");
               if ( "$t_cp{$copies}{'type'}" eq "nfs" ) {
                  if ( ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_srv'} ) && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_exp'} ) ) {
                     $t_cp{$copies}{'srv'}    = $config{'VM'}{$vms}{'CP'}{$copies}{'t_srv'};
                     $t_cp{$copies}{'export'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_exp'};
                     if ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_loc'} ) {
                        $t_cp{$copies}{'locdir'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_loc'};
                     } else {
                        $t_cp{$copies}{'locdir'} = "/mnt/target_" . $PID . "_" . $copies;
                     }
                     $logger->debug("$ll    target srv: $t_cp{$copies}{'srv'}");
                     $logger->debug("$ll    target export: $t_cp{$copies}{'export'}");
                     $logger->debug("$ll    target loc mount: $t_cp{$copies}{'locdir'}");
                  } else {
                     $logger->error("one or more parameter for target type nfs missing in $copies - abort");
                     $retc = 33;
                     last;
                  }
               } elsif ( "$t_cp{$copies}{'type'}" eq "sftp" ) {
                  if (    ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_srv'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_dir'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_sftpusr'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_sftppwd'} ) ) {
                     $t_cp{$copies}{'srv'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_srv'};
                     $t_cp{$copies}{'dir'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_dir'};
                     $t_cp{$copies}{'usr'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_sftpusr'};
                     $t_cp{$copies}{'pwd'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_sftppwd'};
                     $logger->debug("$ll    target srv: $t_cp{$copies}{'srv'}");
                     $logger->debug("$ll    target dir: $t_cp{$copies}{'dir'}");
                     $logger->debug("$ll    target user: $t_cp{$copies}{'usr'}");
                     $logger->debug("$ll    target password: $t_cp{$copies}{'pwd'}");
                  } else {
                     $logger->error("one or more parameter for target sftp missing - abort");
                     $retc = 34;
                     last;
                  }
               } elsif ( "$t_cp{$copies}{'type'}" eq "scp" ) {
                  if (    ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_srv'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_dir'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_scpusr'} )
                       && ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_scppwd'} ) ) {
                     $t_cp{$copies}{'srv'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_srv'};
                     $t_cp{$copies}{'dir'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_dir'};
                     $t_cp{$copies}{'usr'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_scpusr'};
                     $t_cp{$copies}{'pwd'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_scppwd'};
                     $logger->debug("$ll    target srv: $t_cp{$copies}{'srv'}");
                     $logger->debug("$ll    target dir: $t_cp{$copies}{'dir'}");
                     $logger->debug("$ll    target user: $t_cp{$copies}{'usr'}");
                     $logger->debug("$ll    target password: $t_cp{$copies}{'pwd'}");
                  } else {
                     $logger->error("one or more parameter for target scp missing - abort");
                     $retc = 34;
                     last;
                  }
               } elsif ( "$t_cp{$copies}{'type'}" eq "dir" ) {
                  if ( defined $config{'VM'}{$vms}{'CP'}{$copies}{'t_dir'} ) {
                     $t_cp{$copies}{'dir'} = $config{'VM'}{$vms}{'CP'}{$copies}{'t_dir'};
                     $logger->debug("$ll    target dir: $t_cp{$copies}{'dir'}");
                  } else {
                     $logger->error("dir for type dir missing - abort");
                     $retc = 35;
                     last;
                  }
               } else {
                  $logger->error("unknown target type - abort");
                  $retc = 24;
                  last;
               }
            } else {
               $logger->error("source or target type missing - abort");
               $retc = 22;
               last;
            }
         }
         unless ($retc) { $gefunden = 1; }
      }
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub create_path {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my $path = shift();
   unless ( -d $path ) {
      $logger->debug("$ll  path [$path] does not exist - create");
      eval { mkpath($path) };
      if ($@) {
         $logger->error("problem creating $path");
         $retc = 99;
      } else {
         $logger->debug("$ll  path created sucessful");
      }
   } else {
      $logger->debug("$ll  path already created");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub delete_path {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll   = " " x $flvl;
   my $retc = 0;
   $logger->trace("$ll func start: [$fc]");
   my $path = shift();
   if ( -d $path ) {
      $logger->debug("$ll  path [$path] exist - delete");
      eval { rmtree($path) };
      my $rc = @$;
      $logger->trace("$ll  rc=[$rc]");
      if ($rc) {
         $logger->error("problem deleting $path");
         $retc = 98;
      } else {
         $logger->debug("$ll  path deleted sucessful");
      }
   } else {
      $logger->debug("$ll  path does not exist");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub src_mount_nfs {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $job  = shift();
   $logger->trace("$ll  cmd: [$job]");
   $logger->debug("$ll  source dir is nfs mount");
   $s_cp{$job}{'sourcedir'} = $s_cp{$job}{'locdir'};
   $logger->debug("$ll  mount nfs export to local dir [$s_cp{$job}{'sourcedir'}]");
   $logger->debug("$ll  create local temp mount dir ...");
   $retc = create_path( $s_cp{$job}{'sourcedir'} );
   my $command = "mount -t nfs $s_cp{$job}{'srv'}:" . "$s_cp{$job}{'export'} $s_cp{$job}{'sourcedir'}";
   $logger->trace("$ll  cmd: $command");
   my $eo = `$command`;
   $retc = $?;
   $retc = $retc >> 8 unless ( $retc == -1 );

   unless ($retc) {
      $logger->trace("$ll  ok");
   } else {
      $logger->error("$ll cannot mount [$eo]");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub src_2tmpdir {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $job  = shift();
   $logger->trace("$ll  cmd: [$job]");
   $logger->debug("$ll  source dir is $s_cp{$job}{type}");
   $s_cp{$job}{'sourcedir'} = "/mnt/source_" . $PID . "_" . $job;
   $logger->debug("$ll  first copy all files to local temp dir [$s_cp{$job}{'sourcedir'}]");
   $logger->debug("$ll  create local dir");
   $retc = create_path( $s_cp{$job}{'sourcedir'} );
   $logger->debug("$ll  copy files");

   if ( "$s_cp{$job}{type}" eq "sftp" ) {
      $logger->trace("$ll   ==> sftp copy");
   } elsif ( "$s_cp{$job}{type}" eq "scp" ) {
      $logger->trace("$ll   ==> scp copy");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub src_locdir {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $job  = shift();
   $logger->trace("$ll  cmd: [$job]");
   $logger->info("$ll  source is local dir - nothing to do");
   $s_cp{$job}{'sourcedir'} = $s_cp{$job}{'dir'};
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub trgt_nfs {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $job  = shift();
   $logger->trace("$ll  cmd: [$job]");
   $logger->debug("$ll  target is nfs mount");
   $logger->debug("$ll  mount target nfs mount to local dir");
   $t_cp{$job}{'targetdir'} = "/mnt/target_" . $PID . "_" . $job;
   $logger->debug("$ll  create local temp mount dir ...");
   $retc = create_path( $t_cp{$job}{'targetdir'} );
   my $command = "mount -t nfs $t_cp{$job}{'srv'}:" . "$t_cp{$job}{'export'} $t_cp{$job}{'targetdir'}";
   $logger->trace("$ll  cmd: $command");
   my $eo = `$command`;
   $retc = $?;
   $retc = $retc >> 8 unless ( $retc == -1 );

   unless ($retc) {
      $logger->trace("$ll  ok");
   } else {
      $logger->error("$ll cannot mount [$eo]");
   }
   my $source;
   my $target;
   unless ($retc) {
      $source = $s_cp{$job}{'sourcedir'} . "/" . $clarg{'dir'};
      $logger->trace("$ll   source: $source");
      $target = $t_cp{$job}{'targetdir'} . "/" . $clarg{'dir'};
      $logger->trace("$ll   target: $target");
      unless ( -d $source ) {
         $logger->error("source dir does not exist - abort");
         $retc = 66;
      }
   }
   unless ($retc) {
      $logger->debug("$ll  start copy files");
      $logger->trace("$ll   source=[$source]");
      $logger->trace("$ll   target=[$target]");
      my ( $num_of_files_and_dirs, $num_of_dirs, $depth_traversed ) = dircopy( $source, $target );
      unless ($num_of_files_and_dirs) {
         $logger->error("error during copy source to target");
         $retc = 44;
      } else {
         $logger->info("$ll   data copy: $num_of_files_and_dirs");
      }
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub trgt_sftp {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $job  = shift();
   $logger->trace("$ll  cmd: [$job]");
   $logger->debug("$ll  target is sftp ...");
   $Net::SFTP::Foreign::debug = 0;
   my $host = $t_cp{$job}{'srv'};
   $logger->trace("$ll   server: $host");
   my $user = $t_cp{$job}{'usr'};
   $logger->trace("$ll   user: $user");
   my $rdir = $t_cp{$job}{'dir'} . "/" . $clarg{'dir'};
   $logger->trace("$ll   target: $rdir");
   my $ldir = $s_cp{$job}{'sourcedir'} . "/" . $clarg{'dir'};
   $logger->trace("$ll   source: $ldir");
   my $cpwd = $t_cp{$job}{'pwd'};
   my $pwd;
   $logger->trace("$ll   pwd: $cpwd");
   srand($go);
   $pwd .= chr( ord($_) ^ int( rand(10) ) ) for ( split( '', $cpwd ) );
   $logger->debug("$ll  connect to server ...");
   my $sftp;
   my %args = (

      # backend  => 'Net_SSH2',
      user     => $user,
      password => $pwd
      );
   $logger->debug("$ll  connecto to $host");
   $sftp = Net::SFTP::Foreign->new( $host, %args );
   my $rc = $?;
   if ($rc) {
      $logger->debug("$ll  ok");
   } else {
      $logger->error("cannot connect to host $host");
      $logger->trace("$ll   rc=$rc");
      $logger->trace("$ll   out:$!");
      $retc = 99;
   }
   unless ($retc) {
      my $ls = $sftp->ls($rdir);
      my $rc = $?;
      $logger->trace( "$ll  rc=[" . $sftp->error . "]" );
      unless ($rc) {
         $logger->debug("$ll  dir exist - override");
      } else {
         $logger->debug("$ll  dir does not exist - create");
         $sftp->mkpath($rdir);
         my $rc = $?;
         $logger->trace( "$ll  rc=[" . $sftp->error . "]" );
         if ($rc) {
            $logger->debug("$ll  dir created ok");
         } else {
            $logger->error("cannot create dir $rdir");
            $retc = 99;
         }
      }
   }
   unless ($retc) {
      $logger->debug("$ll   open local directory ...");
      $logger->trace("$ll   ldir: $ldir");
      if ( opendir( DIR, $ldir ) ) {
         $logger->debug("$ll   ok");
      } else {
         $logger->error("cannot open local dir [$ldir] - [$!]");
         $retc = 999;
      }
   }
   unless ($retc) {
      $logger->debug("$ll   read dir ...");
      while ( my $file = readdir(DIR) ) {
         $logger->trace("$ll   file: $file");
         next if ( $file =~ m/^\./ );
         $logger->trace("$ll   source: $ldir");
         $logger->trace("$ll   target: $rdir");
         $logger->info("$ll   start copy $file");
         $sftp->put( "$ldir/$file", "$rdir/$file" );
         $retc = $sftp->error;
         $logger->trace("$ll   retc: $retc");
         $logger->trace( "$ll   status: [" . $sftp->status() . "]" );

         if ($retc) {
            $logger->error("$ll   cannot copy file $ldir/$file - rc=$retc");
            last;
         } else {
            $logger->info("$ll   file $ldir/$file transfered");
         }
      }
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub ssh_dir_exist {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $host = shift();
   my $user = shift();
   my $pwd  = shift();
   my $rdir = shift();
   $logger->debug("$ll   test if dir [$rdir] exist");
   my ( $stdout, $stderr, $exit );
   my %sshparam = (
      protocol => '2,1',
      ciphers  => 'RC4',
      port     => 22,

      #   debug => 1,
      #   interactive => 1,
      );
   $logger->trace("$ll   create new login object");
   my $ssh = Net::SSH::Perl->new( $host, %sshparam );
   my $rc = $?;
   unless ($rc) {
      $logger->debug("$ll  ok");
   } else {
      $logger->error("cannot create ssh object");
      $logger->trace("$ll   rc=$rc");
      $logger->trace("$ll   out:$!");
      $retc = 99;
   }
   unless ($retc) {
      $logger->debug("$ll   Login to server [$host]");
      $ssh->login( $user, $pwd );
      $logger->info("$ll   test if dir exist");
      my $cmd = "ls -l $rdir";
      $logger->trace("$ll   Command: $cmd");
      ( $stdout, $stderr, $exit ) = $ssh->cmd($cmd);
      if ( defined $stdout ) { $logger->trace("$ll   stdout: $stdout"); }
      if ( defined $stderr ) { $logger->trace("$ll   stderr: $stderr"); }
      if ( defined $exit )   { $logger->trace("$ll   exit: $exit"); }

      if ( $exit == 0 ) {
         $logger->debug("$ll   dir exist - override all");
      } else {
         $logger->debug("$ll   dir does not exist - create");
         $logger->info("$ll   Create new dir [$rdir]");
         my $cmd = "mkdir $rdir";
         $logger->trace("$ll   Command: $cmd");
         ( $stdout, $stderr, $exit ) = $ssh->cmd($cmd);
         if ( defined $stdout ) { $logger->trace("$ll   stdout: $stdout"); }
         if ( defined $stderr ) { $logger->trace("$ll   stderr: $stderr"); }
         if ( defined $exit )   { $logger->trace("$ll   exit: $exit"); }

         if ( $exit == 0 ) {
            $logger->debug("$ll   creating ok");
         } else {
            $logger->error("$ll   cannot create dir rc=$exit");
            $retc = $exit;
         }
      }
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub trgt_scp {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $job  = shift();

#   use Data::Dumper;
#   print Dumper(\%t_cp);
#   print Dumper(\%s_cp);
   $logger->trace("$ll  cmd: [$job]");
   $logger->debug("$ll  target is scp ...");

   sub scp_errors {
      use strict;
      my $line = shift;
      $line =~ s/\012//g;
      $line =~ s/\015//g;
      $logger->error($line);
      return (1);
   }
   my $host = $t_cp{$job}{'srv'};
   $logger->trace("$ll   server: $host");
   my $user = $t_cp{$job}{'usr'};
   $logger->trace("$ll   user: $user");
   my $rdir = $t_cp{$job}{'dir'} . "/" . $clarg{'dir'};
   $logger->trace("$ll   target: $rdir");
   my $ldir = $s_cp{$job}{'sourcedir'} . "/" . $clarg{'dir'};
   $logger->trace("$ll   source: $ldir");
   my $cpwd = $t_cp{$job}{'pwd'};
   my $pwd;
   $logger->trace("$ll   pwd: $cpwd");
   srand($go);
   $pwd .= chr( ord($_) ^ int( rand(10) ) ) for ( split( '', $cpwd ) );
   $logger->debug("$ll   connect to server ...");
   my $scp;
   $scp = Net::SCP::Expect->new( host => $host, user => $user, password => $pwd, recursive => 1, error_handler => \&scp_errors );
   $retc = $?;
   $logger->trace("$ll   rc=$retc");

   unless ($retc) {
      $retc = ssh_dir_exist( $host, $user, $pwd, $rdir );
   }
   unless ($retc) {
      $logger->debug("$ll   open local directory ...");
      $logger->trace("$ll   ldir: $ldir");
      if ( opendir( DIR, $ldir ) ) {
         $logger->debug("$ll   ok");
      } else {
         $logger->error("cannot open local dir [$ldir] - [$!]");
         $retc = 999;
      }
   }
   unless ($retc) {
      $logger->debug("$ll   read dir ...");
      while ( my $file = readdir(DIR) ) {
         $logger->trace("$ll   file: $file");
         next if ( $file =~ m/^\./ );
         $logger->trace("$ll   source: $ldir");
         $logger->trace("$ll   target: $rdir");
         $logger->info("$ll   start copy $file");
         $scp->scp( "$ldir/$file", "$rdir" );
         $retc = $?;
         if ($retc) {
            $logger->error("$ll   cannot copy file $ldir/$file - rc=$retc");
            last;
         } else {
            $logger->info("$ll   file $ldir/$file transfered");
         }
      }
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub trgt_dir {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $job  = shift();
   $logger->trace("$ll  cmd: [$job]");
   $logger->debug("$ll  target is local dir - start copy");

   unless ( -d $t_cp{$job}{'t_dir'} ) {
      $logger->error("target dir does not exist - abort");
      $retc = 66;
   }
   my $source;
   my $target;
   unless ($retc) {
      $source = $s_cp{$job}{'sourcedir'} . "/" . $clarg{'dir'};
      $logger->trace("$ll   source: $source");
      $target = $t_cp{$job}{'t_dir'} . "/" . $clarg{'dir'};
      $logger->trace("$ll   target: $target");
      unless ($retc) {
         unless ( -d $source ) {
            $logger->error("source dir does not exist - abort");
            $retc = 66;
         }
      }
   }
   unless ($retc) {
      $logger->debug("$ll  start copy files");
      my ( $num_of_files_and_dirs, $num_of_dirs, $depth_traversed ) = dircopy( $source, $target );
      unless ($num_of_files_and_dirs) {
         $logger->error("error during copy source to target");
         $retc = 44;
      } else {
         $logger->info("$ll   data copy: $num_of_files_and_dirs");
      }
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub warten {
   my $leer = shift;
   my $ll   = " " x $leer;
   print TimeStamp('10') . " : INFO $ll Waiting .";
   my $waitend  = 10;
   my $waittime = 1;
   my $i        = 1;
   while ( $i < $waitend ) {
      print ".";
      sleep $waittime;
      $i++;
   }
   print " ok\n";
   $| = 0;
}

sub checkunmountnfs {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $mp   = shift();
   $logger->trace("$ll  mount point: [$mp]");
   $logger->debug("$ll  a second test - attention only :)");
   my $mount_result = `/bin/mount | /bin/grep $mp`;

   if ( $mount_result ne "" ) {
      $logger->error("path $mp is still mounted - abort");
      $retc = 99;
   } else {
      $logger->debug("$ll  all okay - you can delete now");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub unmountnfs {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $mp   = shift();
   $logger->debug("$ll   unmount mount point: $mp");
   my $cmd = "umount -l $mp";
   $logger->trace("$ll   cmd: $cmd");
   my $eo = `2>&1 $cmd`;
   $retc = $?;
   $retc = $retc >> 8 unless ( $retc == -1 );
   $logger->trace("$ll   [$eo]");

   unless ($retc) {
      $logger->trace("$ll   ok");
   } else {
      $logger->error("cannot umount [$eo]");
   }

   # print "\nPress ENTER ...";
   # my $enter = <STDIN>;
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub end_tmpnfs {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $mp   = shift();
   my $sp   = shift();
   $logger->trace("$ll  source point: [$sp]");
   $logger->trace("$ll  mount point: [$mp]");
   warten(4);
   $retc = unmountnfs($mp);

   unless ($retc) {
      $retc = checkunmountnfs($mp);
   }
   unless ($retc) {
      $logger->debug("$ll  remove nfs temp dir ");
      $retc = delete_path($mp);
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub end_tmpdir {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc = 0;
   my $job  = shift();
   $logger->trace("$ll  cmd: [$job]");
   $logger->debug("$ll  remove local temp dir and files");
   $retc = delete_path( $s_cp{$job}{'sourcedir'} );
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

sub newsub {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc    = 0;
   my $command = shift();
   $logger->trace("$ll cmd: [$command]");
   my $eo = qx($command  2>&1);
   $retc = $?;
   $retc = $retc >> 8 unless ( $retc == -1 );

   unless ($retc) {
      $logger->trace("$ll ok");
   } else {
      $logger->error("$ll ERROR [$eo]");
   }
   $logger->trace("$ll func end: [$fc] rc: [$retc]");
   $flvl--;
   return ($retc);
}

# main
# ----------------------------------------------------------------------------------------------------------------
$logger->info("Starting $prg - version $ver");
$logger->info(" vm to clone: $clarg{'dir'} ");
my $basevm = get_basevm( $clarg{'dir'} );
if ( "$basevm" eq "$clarg{'dir'}" ) {
   $logger->warn(" clone input same as base vm - no clone!");
} else {
   $logger->info(" base vm: $basevm");
}
$retc = read_conf($basevm);
unless ($retc) {
   my $job;
   $logger->debug(" List all jobs ..");
   foreach $job ( keys %{t_cp} ) {
      $logger->info(" ===>  job name: $job");
      if ( "$s_cp{$job}{'type'}" eq "nfs" ) {
         $logger->trace("  ==> source is nfs");
         $retc = src_mount_nfs($job);
      } elsif ( "$s_cp{$job}{'type'}" eq "sftp" ) {
         $logger->trace("  ==> source is sftp");
         $retc = src_2tmpdir($job);
      } elsif ( "$s_cp{$job}{'type'}" eq "scp" ) {
         $logger->trace("  ==> source is scp");
         $retc = src_2tmpdir($job);
      } elsif ( "$s_cp{$job}{'type'}" eq "dir" ) {
         $logger->trace("  ==> source is dir");
         $retc = src_locdir($job);
      }
      unless ($retc) {
         $logger->debug(" ===> copy from source dir: $s_cp{$job}{'sourcedir'}");
         if ( "$t_cp{$job}{'type'}" eq "nfs" ) {
            $logger->trace("  ==> target is nfs");
            $retc = trgt_nfs($job);
         } elsif ( "$t_cp{$job}{'type'}" eq "sftp" ) {
            $logger->trace("  ==> target is sftp");
            $retc = trgt_sftp($job);
         } elsif ( "$t_cp{$job}{'type'}" eq "scp" ) {
            $logger->trace("  ==> target is scp");
            $retc = trgt_scp($job);
         } elsif ( "$t_cp{$job}{'type'}" eq "dir" ) {
            $logger->trace("  ==> target is dir");
            $retc = trgt_dir($job);
         }
      }
      unless ($retc) {
         $logger->debug(" ===> clean up source ...");
         if ( "$s_cp{$job}{'type'}" eq "nfs" ) {
            $logger->trace("  ==> unmount nfs share");
            $retc = end_tmpnfs( $s_cp{$job}{'sourcedir'}, $s_cp{$job}{'srv'} . ":" . $s_cp{$job}{'export'} );
         } elsif ( "$s_cp{$job}{'type'}" eq "sftp" ) {
            $logger->trace("  ==> delete temp sftp dir");
            $retc = end_tmpdir($job);
         } elsif ( "$s_cp{$job}{'type'}" eq "sftp" ) {
            $logger->trace("  ==> delete temp scp dir");
            $retc = end_tmpdir($job);
         } elsif ( "$s_cp{$job}{'type'}" eq "dir" ) {
            $logger->trace("  ==> source is local dir - do nothing");
         }
      }
      unless ($retc) {
         $logger->debug(" ===> clean up target ...");
         if ( "$t_cp{$job}{'type'}" eq "nfs" ) {
            $logger->trace("  ==> unmount nfs share");
            $retc = end_tmpnfs( $t_cp{$job}{'targetdir'}, $t_cp{$job}{'srv'} . ":" . $t_cp{$job}{'export'} );
         } elsif ( "$t_cp{$job}{'type'}" eq "sftp" ) {
            $logger->trace("  ==> target dir is sftp - delete tmp dir");
            $retc = end_tmpdir($job);
         } elsif ( "$t_cp{$job}{'type'}" eq "scp" ) {
            $logger->trace("  ==> target dir is scp - delete tmp dir");
            $retc = end_tmpdir($job);
         } elsif ( "$t_cp{$job}{'type'}" eq "dir" ) {
            $logger->trace("  ==> target is local dir - do nothing");
         }
      }
      if ($retc) {
         last;
      }
   }
}

#use Data::Dumper;
#print Dumper(\%t_cp);
#print Dumper(\%s_cp);
$logger->info("End $prg - rc=$retc");
