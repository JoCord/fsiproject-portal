#!/usr/bin/perl -w
#
#   vmon.pl - poweron vm
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
our $ver = "1.06.01 - 22.5.2014";

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use VMware::VILib;
use VMware::VIRuntime;
use File::Basename;
use English;
use Cwd qw(:DEFAULT getcwd);
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
my $name = fileparse($0);
my ( $server, $dash, $idx, $length, $headline, $vmname, $vm_view, $task_ref, $msg );
## For printing colors to the console
my ${colorRed}    = "\033[31;1m";
my ${colorGreen}  = "\033[32;1m";
my ${colorCyan}   = "\033[36;1m";
my ${colorWhite}  = "\033[37;1m";
my ${colorNormal} = "\033[m";
my ${colorBold}   = "\033[1m";
my ${colorNoBold} = "\033[0m";
local $SIG{__DIE__} = sub { Util::disconnect(); };
my %opts = (
             vmname => {
                         type     => "=s",
                         help     => "Name of VM to power on",
                         required => 1, },
             server => {
                         type     => "=s",
                         help     => "Name of Virtual Center or ESXi",
                         required => 1, },
             log => {
                      type     => "=s",
                      help     => "Logfile.",
                      required => 0,
                      default  => "none", },
             debug => {
                        type     => "",
                        help     => "Log level DEBUG",
                        required => 0,
                        default  => "none", },
             chk => {
                      type     => "",
                      help     => "chk only - no power on",
                      required => 0,
                      default  => "none", },
             ignore => {
                         type     => "",
                         help     => "ignore pid file",
                         required => 0,
                         default  => "none", },
               );
