#!/usr/bin/perl -w
# 
#   vmdel.pl - delete vm
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
our $ver = '1.08.01 - 22.5.2014';

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
my $usage = "Usage: $name --server <vc> --username <login user> --password <password  --vmname <VM to delete>";
my ($server,$dash,$idx,$length,$headline,$vmname,$vm_view,$task_ref,$msg);

if ($#ARGV eq '-1') {print $usage; exit;}

local $SIG{__DIE__} = sub{Util::disconnect();};

my %opts = (
   vmname => {
      type => "=s",
      help => "Name of VM to Delete\n$usage",
      required => 1,
   },
   log => {
      type => "=s",
      help => "How long to wait for shutdown succeeded.",
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
# my $flagfile = $dirs . '../tmp/' . $prgname . '.pid';
$logger->debug("PID : " . $flagfile);

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
      select PIDFILE;
      $| = 1;
      select STDOUT;
      print PIDFILE localtime() . "\n" . Opts::get_option('vmname');
      $logger->info("We running exclusive ... flagfile created");
      $waiting=0;
   }
}

sub getStatus {
     my ($taskRef,$message) = @_;

     my $task_view = Vim::get_view(mo_ref => $taskRef);
     my $taskinfo = $task_view->info->state->val;
     my $continue = 1;
     while ($continue) {
             my $info = $task_view->info;
             if ($info->state->val eq 'success') {
                     $logger->info($message);
                     $continue = 0;
             } elsif ($info->state->val eq 'error') {
                     my $soap_fault = SoapFault->new;
                     $soap_fault->name($info->error->fault);
                     $soap_fault->detail($info->error->fault);
                     $soap_fault->fault_string($info->error->localizedMessage);
                     die "$soap_fault\n";
             }
             sleep '5';
             $task_view->ViewBase::update_view_data();
     }
     return;
}

unless($retc) {
   
   $logger->debug("User: " . Opts::get_option('username'));
   
   Util::connect();
   
   $vmname = Opts::get_option('vmname');
   
   $logger->info("Search for VM $vmname");
   $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine',
                                       filter => {'name' => $vmname});
   
   if (! $vm_view) {
   	Util::disconnect();
   	$logger->error("Unable to locate VM: $vmname");
        $retc=99;
   } else {
      $logger->debug("VM $vmname found - go on");
      
      my $vmstatus = $vm_view->runtime->powerState->val;
      $logger->info("VM Status: [" . $vmstatus . "]");
      if ('suspended'  eq $vmstatus) {
      	$logger->info("  ==> VM is suspended - clone suspended.");
      } 
      # poweredOff
      if ('poweredOn' eq $vmstatus) {
      	$logger->info("  ==> VM is online");
              $logger->info("  ==> Trying to poweroff -> " . $vmname);
      	eval {
      		$task_ref = $vm_view->PowerOffVM_Task();
                      $msg = "\tSuccessfully powered off " . $vmname;
      		getStatus($task_ref,$msg);
              };
        if($@) { $logger->logdie("Error VM $@ "); }
      }
      
      $logger->info("Trying to delete " . $vmname);
      eval {
         $task_ref = $vm_view->Destroy_Task();
         $msg = "Successfully deleted " . $vmname;
         getStatus($task_ref,$msg);
      };
      
      if($@) { 
         $logger->logdie("VM cannot delete ". $@); 
      } else {
         $logger->info("Delete Process finished");
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


}

$logger->debug("End $prg - version $ver - rc $retc");
exit ($retc);
