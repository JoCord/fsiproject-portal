#!/usr/bin/perl -w
#
#   clone.pl - start clone procedure with config vars
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
our $ver = '1.35.06 - 10.1.2017';
my $retc = 0;
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Config::General;
use English;
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
use Timer::Simple();
my $timerlog = Timer::Simple->new( start => 0, string => 'human' );
my ( $tvmoff, $tvmclone, $tvmclean );
use File::Spec;
use File::Basename;
my $rel_path = File::Spec->rel2abs(__FILE__);
my ( $volume, $dirs, $prg ) = File::Spec->splitpath($rel_path);
our $prgname = basename( $prg, '.pl' );

require "$Bin/../lib/func.pl";                                                                                                     # some general functions
require "$Bin/clone_help.pl";

if ( $#ARGV eq '-1' ) { help(); }


use Log::Log4perl qw(:no_extra_logdie_message);
my $conf_file = $dirs . '../etc/log4p_vmc';

unless ( -e $conf_file ) {
   print "\n ERROR: cannot find config file for logs $conf_file !\n\n";
   exit(101);
}
my @ARGS             = @ARGV;                                                                                                      ## This is so later we can re-parse the command line args later if we need to
my $numargv          = @ARGS;
my $counter          = 0;
my $override_storage = "no";
my $usevm            = "no";
my $optvm            = "no";
my $useoptvm         = "no";
my $loglevel         = 0;
my $logfile          = "no";
my $clonematrix      = "../etc/clonematrix";
my $optvmname        = "none";
my $vmname           = "none";
my $clone_name       = "none";
my $vc               = "none";
my $thost            = "none";
my $trespool         = "none";
my $tstore           = "none";
my $user             = "none";
my $cpass            = "none";
my $rebootonly       = "no";
my $pass;
my $gefunden = 0;
my $vms;
my $vmshut   = 0;
my $tfolder  = "none";
my $tpg1     = "none";
my $tpg2     = "none";
my $mailwait = 0;
my $gens     = 1;
my $config;
my $ext_cmd  = "none";
my $ext_parm = "none";
my @ext_parm;
my $sendemail = 1;
my $bootparm  = "";
my $boot      = 0;
my $chkon     = 0;
my $ignore    = 0;

for ( $counter = 0 ; $counter < $numargv ; $counter++ ) {
   print("\nArgument: $ARGS[$counter]\n");
   if ( $ARGS[ $counter ] =~ /^-h$/i ) {
      help();
   } elsif ( $ARGS[ $counter ] eq "" ) {
      ## Do nothing
   } elsif ( $ARGS[ $counter ] =~ /^--help/ ) {
      help();
   } elsif ( $ARGS[ $counter ] =~ /^--chkon$/ ) {
      $counter++;
      $bootparm = "";
      $chkon    = 1;
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($bootparm) { $bootparm .= " "; }
            $bootparm .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($bootparm);
         $bootparm =~ s/\n|\r//g;
         print("Found boot parameter [$bootparm]\n");
      } else {
         print("Do not boot vm if offline\n");
         $counter--;
      }
   } elsif ( $ARGS[ $counter ] =~ /^--storage$/ ) {
      print("Storage override found\n");
      $counter++;
      $override_storage = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($override_storage) { $override_storage .= " "; }
            $override_storage .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($override_storage);
         $override_storage =~ s/\n|\r//g;
         print("Found storage override [$override_storage]\n");
      } else {
         print("The argument after --storage was not valid storage name\n");
         print("Take configure storage instead\n");
         $counter--;
      }
   } elsif ( $ARGS[ $counter ] =~ /^--optvm$/ ) {
      $counter++;
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         $optvm = $ARGS[ $counter ];
         chomp($optvm);
         $optvm =~ s/\n|\r//g;
         print("Optional VM found: $optvm");
      } else {
         print("The argument after --optvm was not correct - ignore!\n");
         $counter--;
      }
   } elsif ( $ARGS[ $counter ] =~ m/^--reboot$/ ) {
      $rebootonly = "yes";
   } elsif ( $ARGS[ $counter ] =~ m/^--ignore$/ ) {
      $ignore = 1;
   } elsif ( $ARGS[ $counter ] =~ m/^--noemail$/ ) {
      $sendemail = 0;
   } elsif ( $ARGS[ $counter ] =~ m/^--debug$/ ) {
      $loglevel = 10000;
      print("Activate debug log level");
   } elsif ( $ARGS[ $counter ] =~ m/^--trace$/ ) {
      $loglevel = 5000;
      print("Activate trace log level");
   } elsif ( $ARGS[ $counter ] =~ /^--vm$/ ) {
      $counter++;
      $usevm = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ($usevm) { $usevm .= " "; }
            $usevm .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp($usevm);
         $usevm =~ s/\n|\r//g;
         print("VM Name: [$usevm]\n");
      } else {
         print("ERROR: The argument after --vm was not valid storage name\n\n");
         help();
      }
   } else {
      print("Unknown option [$ARGS[$counter]]- ignore");
   }
} ## end for ( $counter = 0 ; $counter < $numargv ; $counter++ )
print("\n\n");
if ( $usevm eq "no" ) {
   print("\n\nERROR: no vmname given - abort\n\n");
   help();
}
if ( $logfile eq "no" ) {
   if ( $usevm ne "no" ) {
      $logfile = sprintf "%s../logs/%s-%s", $dirs, $prgname, $usevm;
   } else {
      $logfile = sprintf "%s../logs/%s", $dirs, $prgname;
   }
} else {
   print("Logfile from comman line: $logfile");
}
sub log4p_logfile { return $logfile }
my $flagfile = $dirs . '../tmp/' . $prgname . '-' . $usevm . '.pid';
unless ($ignore) {
   if ( -e $flagfile ) {
      print "\nERROR: $flagfile exist - script still running!\n\n";
      exit(100);
   } else {
      open( PIDFILE, ">>$flagfile" );
      select PIDFILE;
      $| = 1;
      select STDOUT;
      print PIDFILE localtime() . "\n" . $usevm;
   } ## end else [ if ( -e $flagfile ) ]
} ## end unless ($ignore)
my $maillog = $logfile . ".txt";
# my $xmllog  = $logfile . ".xml";