use File::Spec;
use File::Basename;
my $rel_path = File::Spec->rel2abs(__FILE__);
my ( $volume, $dirs, $prg ) = File::Spec->splitpath($rel_path);
my $prgname = basename( $prg, '.pl' );
if ( $#ARGV eq '-1' ) { help(); }
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
use Log::Log4perl qw(:no_extra_logdie_message);
my $conf_file = $dirs . '../etc/log4p_vmc';
my $logfile;

if ( Opts::get_option('log') eq "none" ) {
   $logfile = sprintf "%s../logs/%s-%s.log", $dirs, $prgname, Opts::get_option('vmname');
} else {
   $logfile = Opts::get_option('log');
}
sub log4p_logfile { return $logfile }
Log::Log4perl->init($conf_file);
my $logger = Log::Log4perl::get_logger();

sub help {
   print <<EOM;

             ${colorBold}H E L P for $prgname ${colorNoBold}

  ${colorGreen}power on or check if power on${colorNormal}
  
    ${colorRed}VM to handle${colorNormal}
     --vmname <vmname>       work with this vm
     --server <vc>           virtual center
    
    ${colorRed}System parameter${colorNormal}
     --debug                 debug mode
     --chk on                check only - do not power on vm
                              rc=1 on
                              rc=0 offline or suspended
     --ignore                ignore pid file
    
EOM
   exit(0);
} ## end sub help

sub getStatus {
   my ( $taskRef, $message ) = @_;
   my $task_view = Vim::get_view( mo_ref => $taskRef );
   my $taskinfo  = $task_view->info->state->val;
   my $continue  = 1;
   while ($continue) {
      my $info = $task_view->info;
      if ( $info->state->val eq 'success' ) {
         $logger->info($message);
         $continue = 0;
      } elsif ( $info->state->val eq 'error' ) {
         my $soap_fault = SoapFault->new;
         $soap_fault->name( $info->error->fault );
         $soap_fault->detail( $info->error->fault );
         $soap_fault->fault_string( $info->error->localizedMessage );
         die "$soap_fault\n";
      } ## end elsif ( $info->state->val eq 'error' )
      sleep '5';
      $task_view->ViewBase::update_view_data();
   } ## end while ($continue)
   return;
} ## end sub getStatus
$logger->info("Starting $prg - version $ver");
if ( Opts::get_option('debug') ne "none" ) {
   $logger->level(10000);
   $logger->debug("Activate debug log level");
}
my $chkon;
if ( Opts::get_option('chk') eq "none" ) {
   $logger->debug("Do not check online status");
   $chkon = 0;
} else {
   $logger->debug("Check vm online status");
   $chkon = 1;
}
my $ignore;
if ( Opts::get_option('ignore') ne "none" ) {
   $logger->debug("Ignore pid file");
   $ignore = 0;
} else {
   $logger->debug("Do not ignore pid file - check if script is still running");
   $ignore = 1;
}
my $flagfile = $dirs . '../tmp/' . $prgname . '-' . Opts::get_option('vmname') . '.pid';

# my $flagfile = $dirs . '../tmp/' . $prgname . '.pid';
$logger->debug( "PID : " . $flagfile );
$logger->debug( "User: " . Opts::get_option('username') );
my $retc      = 0;
my $waiting   = 1;
my $maxwait   = 100;
my $waitcount = 0;
if ($ignore) {
   $logger->debug("Test if script already running ...");
   while ($waiting) {
      if ( -e $flagfile ) {
         $logger->info("$prgname is already running - waiting ..");
         sleep(10);
         $waitcount++;
         if ( $waitcount eq $maxwait ) {
            $logger->warining("Wait to long ... abort");
            $retc = 100;
         }
      } else {
         open( PIDFILE, ">>$flagfile" );
         ## Put the file into non-buffering mode
         select PIDFILE;
         $| = 1;
         select STDOUT;
         print PIDFILE localtime() . "\n" . Opts::get_option('vmname');
         $logger->info("We running exclusive ... flagfile created");
         $waiting = 0;
      } ## end else [ if ( -e $flagfile ) ]
   } ## end while ($waiting)
} ## end if ($ignore)
unless ($retc) {
   $logger->trace( "Connect to server now " . Opts::get_option('server') );
   Util::connect();
   $vmname = Opts::get_option('vmname');
   $logger->info("Search for VM $vmname");
   $logger->trace("Get vm views ...");
   $vm_view = Vim::find_entity_view( view_type => 'VirtualMachine',
                                     filter    => { 'name' => $vmname } );
   $logger->trace("Got vm view $vm_view");
   if ( !$vm_view ) {
      $logger->trace("Something wrong ... abort");
      Util::disconnect();
      $logger->trace("Disconnect from vc");
      $logger->error("Unable to locate VM: $vmname");
      $retc = 99;
   } else {
      $logger->debug("VM $vmname found - go on");
      my $vmstatus = $vm_view->runtime->powerState->val;
      $logger->info( "VM Status: [" . $vmstatus . "]" );
      if ( 'poweredOff' eq $vmstatus ) {
         unless ($chkon) {
            $logger->info("  ==> VM is powered off.");
            $logger->info( "  ==> Trying to poweron -> " . $vmname );
            eval {
               $task_ref = $vm_view->PowerOnVM_Task();
               $msg      = "\tSuccessfully powered on " . $vmname;
               getStatus( $task_ref, $msg );
            };
            if ($@) {
               $logger->error("Error VM $@ ");
               $retc = 98;
            }
         } else {
            $logger->trace("  only check - no boot");
            $retc = 1;
         }
      } elsif ( 'suspended' eq $vmstatus ) {
         $logger->info("  ==> VM is suspended");
         if ($chkon) {
            $retc=2;
         }
      } elsif ( 'poweredOn' eq $vmstatus ) {
         $logger->info("  ==> VM is already online");
      } else {
         $logger->error("Unknown State for VM $vmstatus");
         $retc = 100;
      }
   } ## end else [ if ( !$vm_view ) ]
   if ($ignore) {
      if ( -e $flagfile ) {
         $logger->debug("Close PID file");
         close PIDFILE;
         $logger->info("Delete PID file");
         if ( unlink $flagfile ) {
            $logger->debug("PID file deleted");
         } else {
            $logger->error("Cannot delete PID file");
            $retc = 99;
         }
      } else {
         $logger->error("ups - no flag file exist - why ?");
      }
   } ## end if ($ignore)
} ## end unless ($retc)
$logger->debug("End $prg - version $ver - rc $retc");
exit($retc);
