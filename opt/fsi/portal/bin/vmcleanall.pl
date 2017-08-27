#!/usr/bin/perl -w
#
#   vmcleanall.pl - clean generations of all configure vms
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
our $ver = '1.01.01 - 17.7.2014';
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
my $prgname = basename( $prg, '.pl' );
## For printing colors to the console
my ${colorRed}    = "\033[31;1m";
my ${colorGreen}  = "\033[32;1m";
my ${colorCyan}   = "\033[36;1m";
my ${colorWhite}  = "\033[37;1m";
my ${colorNormal} = "\033[m";
my ${colorBold}   = "\033[1m";
my ${colorNoBold} = "\033[0m";
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
my $startclean       = 1;

my $loglevel         = 0;
my $logfile          = "no";
my $clonematrix      = "../etc/clonematrix";

for ( $counter = 0 ; $counter < $numargv ; $counter++ ) {
   print("\nArgument: $ARGS[$counter]\n");
   if ( $ARGS[ $counter ] =~ /^-h$/i ) {
      help();
   } elsif ( $ARGS[ $counter ] eq "" ) {
      ## Do nothing
   } elsif ( $ARGS[ $counter ] =~ /^--help/ ) {
      help();
   } elsif ( $ARGS[ $counter ] =~ m/^--clean$/ ) {
      $startclean = 0;
   } elsif ( $ARGS[ $counter ] =~ m/^--debug$/ ) {
      $loglevel = 10000;
      print("Activate debug log level");
   } elsif ( $ARGS[ $counter ] =~ m/^--trace$/ ) {
      $loglevel = 5000;
      print("Activate trace log level");
   } else {
      print("Unknown option [$ARGS[$counter]]- ignore");
   }
} ## end for ( $counter = 0 ; $counter < $numargv ; $counter++ )
print("\n\n");
$logfile = sprintf "%s../logs/%s", $dirs, $prgname;

sub log4p_logfile { return $logfile }

Log::Log4perl->init($conf_file);
my $logger = Log::Log4perl::get_logger();
$logger->info("Starting $prg - version $ver");

sub help {
   print <<EOM;

             ${colorBold}H E L P for $prgname ${colorNoBold}

  ${colorGreen}Clean generations of all configure vms${colorNormal}
  
    ${colorRed}Parameter${colorNormal}
     --clean           start cleaning
     
    ${colorRed}System parameter${colorNormal}
     --debug                 debug mode
    
EOM
   exit(0);
} ## end sub help

if ( $loglevel ne "no" ) {
   $logger->level($loglevel);
   $logger->debug("Activate new log level: [$loglevel]");
}
$logger->info( "Log Level: " . $logger->level() );

my $go = 4123123123213;
$logger->debug("Test if clonematrix exist");
if ( -e "$dirs$clonematrix" ) {
   $logger->debug("Clonematrix config file found");
} else {
   $logger->error("Cannot find clonematrix config file $dirs$clonematrix");
   exit(40);
}
my $conf = new Config::General("$dirs../etc/clonematrix");
$logger->debug("Get all clone configurations ...");
my %config = $conf->getall;
$logger->info("Check if VM is known");

# use Data::Dumper;
# print Dumper(\%config);
foreach my $vms ( keys %{ $config{'VM'} } ) {
   $logger->debug("==> VM found in config: [$vms]");
   
   my $vc="none";
   my $cpass="none";
   my $pass;
   my $user="none";
   my $gens=1;
   
   if ( defined $config{'VM'}{$vms}{'vc'} ) {
      if ( "$vc" eq "none" ) {
         $vc = $config{'VM'}{$vms}{'vc'};
         $logger->debug("vm setting virtual center = $vc");
      }
   } else {
      $logger->error("no vitual center found in vm config");
      $retc = 1;
   }
   if ( defined $config{'VM'}{$vms}{'pwd'} ) {
      if ( "$cpass" eq "none" ) {
         $cpass = $config{'VM'}{$vms}{'pwd'};
         $logger->debug("vm setting password found = ********");
      }
   } else {
      $logger->error("no access password set in vm config");
      $retc = 1;
   }
   
   if ( defined $config{'VM'}{$vms}{'usr'} ) {
      if ( "$user" eq "none" ) {
         $user = $config{'VM'}{$vms}{'usr'};
         $logger->debug("vm setting login user = $user");
      }
   } else {
      $logger->error("no access user set in vm config");
      $retc = 1;
   }
   if ( defined $config{'VM'}{$vms}{'ge'} ) {
      $gens = $config{'VM'}{$vms}{'ge'};
      $logger->debug("vm setting vm generations = $gens");
   }
   
   unless ( $retc ) {
      srand($go);
      $pass .= chr( ord($_) ^ int( rand(10) ) ) for ( split( '', $cpass ) );
   
      $logger->debug( $dirs . "vmclean.pl" );
      my @command = ( $dirs . "vmclean.pl", "--generation", $gens, "--server", $vc, "--username", $user, "--password", $pass, "--log", $logfile );
      $logger->debug( "  ==> Parameter: --vmfilter ", $vms, " --generation ", $gens );
      @command = ( @command, "--vmfilter", $vms );
      $logger->debug( "      --server ", $vc, " --username ", $user, " --password ******" );
      $logger->debug( "      --log ", $logfile );
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
   }
      
}
$logger->debug("Search clonematrix finish");

$logger->info("End $prg - version $ver return code $retc");
exit($retc);
__END__