# unlink $xmllog;
unlink $maillog;
Log::Log4perl->init($conf_file);
my $logger = Log::Log4perl::get_logger();
$logger->info("Starting $prg - version $ver");


sub del_file {
   my ($delfile) = @_;
   if ( -e $delfile ) {
      $logger->debug("file [$delfile] exist - try to delete");
      if ( unlink $delfile ) {
         $logger->debug("file deleted");
      } else {
         $logger->debug("Cannot delete file");
      }
   } else {
      $logger->debug("file does not exist");
   }
} ## end sub del_file

sub date_time {
   my $variante = $_[ 0 ];
   unless ( defined $variante ) {
      $variante = "n";
   }
   my $datetime = "";
   my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime();
   $year += 1900;
   $mon  += 1;
   $mon  = $mon < 10  ? $mon  = "0" . $mon  : $mon;
   $hour = $hour < 10 ? $hour = "0" . $hour : $hour;
   $mday = $mday < 10 ? $mday = "0" . $mday : $mday;
   $min  = $min < 10  ? $min  = "0" . $min  : $min;
   $sec  = $sec < 10  ? $sec  = "0" . $sec  : $sec;

   if ( $variante eq "s" ) {
      $datetime = "$year$mon$mday$hour$min";
   } else {
      $datetime = "$year.$mon.$mday-$hour:$min:$sec";
   }
   return ($datetime);
} ## end sub date_time

sub del_flagfile {
   my ($flagfile) = @_;
   if ( -e $flagfile ) {
      $logger->debug("Close PID file");
      close PIDFILE;
      $logger->info("Delete PID file");
      if ( unlink $flagfile ) {
         $logger->debug("PID file deleted");
      } else {
         $logger->error("Cannot delete PID file");
         $retc = 95;
      }
   } else {
      $logger->warn("No logfile exist");
   }
} ## end sub del_flagfile
if ( $loglevel != 0 ) {
   $logger->level($loglevel);
   $logger->debug("Activate new log level: [$loglevel]");
}
$logger->info( "Log Level: " . $logger->level() );
if ( $rebootonly eq "no" ) {
   $logger->info("VM to clone and clean: [$usevm]");
} else {
   $logger->info("VM to reboot: [$usevm]");
}
$logger->debug("PID File: [$flagfile]");
if ( $override_storage ne "no" ) { $logger->info("Storage override: [$override_storage]"); }
if ( $optvm ne "no" ) {
   $logger->info("VM option flag: [$optvm]");
   $useoptvm = $usevm . $optvm;
   $logger->info("VM to clone and clean override: [$useoptvm]");
}
my $go = 4123123123213;
$logger->debug("Test if clonematrix exist");
if ( -e "$dirs$clonematrix" ) {
   $logger->debug("Clonematrix config file found");
} else {
   $logger->error("Cannot find clonematrix config file $dirs$clonematrix");
   del_flagfile($flagfile);
   exit(40);
}
my $conf = new Config::General("$dirs../etc/clonematrix");
$logger->debug("Get all clone configurations ...");
my %config = $conf->getall;
$logger->info("Check if VM is known");
if ( $bootparm eq "boot" ) {
   $logger->debug("  reboot vm if offline set");
   $boot = 1;
}

