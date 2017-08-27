#!/usr/bin/perl -w
# 
#   vmcpg.pl - Change Portgroup
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
our $ver = '1.03.01 - 22.5.2014';

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

my $retc=0;
my $name = fileparse($0);
my $usage = "Usage: $name --server <vc> --username <login user> --password <password  --vmname <VM>  --vnic <Nummer> --portgroup <Portgroup>";
my ($server,$dash,$idx,$length,$headline,$task_ref,$msg);

if ($#ARGV eq '-1') {print $usage; exit;}

local $SIG{__DIE__} = sub{Util::disconnect();};

my %opts = (
   'vmname' => {
         type => "=s",
         help => "The name of the virtual machine",
         required => 1,
   },
   'vnic' => {
         type => "=s",
         help => "vNIC Adapter # (e.g. 1,2,3,etc)",
         required => 1,
   },
   'portgroup' => {
         type => "=s",
         help => "Portgroup to add",
         required => 1,
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
Util::connect();

my $vnic_device;
my $vmname = Opts::get_option ('vmname');
my $vnic = Opts::get_option ('vnic');
my $portgroup = Opts::get_option ('portgroup');

$logger->debug("search vm $vmname");
my $vm_view  = Vim::find_entity_view (view_type => 'VirtualMachine', filter =>{ 'name'=> $vmname});

if ($vm_view) {
   $logger->debug("Found vm");
   my $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
   my $devices = $vm_view->config->hardware->device;
   my $vnic_name_e = "Network adapter $vnic";
   my $vnic_name_g = "Netzwerkadapter $vnic";
   my $vnic_found = "none";

   $logger->debug("Search for vnic ...");
   foreach my $device (@$devices) {
           $vnic_found = $device->deviceInfo->label;
           $logger->debug("VM defice info: $vnic_found");
           if ($vnic_found eq $vnic_name_e){
                   $vnic_device=$device;
           }
           if ($vnic_found eq $vnic_name_g){
                   $vnic_device=$device;
           }
   }
   
   if($vnic_device){
           $logger->debug("Found vnic device: $vnic_device");
           $vnic_device->deviceInfo->summary($portgroup);
           $vnic_device->backing->deviceName($portgroup);
           my $vm_dev_spec = VirtualDeviceConfigSpec->new(device => $vnic_device,operation => $config_spec_operation);

           my $vmPortgroupChangespec = VirtualMachineConfigSpec->new(deviceChange => [ $vm_dev_spec ] );

           $logger->debug("Reconfigure vm ...");
           eval{
                   $vm_view->ReconfigVM(spec => $vmPortgroupChangespec);
           };
           if ($@) {
                   $logger->error("Reconfiguration of portgroup $portgroup failed: $@");
                   $retc=99;
           }
           else {
                   $vm_view->update_view_data();
                   $logger->info("Reconfiguration of portgroup $portgroup successful for $vmname");
           }
   } else {
           $logger->error("Unable to find nic $vnic");
           $retc=98;
   }
} else {
   $logger->error("Unable to locate $vmname!");
   $retc=97;
}

Util::disconnect();
$logger->debug("End $prg - version $ver - rc $retc");
exit ($retc);
