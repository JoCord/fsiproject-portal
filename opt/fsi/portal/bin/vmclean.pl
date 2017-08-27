#!/usr/bin/perl -w
# 
#   vmclean.pl - check if clean need
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
our $ver = '2.00.02 - 23.7.2014';
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use VMware::VILib;
use VMware::VIRuntime;
use File::Basename;
use English;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;


my %opts = (
   vmfilter => {
      type => "=s",
      help => "The filter of the Virtual Machines to clean up",
      required => 1,
   },
   generation => {
      type => "=s",
      help => "How many generation of Virtual Machine still used",
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
   $logfile = sprintf "%s../logs/%s-%s.log", $dirs, $prgname, Opts::get_option('vmfilter'); 
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
my $flagfile = $dirs . '../tmp/' . $prgname . '.pid';
$logger->debug("PID : " . $flagfile);

my $retc=0;
my $waiting=1;
my $maxwait=100;
my $waitcount=0;

my @generations;
my $count = 0;
my $gens;       
my $vc;
my $pass;
my $user;

$logger->debug("Test if script already running ...");
while ($waiting) {
   if (-e $flagfile) {
      $logger->info("$prgname is already running - waiting ..");
      sleep(10);
      $waitcount++;
      if ($waitcount eq $maxwait) {
         $logger->warining("Wait to long ... abort");
         $retc=100;
         $waiting=0;
      }
   } else {
      open (PIDFILE, ">>$flagfile");
      ## Put the file into non-buffering mode
      select PIDFILE;
      $| = 1;
      select STDOUT;
      print PIDFILE localtime() . "\n" . Opts::get_option('vmfilter');
      $logger->info("We running exclusive ... flagfile created");
      $waiting=0;
   }
}

unless($retc) {
   
   local $SIG{__DIE__} = sub{Util::disconnect();};
   $logger->info("Connect to vc now ..");
   Util::connect();
   
   my $filter = Opts::get_option('vmfilter');
   $logger->info("Base VM: ",$filter);

   $gens = Opts::get_option('generation');
   $logger->trace("Generation from Command line : $gens");

   $vc = Opts::get_option('server');
   $pass = Opts::get_option('password');
   $user = Opts::get_option('username');

   $filter = $filter . "-";
   
   my $vm_views = Vim::find_entity_views(
         view_type => 'VirtualMachine',
         filter => {
            'name' => qr/^$filter/
         }
   );
      
   foreach my $vm (@$vm_views) {
      my $vmname=$vm->name;
      $logger->trace("mark $vmname for generations delete");
      $generations[$count] = $vmname;
      $count++;
   }   
}
 
unless($retc) {
   $logger->info("Generations found: $count");
   if ($count > $gens ) {
      $logger->info("  ==> to much generation - delete");
      my $delvms = $count - $gens;
      $logger->info("  ==> must delete $delvms generations");
      my $vc = Opts::get_option('server');
      foreach (sort(@generations)) {
         if ($delvms) {
            $logger->info("  ==> delete: $_");
            $delvms--;
            $logger->debug("execute " . $dirs . "vmdel.pl");
            $logger->debug(" ==> Parameter: --vmname $_");
            $logger->debug("                --server $vc --server $vc");
            $logger->debug("                --username $user --password *******");
            $logger->debug("                --log ",$logfile);
            my @command = ($dirs . "vmdel.pl","--vmname",$_,"--server",$vc,"--server",$vc,"--username",$user,"--password",$pass,"--log",$logfile);
            if ($logger->level() eq 10000) {
               @command = (@command, "--debug");
            }
            if ( system(@command) == 0 ) {
                $logger->info("system vmdel.pl successfull");
            } else {
                $retc = 99;
                $logger->error("system call to vmdel.pl failed: $?");
            }
         } else {
            $logger->info("  ==> keep: $_");
         }
      }
   } else {
      $logger->info( "  ==> less or equal generations exist - no delete need");
   }
}

unless ($retc) {   
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

$logger->debug("End $prg - return code $retc");
exit ($retc);