# use Data::Dumper;
# print Dumper(\%config);
foreach $vms ( keys %{ $config{'VM'} } ) {
   $logger->trace("==> VM found in config: [$vms]");
   $logger->trace("==> VM from command line: [$usevm]");
   if ( ( $usevm eq $vms ) || ( $useoptvm eq $vms ) ) {
      $logger->info("vm [$vms] found in clone matrix");
      if ( defined $config{'VM'}{$vms}{'vc'} ) {
         if ( "$vc" eq "none" ) {
            $vc = $config{'VM'}{$vms}{'vc'};
            $logger->debug("vm setting virtual center = $vc");
         } else {
            if ( $useoptvm eq $vms ) {
               $logger->debug("vm opt setting override normal vm setting");
               $vc = $config{'VM'}{$vms}{'vc'};
               $logger->debug("vm setting virtual center = $vc");
            } else {
               $logger->debug("vc already set to $vc");
            }
         } ## end else [ if ( "$vc" eq "none" ) ]
      } else {
         $logger->error("no vitual center found in vm config");
         $retc = 1;
      }
      if ( defined $config{'VM'}{$vms}{'pwd'} ) {
         if ( "$cpass" eq "none" ) {
            $cpass = $config{'VM'}{$vms}{'pwd'};
            $logger->debug("vm setting password found = ********");
         } else {
            if ( $useoptvm eq $vms ) {
               $logger->debug("vm opt setting override normal vm setting");
               $cpass = $config{'VM'}{$vms}{'pwd'};
               $logger->debug("vm setting password found = ********");
            } else {
               $logger->debug("password already set");
            }
         } ## end else [ if ( "$cpass" eq "none" ) ]
      } else {
         $logger->error("no access password set in vm config");
         $retc = 1;
      }
      if ( defined $config{'VM'}{$vms}{'usr'} ) {
         if ( "$user" eq "none" ) {
            $user = $config{'VM'}{$vms}{'usr'};
            $logger->debug("vm setting login user = $user");
         } else {
            if ( $useoptvm eq $vms ) {
               $logger->debug("vm opt setting override normal vm setting");
               $user = $config{'VM'}{$vms}{'usr'};
               $logger->debug("vm setting login user = $user");
            } else {
               $logger->debug("user already set");
            }
         } ## end else [ if ( "$user" eq "none" ) ]
      } else {
         $logger->error("no access user set in vm config");
         $retc = 1;
      }
      if ( defined $config{'VM'}{$vms}{'th'} ) {
         if ( "$thost" eq "none" ) {
            $thost = $config{'VM'}{$vms}{'th'};
            $logger->debug("vm setting target host = $thost");
         } else {
            if ( $useoptvm eq $vms ) {
               $logger->debug("vm opt setting override normal vm setting");
               $thost = $config{'VM'}{$vms}{'th'};
               $logger->debug("vm setting target host = $thost");
            } else {
               $logger->debug("vm target host already set to $thost");
            }
         } ## end else [ if ( "$thost" eq "none" ) ]
      } else {
         $logger->error("no target host set in vm config");
         $retc = 1;
      }
      if ( defined $config{'VM'}{$vms}{'tr'} ) {
         if ( "$trespool" eq "none" ) {
            $trespool = $config{'VM'}{$vms}{'tr'};
            $logger->debug("vm setting target resource pool = $trespool");
         } else {
            if ( $useoptvm eq $vms ) {
               $logger->debug("vm opt setting override normal vm setting");
               $trespool = $config{'VM'}{$vms}{'th'};
               $logger->debug("vm setting target resource pool = $trespool");
            } else {
               $logger->debug("vm target host already set to $trespool");
            }
         } ## end else [ if ( "$trespool" eq "none" ) ]
      }
      if ( $override_storage eq "no" ) {
         $logger->debug("no storage override - read config");
         if ( defined $config{'VM'}{$vms}{'ts'} ) {
            if ( "$tstore" eq "none" ) {
               $tstore = $config{'VM'}{$vms}{'ts'};
               $logger->debug("vm setting target store = $tstore");
            } else {
               if ( $useoptvm eq $vms ) {
                  $logger->debug("vm opt setting override normal vm setting");
                  $tstore = $config{'VM'}{$vms}{'ts'};
                  $logger->debug("vm setting target store = $tstore");
               } else {
                  $logger->debug("vm target store already set to $tstore");
               }
            } ## end else [ if ( "$tstore" eq "none" ) ]
         } else {
            $logger->error("no target store set in vm config");
            $retc = 1;
         }
      } else {
         $logger->debug("storage override use [$override_storage]");
         $tstore = $override_storage;
      }
      if ( defined $config{'VM'}{$vms}{'ge'} ) {
         $gens = $config{'VM'}{$vms}{'ge'};
         $logger->debug("vm setting vm generations = $gens");
      }
      if ( defined $config{'VM'}{$vms}{'sd'} ) {
         $vmshut = $config{'VM'}{$vms}{'sd'};
         $logger->debug("vm setting shutdown delays = $vmshut");
      }
      if ( defined $config{'VM'}{$vms}{'tf'} ) {
         $tfolder = $config{'VM'}{$vms}{'tf'};
         $logger->debug("vm target folder set = $tfolder");
      }
      if ( defined $config{'VM'}{$vms}{'tp1'} ) {
         $tpg1 = $config{'VM'}{$vms}{'tp1'};
         $logger->debug("vm target port group nic 1 = $tpg1");
      }
      if ( defined $config{'VM'}{$vms}{'tp2'} ) {
         $tpg2 = $config{'VM'}{$vms}{'tp2'};
         $logger->debug("vm target port group nic 2 = $tpg2");
      }
      if ( defined $config{'VM'}{$vms}{'mw'} ) {
         $mailwait = $config{'VM'}{$vms}{'mw'};
         $logger->debug("vm wait mail send = $mailwait");
      }
      if ( defined $config{'VM'}{$vms}{'external'} ) {
         $ext_cmd  = $config{'VM'}{$vms}{'external'};
         $ext_parm = "none";
         $logger->info("vm setting external command: $ext_cmd");
         if ( defined $config{'VM'}{$vms}{'extparam'} ) {
            $ext_parm = $config{'VM'}{$vms}{'extparam'};
            $logger->debug("vm setting ext. parameter: $ext_parm");
            @ext_parm = split( " ", $ext_parm );
         } else {
            $logger->debug("vm setting no ext. parameter found");
         }
      } ## end if ( defined $config{'VM'}{$vms}{'external'} )
      $vmname = $usevm;
      unless ($retc) { $gefunden = 1; }
   } ## end if ( ( $usevm eq $vms ) || ( $useoptvm eq $vms ) )
} ## end foreach $vms ( keys %{ $config{'VM'} } )
$logger->debug("Search clonematrix finish");
if ($gefunden) {
   if ( $rebootonly eq "no" ) {
      $logger->info("VM $vmname to clone exist in clone matrix - clone now");
   } else {
      $logger->info("VM $vmname to reboot exist in clone matrix - reboot now");
   }
   $logger->info("VC $vc");
   srand($go);
   $pass .= chr( ord($_) ^ int( rand(10) ) ) for ( split( '', $cpass ) );
   unless ($chkon) {
      if ($vmshut) {
         $logger->info("VM setting to shutdown vm first found");
         $logger->debug( $dirs . "vmoff.pl" );
         $logger->debug( "  ==> Parameter: --vmname ", $vmname, " --server ", $vc );
         $logger->debug( "                 --retries ", $vmshut, " --username ", $user, " --password *******" );
         $logger->debug( "                 --log ", $logfile );
         my @command = ( $dirs . "vmoff.pl", "--vmname", $vmname, "--server", $vc, "--username", $user, "--password", $pass, "--retries", $vmshut, "--log", $logfile );
         if ( $logger->level() eq 10000 ) {
            @command = ( @command, "--debug" );
         }
         $logger->info("Shutdown vm now.");
         $timerlog->start;
         $retc = system(@command);
         if ( $retc == 0 ) {
            $timerlog->stop;
            $logger->info("VM $vmname shutdown successfully");
         } else {
            $timerlog->stop;
            $logger->error("Cannot shutdown vm $vmname ($retc) - abort $?");
         }
         $tvmoff = $timerlog->string();
         $logger->debug("Time vmoff.pl run: $tvmoff");
      } else {
         $tvmoff = "not shutdown";
         $logger->info("No VM shutdown configure");
      }
   } else {
      $logger->trace("  only check if vm on - no shutdown");
   }
   unless ($retc) {
      if ( $rebootonly eq "yes" ) {
         $logger->debug("Reboot only flag - no cloning");
      } elsif ($chkon) {
         $logger->debug("Check flag - do not clone");
      } else {
         $clone_name = $vmname . "-" . TimeStamp(13);
         $logger->debug( $dirs . "vmclone.pl" );
         $logger->debug( "  ==> Parameter: --vmname ", $vmname, " --server ", $vc );
         $logger->debug( "                 --targetvmname ", $clone_name );
         $logger->debug( "                 --targethost ", $thost, " --targetstore ", $tstore );
         unless ( "$trespool" eq "none" ) {
            $logger->debug( "                 --targetpool ", $trespool );   
         }
         unless ( $tfolder eq "none" ) {
            $logger->debug( "                 --targetfolder ", $tfolder );
         }
         $logger->debug( "                 --username ", $user, " --password *******" );
         $logger->debug( "                 --log ", $logfile );
         unless ( $tpg1 eq "none" ) {
            $logger->debug( "                 --pg1 ", $tpg1 );
         }
         unless ( $tpg2 eq "none" ) {
            $logger->debug( "                 --pg2 ", $tpg2 );
         }
         my @command = ( $dirs . "vmclone.pl", "--vmname", $vmname, "--targetvmname", $clone_name, "--server", $vc, "--targethost", $thost, "--targetstore", $tstore, "--username", $user, "--password", $pass, "--log", $logfile, "--pg1", $tpg1, "--pg1", $tpg1);
         unless ( $tfolder eq "none" ) {
            @command = ( @command, "--targetfolder", $tfolder );
         }
         unless ( "$trespool" eq "none" ) {
            @command = ( @command, "--targetpool", $trespool );   
         }

         if ( $logger->level() eq 10000 ) {
            @command = ( @command, "--debug" );
         }
         if ( $useoptvm ne "no" ) {
            $logger->debug( "                 --targetvmname ", $useoptvm . "-" . TimeStamp(13) );
            @command = ( @command, "--targetvmname", $useoptvm . "-" . TimeStamp(13) );
         }
         $logger->info("Start clone procedure.");
         $timerlog->start;
         if ( system(@command) == 0 ) {
            $timerlog->stop;
            $logger->info("Cloning successfull ended");
         } else {
            $timerlog->stop;
            $retc = 98;
            $logger->error("system call to vmclone.pl failed: $?");
         }
         $tvmclone = $timerlog->string();
         $logger->debug("Time vmclone.pl run: $tvmclone");
      } ## end else [ if ( $rebootonly eq "yes" ) ]
   } ## end unless ($retc)
   unless ($retc) {
      unless ($chkon) {
         if ($vmshut) {
            $logger->info("VM setting to shutdown vm first found");
            $logger->info("Due to that, power on VM now");
            $logger->debug( $dirs . "vmon.pl" );
            $logger->debug( "  ==> Parameter: --vmname ", $vmname, " --server ", $vc );
            $logger->debug( "                 --username ", $user, " --password *******" );
            $logger->debug( "                 --log ", $logfile );
            my @command = ( $dirs . "vmon.pl", "--vmname", $vmname, "--server", $vc, "--username", $user, "--password", $pass, "--log", $logfile );
            if ( $logger->level() eq 10000 ) {
               @command = ( @command, "--debug" );
            }
            $logger->info("Power On vm now.");
            if ( system(@command) == 0 ) {
               $logger->info("VM $vmname powered on");
            } else {
               $logger->error("Cannot power on vm $vmname - abort $?");
               $retc = 94;
            }
         } else {
            $logger->info("No shutdown configure, no poweron needed");
         }
      } else {
         $logger->debug("Check flag - do not power on");
      }
   } ## end unless ($retc)
   unless ($retc) {
      if ( $rebootonly eq "yes" ) {
         $logger->debug("Reboot only flag - no external call need");
      } elsif ($chkon) {
         $logger->debug("Check flag - no external call need");
      } else {
         if ( "$ext_cmd" ne "none" ) {
            $logger->debug("found external call.");
            $logger->debug("replace config vars ...");
            my $i = 0;
            while ( $i <= $#ext_parm ) {
               if ( "$ext_parm[$i]" eq "VM_NAME" ) {
                  $ext_parm[ $i ] = $vmname;
                  $logger->trace("found VM_NAME -> $vmname");
               } elsif ( "$ext_parm[$i]" eq "VM_CLONE" ) {
                  $ext_parm[ $i ] = $clone_name;
                  $logger->trace("found VM_CLONE -> $clone_name");
               }
               $i++;
            } ## end while ( $i <= $#ext_parm )
            my @extcmd = ( $dirs . $ext_cmd );
            if ( "$ext_parm" ne "none" ) {
               @extcmd = ( @extcmd, @ext_parm );
            }
            @extcmd = ( @extcmd, "--log", $logfile );
            $logger->info("call external script [$ext_cmd] now ...");
            if ( system(@extcmd) == 0 ) {
               $logger->info("ext. script end without errors");
            } else {
               $logger->error("ext. script end with error: $?");
               $retc = 74;
            }
         } else {
            $logger->debug("no external script define");
         }
      } ## end else [ if ( $rebootonly eq "yes" ) ]
   } ## end unless ($retc)
   unless ($retc) {
      if ( $rebootonly eq "yes" ) {
         $logger->debug("Reboot only flag - no cleaning");
      } elsif ($chkon) {
         $logger->debug("Check flag - no cleaning");
      } else {
         $logger->debug( $dirs . "vmclean.pl" );
         my @command = ( $dirs . "vmclean.pl", "--generation", $gens, "--server", $vc, "--username", $user, "--password", $pass, "--log", $logfile );
         if ( $useoptvm ne "no" ) {
            $logger->debug( "  ==> Parameter: --vmfilter ", $useoptvm, " --generation ", $gens );
            @command = ( @command, "--vmfilter", $useoptvm );
         } else {
            $logger->debug( "  ==> Parameter: --vmfilter ", $vmname, " --generation ", $gens );
            @command = ( @command, "--vmfilter", $vmname );
         }
         $logger->debug( "      --server ", $vc, " --username ", $user, " --password ******" );
         $logger->debug( "                 --log ", $logfile );
         if ( $logger->level() eq 10000 ) {
            @command = ( @command, "--debug" );
         }
         $logger->info("Start cleaning procedure.");
         $timerlog->start;
         if ( system(@command) == 0 ) {
            $timerlog->stop;
            $logger->info("Cleaning successfull ended");
         } else {
            $timerlog->stop;
            $retc = 97;
            $logger->error("system call to vmclean.pl failed: $?");
         }
         $tvmclean = $timerlog->string();
         $logger->debug("Time vmclean.pl run: $tvmclean");
      } ## end else [ if ( $rebootonly eq "yes" ) ]
   } ## end unless ($retc)
   if ($chkon) {
      $logger->info("Check if vm $vmname online");
      $logger->debug( $dirs . "vmon.pl" );
      $logger->debug( "  ==> Parameter: --vmname ", $vmname, " --server ", $vc );
      $logger->debug( "                 --username ", $user, " --password *******" );
      $logger->debug( "                 --chk on --ignore --log ", $logfile );
      my @command = ( $dirs . "vmon.pl", "--vmname", $vmname, "--server", $vc, "--username", $user, "--password", $pass, "--log", $logfile );
      @command = ( @command, "--chk", "on", "--ignore" );
      if ( $logger->level() eq 10000 ) {
         @command = ( @command, "--debug" );
      }
      $logger->info("Check Power status");
      my $status = system(@command);
      $status = $status >> 8 unless ( $status == -1 );
      $logger->trace(" rc=$status");
      if ( $status == 0 ) {
         $logger->info("VM $vmname is online");
         $bootparm="con";
      } elsif ( $status == 1 ) {
         if ( $boot ) {
            $logger->info("VM $vmname is offline - start now");
            $logger->debug( $dirs . "vmon.pl" );
            $logger->debug( "  ==> Parameter: --vmname ", $vmname, " --server ", $vc );
            $logger->debug( "                 --username ", $user, " --password *******", " --ignore" );
            my @command = ( $dirs . "vmon.pl", "--vmname", $vmname, "--server", $vc, "--username", $user, "--password", $pass, "--log", $logfile, "--ignore" );
            my $status = system(@command);
            if ($status) {
               $logger->error("Error starting VM rc=$status");
               $bootparm="cofbe";
               $retc = $status;
            } else {
               $logger->info(" VM $vmname powered on ");
               $bootparm="cofon";
               $retc=0;
            }
         } else {
            $logger->info("VM $vmname is offline - no boot flag set, I leave powered off");
            $bootparm="cofnb";
         }
      } elsif ( $status == 2 ) {
         $logger->info(" VM $vmname is suspended ");
         $bootparm="cs";
         $retc=0;
      } else {
         $logger->error("VM $vmname unknown status- $status ");
         $bootparm="cu";
         $retc = 94;
      }
   } ## end if ($chkon)
   my ( $adr, $fromemail, $smtpsrv, $toemail, $subject );
   my @args;
   my $body;
   my $esmtp = 0;
   my $xu    = " none ";
   my $xp    = "";
   if ( $mailwait == 0 ) {
      $logger->trace(" immediately start email send ");
   } else {
      $logger->info(" wait $mailwait seconds ... ");
      sleep $mailwait;
      $logger->trace(" wait time over- go on ");
   }
   $logger->debug(" Search for vm specify emails ");
   my $vmemails;
   foreach $vmemails ( keys %{ $config{'VM'}{$vmname}{'email'} } ) {
      $logger->debug(" VM spcify email recipient found in config : $vmemails ");
      if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'to'} ) {
         $toemail = $config{'VM'}{$vmname}{'email'}{$vmemails}{'to'};
         $logger->debug(" To email address : $toemail ");
      } else {
         $logger->error(" No to email adr . define for $vmemails - abort send email ");
         next;
      }
      if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'sr'} ) {
         $smtpsrv = $config{'VM'}{$vmname}{'email'}{$vmemails}{'sr'};
         $logger->debug(" SMTP relay server : $smtpsrv ");
      } else {
         $logger->error(" No smtp relay server define for $vmemails - abort send email ");
         next;
      }
      if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'fr'} ) {
         $fromemail = $config{'VM'}{$vmname}{'email'}{$vmemails}{'fr'};
         $logger->debug(" From email address : $fromemail ");
      } else {
         $logger->error(" No from email adr . define for $vmemails - abort send email ");
         next;
      }
      if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'xu'} ) {
         $xu = $config{'VM'}{$vmname}{'email'}{$vmemails}{'xu'};
         $logger->debug(" Login user : $xu ");
         if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'xp'} ) {
            my $cxp = $config{'VM'}{$vmname}{'email'}{$vmemails}{'xp'};
            $xp = "";
            srand($go);
            $xp .= chr( ord($_) ^ int( rand(10) ) ) for ( split( '', $cxp ) );
            $logger->debug(" Found login password ");
            $logger->trace(" Set esmtp to true ");
            $esmtp = 1;
         } else {
            $logger->error(" Found esmtp user- but no password- ignore ");
         }
      } else {
         $logger->debug(" no esmtp ");
      }
      if ($retc) {
         if ( $chkon ) {
            if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'s' . $bootparm} ) {
               $subject = $config{'VM'}{$vmname}{'email'}{$vmemails}{'s' . $bootparm} . " vm:$vmname";
               $logger->trace("  override subject: $subject");
            } else {
               if ( "$bootparm" eq "con") {
                  $subject = "VM $vmname is online";
               } elsif ( "$bootparm" eq "cofnb" ) {
                  $subject="VM $vmname is offline - no boot flag set, I leave powered off";
               } elsif ( "$bootparm" eq "cofbe" ) {   
                  $subject="VM $vmname is offline - error starting";
               } elsif ( "$bootparm" eq "cofon" ) {   
                  $subject="VM $vmname was offline - start ok";
               } elsif ( "$bootparm" eq "cs" ) {   
                  $subject="VM $vmname is suspended ";
               } else {   
                  $subject = "VM $vmname unknown status";
               }
            }               
            if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'b' . $bootparm} ) {
               $body = $config{'VM'}{$vmname}{'email'}{$vmemails}{'b' . $bootparm} . " vm:$vmname";
               $logger->trace("  override body: $body");
            } else {
               if ( "$bootparm" eq "con") {
                  $subject = "VM $vmname is online";
                  $body = " VM $vmname is online. \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               } elsif ( "$bootparm" eq "cofnb" ) {
                  $subject="VM $vmname is offline - no boot flag set, I leave powered off";
                  $body = " Look to the log attached to this mail for further information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               } elsif ( "$bootparm" eq "cofbe" ) {   
                  $subject="VM $vmname is offline - error starting";
                  $body = " Look to the log attached to this mail for further error information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               } elsif ( "$bootparm" eq "cofon" ) {   
                  $subject="VM $vmname was offline - start ok";
                  $body = " Look to the log attached to this mail for further information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               } elsif ( "$bootparm" eq "cs" ) {   
                  $subject="VM $vmname is suspended ";
                  $body = " Look to the log attached to this mail for further  information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               } else {   
                  $subject = "VM $vmname unknown status";
                  $body = " Look to the log attached to this mail for further error information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               }
            }
         } else {
            if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'be'} ) {
               $body = $config{'VM'}{$vmname}{'email'}{$vmemails}{'be'};
               $logger->trace("  override body: $body");
            } else {
               $body = " Look to the log attached to this mail for further error information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
            }
            $subject = " vmc : ERROR vm cloning " . $vmname . " caused error code " . $retc;
         }
      } else {
         if ( $chkon ) {
            if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'s' . $bootparm} ) {
               $subject = $config{'VM'}{$vmname}{'email'}{$vmemails}{'s' . $bootparm} . " vm: $vmname";
               $logger->trace("  override subject: $subject");
            } else {
               if ( "$bootparm" eq "con") {
                  $subject = "VM $vmname is online";
               } elsif ( "$bootparm" eq "cofnb" ) {
                  $subject="VM $vmname is offline - no boot flag set, I leave powered off";
               } elsif ( "$bootparm" eq "cofbe" ) {   
                  $subject="VM $vmname is offline - error starting";
               } elsif ( "$bootparm" eq "cofon" ) {   
                  $subject="VM $vmname was offline - start ok";
               } elsif ( "$bootparm" eq "cs" ) {   
                  $subject="VM $vmname is suspended ";
               } else {   
                  $subject = "VM $vmname unknown status ";
               }
            }               
            if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'b' . $bootparm} ) {
               $body = $config{'VM'}{$vmname}{'email'}{$vmemails}{'b' . $bootparm} . " vm: $vmname";
               $logger->trace("  override body: $body");
            } else {
               if ( "$bootparm" eq "con") {
                  $subject = "VM $vmname is online";
                  $body = " VM $vmname is online. \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               } elsif ( "$bootparm" eq "cofnb" ) {
                  $subject="VM $vmname is offline - no boot flag set, I leave powered off";
                  $body = " Look to the log attached to this mail for further information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               } elsif ( "$bootparm" eq "cofbe" ) {   
                  $subject="VM $vmname is offline - error starting";
                  $body = " Look to the log attached to this mail for further error information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               } elsif ( "$bootparm" eq "cofon" ) {   
                  $subject="VM $vmname was offline - start ok";
                  $body = " Look to the log attached to this mail for further information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               } elsif ( "$bootparm" eq "cs" ) {   
                  $subject="VM $vmname is suspended ";
                  $body = " Look to the log attached to this mail for further  information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               } else {   
                  $subject = "VM $vmname unknown status ";
                  $body = " Look to the log attached to this mail for further error information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
               }
            }
         } else {
            if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'bo'} ) {
               $body = $config{'VM'}{$vmname}{'email'}{$vmemails}{'bo'};
               $logger->trace("  override body: $body");
            } else {
               $body = " Look to the log attached to this mail for further information . \nVM shutdown time : $tvmoff \nVM clone time : $tvmclone \nVM clean time : $tvmclean \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
            }
            $subject = " vmc : OK vm cloning " . $vmname . " finish successfully " . $retc;
         }
      } ## end else [ if ($retc) ]
      $logger->trace(" email-body : $body ");
      $logger->info(" send mail to $toemail");
      $logger->debug( $dirs . " semail . pl " );
      $logger->debug(" == > -f ", $fromemail, " -t ", $toemail );
      $logger->debug(" - s ",     $smtpsrv );
      $logger->debug("     -u ",  $subject );
      $logger->debug("     -m [define budy text]");
      $logger->debug("     -a ", $maillog );
      # $logger->debug( "     -a ", $xmllog );
      $logger->debug( "     -l ", $logfile );
      
      # "-a", $xmllog,
      @args = ( $dirs . "semail.pl", "-f", $fromemail, "-t", $toemail, "-s", $smtpsrv, "-u", $subject, "-m", $body, "-a", $maillog, "-l", $logfile );

      my $opt_tls="";
      if ( defined $config{'VM'}{$vmname}{'email'}{$vmemails}{'tls'} ) {
         $opt_tls = $config{'VM'}{$vmname}{'email'}{$vmemails}{'tls'};
         $logger->trace("  found tls option: $opt_tls");
         $logger->debug( "     -o ", "tls ". $opt_tls );
         @args = ( @args, "-o", "tls=". $opt_tls);
      } else {
         $logger->trace("  found no tls option - ignore");
      }

      if ( $logger->level() eq 10000 ) {
         @args = ( @args, "--debug" );
      }
      if ($esmtp) {
         $logger->debug("esmtp enable - add login to arguments");
         @args = ( @args, "-xu", $xu, "-xp", $xp );
      }
      if ( $mailwait == 0 ) {
         $logger->trace("immediately start email send");
      } else {
         $logger->info("wait $mailwait seconds ...");
         sleep $mailwait;
         $logger->trace("wait time over - go on");
      }
      if ($sendemail) {
         if ( system(@args) == 0 ) {
            $logger->info("send email successfull");
         } else {
            $retc = 96;
            $logger->error("system call to semail.pl failed: $?");
         }
      } else {
         $logger->debug("do not send email to $toemail");
      }
   } ## end foreach $vmemails ( keys %{ $config{'VM'}{$vmname}{'email'} } )
   $logger->debug("Search for global specify emails");
   my $email = new Config::General("$dirs../etc/emailcfg");
   if ( -e "$dirs../etc/emailcfg" ) {
      $logger->debug("Emailcfg config file $dirs../etc/emailcfg found");
      my %emails = $email->getall;
      foreach $adr ( keys %{ $emails{'email'} } ) {
         $logger->debug("Find email address for: $adr");
         if ( defined $emails{'email'}{$adr}{'to'} ) {
            $toemail = $emails{'email'}{$adr}{'to'};
            $logger->debug("To email address: $toemail");
         } else {
            $logger->error("No to email adr. define for $vmemails - abort send email");
            next;
         }
         if ( defined $emails{'email'}{$adr}{'sr'} ) {
            $smtpsrv = $emails{'email'}{$adr}{'sr'};
            $logger->debug("SMTP relay server: $smtpsrv");
         } else {
            $logger->error("No smtp relay server define for $vmemails - abort send email");
            next;
         }
         if ( defined $emails{'email'}{$adr}{'fr'} ) {
            $fromemail = $emails{'email'}{$adr}{'fr'};
            $logger->debug("From email address: $fromemail");
         } else {
            $logger->error("No from email adr. define for $vmemails - abort send email");
            next;
         }
         if ( defined $emails{'email'}{$adr}{'xu'} ) {
            $xu = $emails{'email'}{$adr}{'xu'};
            $logger->debug("Login user: $xu");
            if ( defined $emails{'email'}{$adr}{'xp'} ) {
               my $cxp = $emails{'email'}{$adr}{'xp'};
               $xp = "";
               srand($go);
               $xp .= chr( ord($_) ^ int( rand(10) ) ) for ( split( '', $cxp ) );
               $logger->debug("Found login password");
               $logger->trace("Set esmtp to true");
               $esmtp = 1;
            } else {
               $logger->error("Found esmtp user - but no password - ignore");
            }
         } else {
            $logger->debug("no esmtp");
         }
         if ($retc) {
            if ( $chkon ) {
               if ( defined $emails{'email'}{$adr}{'s' . $bootparm} ) {
                  $subject = $emails{'email'}{$adr}{'s' . $bootparm} . " vm: $vmname";
                  $logger->trace("  override subject: $subject");
               } else {
                  if ( "$bootparm" eq "con") {
                     $subject = "VM $vmname is online";
                  } elsif ( "$bootparm" eq "cofnb" ) {
                     $subject="VM $vmname is offline - no boot flag set, I leave powered off";
                  } elsif ( "$bootparm" eq "cofbe" ) {   
                     $subject="VM $vmname is offline - error starting";
                  } elsif ( "$bootparm" eq "cofon" ) {   
                     $subject="VM $vmname was offline - start ok";
                  } elsif ( "$bootparm" eq "cs" ) {   
                     $subject="VM $vmname is suspended ";
                  } else {   
                     $subject = "VM $vmname unknown status ";
                  }
               }               
               if ( defined $emails{'email'}{$adr}{'b' . $bootparm} ) {
                  $body = $emails{'email'}{$adr}{'b' . $bootparm} . " vm: $vmname";
                  $logger->trace("  override body: $body");
               } else {
                  if ( "$bootparm" eq "con") {
                     $subject = "VM $vmname is online";
                     $body = " VM $vmname is online. \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  } elsif ( "$bootparm" eq "cofnb" ) {
                     $subject="VM $vmname is offline - no boot flag set, I leave powered off";
                     $body = " Look to the log attached to this mail for further information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  } elsif ( "$bootparm" eq "cofbe" ) {   
                     $subject="VM $vmname is offline - error starting";
                     $body = " Look to the log attached to this mail for further error information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  } elsif ( "$bootparm" eq "cofon" ) {   
                     $subject="VM $vmname was offline - start ok";
                     $body = " Look to the log attached to this mail for further information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  } elsif ( "$bootparm" eq "cs" ) {   
                     $subject="VM $vmname is suspended ";
                     $body = " Look to the log attached to this mail for further  information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  } else {   
                     $subject = "VM $vmname unknown status ";
                     $body = " Look to the log attached to this mail for further error information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  }
               }
            } else {
               if ( defined $emails{'email'}{$adr}{'be'} ) {
                  $body = $emails{'email'}{$adr}{'be'};
                  $logger->trace("  override body: $body");
               } else {
                  $body = "Look to the log attached to this mail for further error information. \n\nRegards VI Team (js)\n\n\nFiles:\n\n ";
               }
               $subject = "vmc: ERROR vm cloning " . $vmname . " caused error code " . $retc;
            }
         } else {
            if ( $chkon ) {
               if ( defined $emails{'email'}{$adr}{'s' . $bootparm} ) {
                  $subject = $emails{'email'}{$adr}{'s' . $bootparm} . " vm: $vmname";
                  $logger->trace("  override subject: $subject");
               } else {
                  if ( "$bootparm" eq "con") {
                     $subject = "VM $vmname is online";
                  } elsif ( "$bootparm" eq "cofnb" ) {
                     $subject="VM $vmname is offline - no boot flag set, I leave powered off";
                  } elsif ( "$bootparm" eq "cofbe" ) {   
                     $subject="VM $vmname is offline - error starting";
                  } elsif ( "$bootparm" eq "cofon" ) {   
                     $subject="VM $vmname was offline - start ok";
                  } elsif ( "$bootparm" eq "cs" ) {   
                     $subject="VM $vmname is suspended ";
                  } else {   
                     $subject = "VM $vmname unknown status ";
                  }
               }               
               if ( defined $emails{'email'}{$adr}{'b' . $bootparm} ) {
                  $body = $emails{'email'}{$adr}{'b' . $bootparm} . " vm: $vmname";
                  $logger->trace("  override body: $body");
               } else {
                  if ( "$bootparm" eq "con") {
                     $subject = "VM $vmname is online";
                     $body = " VM $vmname is online. \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  } elsif ( "$bootparm" eq "cofnb" ) {
                     $subject="VM $vmname is offline - no boot flag set, I leave powered off";
                     $body = " Look to the log attached to this mail for further information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  } elsif ( "$bootparm" eq "cofbe" ) {   
                     $subject="VM $vmname is offline - error starting";
                     $body = " Look to the log attached to this mail for further error information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  } elsif ( "$bootparm" eq "cofon" ) {   
                     $subject="VM $vmname was offline - start ok";
                     $body = " Look to the log attached to this mail for further information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  } elsif ( "$bootparm" eq "cs" ) {   
                     $subject="VM $vmname is suspended ";
                     $body = " Look to the log attached to this mail for further  information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  } else {   
                     $subject = "VM $vmname unknown status ";
                     $body = " Look to the log attached to this mail for further error information . \n \nRegards VI Team(js) \n \n \nFiles : \n \n ";
                  }
               }
            } else {
               if ( defined $emails{'email'}{$adr}{'bo'} ) {
                  $body = $emails{'email'}{$adr}{'bo'};
                  $logger->trace("  override body: $body");
               } else {
                  $body = "Look to the log attached to this mail for further information. \nVM shutdown time: $tvmoff\nVM clone time: $tvmclone\nVM clean time: $tvmclean\n\nRegards VI Team (js)\n\n\nFiles:\n\n ";
               }
               $subject = "vmc: OK vm cloning " . $vmname . " finish successfully " . $retc;
            }
         } ## end else [ if ($retc) ]
         $logger->trace("email-body: $body");
         $logger->info("send mail to $toemail");
         $logger->debug( $dirs . "semail.pl" );
         $logger->debug( " ==> -f ", $fromemail, " -t ", $toemail );
         $logger->debug( "     -s ", $smtpsrv );
         $logger->debug( "     -u ", $subject );
         $logger->debug("     -m [define budy text]");
         $logger->debug( "     -a ", $maillog );

         # $logger->debug( "     -a ", $xmllog );
         $logger->debug( "     -l ", $logfile );

         # "-a", $xmllog,
         @args = ( $dirs . "semail.pl", "-f", $fromemail, "-t", $toemail, "-s", $smtpsrv, "-u", $subject, "-m", $body, "-a", $maillog, "-l", $logfile );

         my $opt_tls="";
         if ( defined $emails{'email'}{$adr}{'tls'} ) {
            $opt_tls = $emails{'email'}{$adr}{'tls'};
            $logger->trace("  found tls option: $opt_tls");
            $logger->debug( "     -o ", "tls ". $opt_tls );
            @args = ( @args, "-o", "tls=". $opt_tls);
         } else {
            $logger->trace("  found no tls option - ignore");
         }

         if ( $logger->level() eq 10000 ) {
            @args = ( @args, "--debug" );
         }
         if ($esmtp) {
            $logger->debug("esmtp enable - add login to arguments");
            @args = ( @args, "-xu", $xu, "-xp", $xp );
         }
         if ($sendemail) {
            if ( system(@args) == 0 ) {
               $logger->info("send email successfull");
            } else {
               $retc = 96;
               $logger->error("system call to semail.pl failed: $?");
            }
         } else {
            $logger->debug("do not send email to $toemail");
         }
      } ## end foreach $adr ( keys %{ $emails{'email'} } )
   } else {
      $logger->warn("Cannot find clonematrix config file $dirs../etc/emailcfg");
      $logger->warn("No global emails send");
   }
} else {
   $logger->error("VM $usevm does not exist in clone matrix - abort");
}

# del_file($xmllog);
del_file($maillog);
del_flagfile($flagfile);
$logger->info("End $prg - version $ver return code $retc");
exit($retc);
__END__
