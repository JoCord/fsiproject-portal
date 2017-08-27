#!/usr/bin/perl -w
# 
#   vmoff.pl - poweroff or shutdown vm
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
our $ver = '1.07.01 - 22.5.2014';

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
my $usage = "Usage: $name --server <vc> --username <login user> --password <password  --vmname <VM to shutdown>";
my ($server,$dash,$idx,$length,$headline,$vmname,$vm_view,$task_ref,$msg);

if ($#ARGV eq '-1') {print $usage; exit;}

local $SIG{__DIE__} = sub{Util::disconnect();};

my %opts = (
   vmname => {
         type => "=s",
         help => "Name of VM to shutdown\n$usage",
         required => 1,
   },
   retries => {
      type => "=s",
      help => "How long to wait for shutdown succeeded.",
      required => 0,
      default => 2,
   },
   log => {
      type => "=s",
      help => "Logfile.",
      required => 0,
      default => "none",
   },
   debug => {
      type => "",
      help => "Log level DEBUG",
      required => 0,
      default => "none",
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();

use File::Spec; 
use File::Basename;
my $rel_path = File::Spec->rel2abs( __FILE__ );
my ($volume,$dirs,$prg) = File::Spec->splitpath( $rel_path );
my $prgname = basename($prg, '.pl');

use Log::Log4perl qw(:no_extra_logdie_message);
my $conf_file = $dirs . '../etc/log4p_vmc';
my $logfile;
if (Opts::get_option('log') eq "none") {
   $logfile = sprintf "%s../logs/%s-%s.log", $dirs, $prgname, Opts::get_option('vmname'); 
} else {
   $logfile = Opts::get_option('log'); 
}
sub log4p_logfile { return  $logfile };
Log::Log4perl->init( $conf_file );
my $logger = Log::Log4perl::get_logger();

$logger->info("Starting $prg - version $ver");
if (Opts::get_option('debug') ne "none") {
      $logger->level(10000);
      $logger->debug("Activate debug log level");
}
my $flagfile = $dirs . '../tmp/' . $prgname . '-' . Opts::get_option('vmname') . '.pid';

$logger->debug("PID : " . $flagfile);
$logger->debug("User: " . Opts::get_option('username'));

my $retc=0;
my $waiting=1;
my $maxwait=100;
my $waitcount=0;

$logger->debug("Test if script already running ...");
while ($waiting) {
   if (-e $flagfile) {
      $logger->info("$prgname is already running - waiting ..");
      sleep(10);
      $waitcount++;
      if ($waitcount eq $maxwait) {
         $logger->warining("Wait to long ... abort");
         $retc=100;
      }
   } else {
      open (PIDFILE, ">>$flagfile");
      ## Put the file into non-buffering mode
      select PIDFILE;
      $| = 1;
      select STDOUT;
      print PIDFILE localtime() . "\n" . Opts::get_option('vmname');
      $logger->info("We running exclusive ... flagfile created");
      $waiting=0;
   }
}

unless($retc) {
   $logger->trace("Connect to vc ..");
   Util::connect();
  
   $vmname = Opts::get_option('vmname');
   
   $logger->info("Search for VM $vmname");

   my $vm;
   $logger->trace("Get VM overview ..");
   $vm = Vim::find_entity_view(view_type => 'VirtualMachine',
                                  filter => {'name' => $vmname});
   $logger->trace("Got VM views $vm ..");
   if (! $vm) {
        $logger->trace("Problem - disconnect");
   	Util::disconnect();
   	$logger->error("Unable to locate VM: $vmname");
        $retc=99;
   } else {
      $logger->info("Found VM");
      
      my $vmneu = $vm->name;
      $logger->debug("VM Name: $vmneu");
   
      my $vmstatus = $vm->runtime->powerState->val;
      $logger->debug("VM is in status : $vmstatus");
      
      if($vmstatus eq 'poweredOff') {
         $logger->info("VM $vmname already powered off");
      } elsif ($vmstatus eq 'suspended') {
         $logger->info("VM $vmname is suspended - abort");
         $retc=98
      } elsif ($vmstatus eq 'poweredOn') {
         $logger->info("VM $vmname powerd on - try to shutdown ...");
         $logger->trace("Get vm status ..");
         if(defined($vm->guest) && ($vm->guest->toolsStatus->val eq 'toolsOld' || $vm->guest->toolsStatus->val eq 'toolsOk') ) {
            eval {
               $logger->info("Shutting down $vmname via VMware Tools...");
               $vm->ShutdownGuest();
            };
   
            if($@) {
               $logger->error("Unable to shutdown $vmname : $@");
               $retc=99;
            }
   
            unless($retc) {
               my $count = 1;
               my $doit = 1;
               my $retries = Opts::get_option('retries');
               $logger->debug("Retries: $retries");
               $logger->info("Waiting for vm shut down ...");
               while ($doit) {
                  $logger->debug("Wait 15 seconds");
                  sleep (15);
                  $count++;
                  $logger->debug("Refresh vm state");
                  $vm->update_view_data();
                  $logger->debug("Test if vm is now powered Off");
                  if ($vm->runtime->powerState->val eq 'poweredOff') {
                     $logger->info("VM successfull shutdown !");
                     $doit = 0;
                  } elsif ($count > $retries) {
                        $logger->error("Timeout shutdown vm $vmname - abort");
                        $retc=96;
                        $doit = 0;
                  } else {
                     $logger->debug("VM still online - retry ...");
                  }
               }
            }
         } else {
               $logger->error("no VM Tools running - thats bad - abort");
               $retc=97;
         }
      } else {
         $logger->error("VM is in unknown state -abort ". $vm->guest->toolsStatus->val);
         $retc=100;
      }
   }

   if (-e $flagfile) {
      $logger->debug("Close PID file");
      close PIDFILE;
      $logger->info("Delete PID file");
      if (unlink $flagfile) {
         $logger->debug("PID file deleted");
      } else {
         $logger->error("Cannot delete PID file");
         $retc = 99;
      }
   } else {
      $logger->error("ups - no flag file exist - why ?");
   }

   
   $logger->info("VM shutdown process finished");
}
$logger->debug("End $prg - version $ver - rc $retc");
exit ($retc);
