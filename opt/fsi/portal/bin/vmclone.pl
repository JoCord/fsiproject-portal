#!/usr/bin/perl -w
#
#   vmclone.pl - clone vm
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
our $ver = '1.12.04 - 26.6.2014';

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Config::General;
use English;
use VMware::VIRuntime;
use AppUtil::VMUtil;
use AppUtil::HostUtil;
use Data::Dumper;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;


use File::Path;
require "$Bin/../lib/func.pl";                                                                                                     # some general functions

my $retc = 0;
my $usage = "vmclone $ver\n\nclone vm\n\nparameter: --vmname <vm> --targethost <hostname> --targetstore <store name on target host>\n\n";
if ( $#ARGV eq '-1' ) { print $usage; exit; }

my %opts = (
   targethost => {
      type     => "=s",
      help     => "The name of the target host",
      required => 1,
     },
   vmname => {
      type     => "=s",
      help     => "The name of the Virtual Machine",
      required => 1,
     },
   targetvmname => {
      type     => "=s",
      help     => "Optional target vm name",
      required => 0,
      default  => "none",
     },
   targetstore => {
      type     => "=s",
      help     => "Name of the target datastore",
      required => 1,
     },
   log => {
      type     => "=s",
      help     => "How long to wait for shutdown succeeded.",
      required => 0,
      default  => "none",
     },
   pg1 => {
      type     => "=s",
      help     => "Change portgroup on nic1",
      required => 0,
      default  => "none",
     },
   pg2 => {
      type     => "=s",
      help     => "Change portgroup on nic2",
      required => 0,
      default  => "none",
     },
   targetfolder => {
      type     => "=s",
      help     => "Name of the target folder",
      required => 0,
      default  => "none",
     },
   targetpool => {
      type     => "=s",
      help     => "Name of the target resource pool",
      required => 0,
      default  => "none",
     },
   debug => {
      type     => "",
      help     => "Log level DEBUG",
      required => 0,
      default  => "none",
     },
     );

Opts::add_options(%opts);
Opts::parse();
Opts::validate();

use File::Spec;
use File::Basename;
my $rel_path = File::Spec->rel2abs(__FILE__);
my ( $volume, $dirs, $prg ) = File::Spec->splitpath($rel_path);
my $prgname = basename( $prg, '.pl' );

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
if ( Opts::get_option('debug') ne "none" ) {
   $logger->level(10000);
   $logger->debug("Activate debug log level");
}

$logger->info("Starting $prg - version $ver");
$logger->debug("Pfad: $dirs");
$logger->debug( "User: " . Opts::get_option('username') );
$logger->debug( "Portgroup nic1 change: " . Opts::get_option('pg1') );
$logger->debug( "Portgroup nic2 change: " . Opts::get_option('pg2') );

# Main
$logger->debug( "connect to virtual center " . Opts::get_option('server') );
Util::connect();

my $vm_name = Opts::get_option('vmname');

my $clone_name;
if ( Opts::get_option('targetvmname') ne "none" ) {
   $logger->info("target vm name from command line");
   $clone_name = Opts::get_option('targetvmname');
} else {
   $logger->debug("no command line given for target vm");
   $clone_name = $vm_name . "-" . TimeStamp(13);
}

$logger->info("VM to clone: $vm_name");
$logger->info("Target VM Name: $clone_name");

my $vm_views = Vim::find_entity_views( view_type => 'VirtualMachine',
   filter => { 'name' => $vm_name } );
if (@$vm_views) {
   foreach (@$vm_views) {
      my $disk_size = 0;
      my $devices   = $_->config->hardware->device;
      foreach my $device (@$devices) {
         if ( ref $device eq "VirtualDisk" ) {
            $disk_size = $disk_size + $device->capacityInKB;
         }
      }

      # Target
      my $thost_name = Opts::get_option('targethost');
      $logger->debug("Target host: $thost_name");
      my $thost_view = Vim::find_entity_view( view_type => 'HostSystem',
         filter => { 'name' => $thost_name } );

      if ( !$thost_view ) {
         $logger->error("Target Host $thost_name not found");
         $retc = 95;
      } else {
         $logger->info("Found target host");
         
         my $tdisk_size = 0;
         my $tdevices   = $_->config->hardware->device;
         foreach my $tdevice (@$tdevices) {
            if ( ref $tdevice eq "VirtualDisk" ) {
               $tdisk_size = $tdisk_size + $tdevice->capacityInKB;
            }
         }
         $logger->debug("Target disk size: $tdisk_size");
         if ($thost_view) {
            my $tcomp_res_view = Vim::get_view( mo_ref => $thost_view->parent );
            my $tds_name = Opts::get_option('targetstore');
            my %tds_info = HostUtils::get_datastore( host_view => $thost_view,
                                                     datastore => $tds_name,
                                                     disksize  => $tdisk_size );

#            my $dumpout=Dumper(\%tds_info);
#            $logger->trace(" Overview-Dump: $dumpout");  
                                                     
            if ( $tds_info{mor} eq 0 ) {
               if ( $tds_info{name} eq 'datastore_error' ) {
                  $logger->error("Datastore $tds_name not available.");
                  $retc = 94;
               }
               if ( $tds_info{name} eq 'disksize_error' ) {
                  $logger->error("The free space available is less than the specified disksize or the host is not accessible.");
                  $retc = 93;
               }
            } ## end if ( $tds_info{mor} eq...)
            unless ($retc) {
               my $tresourcepool;    
               my %pool_check;
               
               if ( Opts::get_option('targetpool') eq "none" ) {
                  $logger->info("No change of target resource pool desired");
                  $tresourcepool = $tcomp_res_view->resourcePool;
               } else {
                  $tresourcepool=Opts::get_option('targetpool');
                  $logger->debug(" Resource Pool configure: $tresourcepool");
                  # To check wheather the resource pool belongs to target host or not.
                  %pool_check = HostUtils::check_pool(poolname => $tresourcepool,
                                                       targethost => $thost_name);
                  if($pool_check{foundhost} == 0) {
                     $logger->warn("  Cannot find Resource-Pool $tresourcepool - ignore");
                     $tresourcepool = $tcomp_res_view->resourcePool;
                  } else {
                     $tresourcepool = $pool_check{mor};
                  }
               }
               $logger->trace(" Resource-Pool: $tresourcepool");
#               my $dumpout1=Dumper(\$tresourcepool);
#               $logger->trace(" Overview-Dump: $dumpout1");  
               my $relocate_spec = VirtualMachineRelocateSpec->new( datastore => $tds_info{mor},
                                                                         host => $thost_view,
                                                                         pool => $tresourcepool );
               my $clone_spec;
               
#               my $dumpout=Dumper(\$relocate_spec);
#               $logger->trace(" Overview-Dump: $dumpout");  
               

               # Clone
               $clone_spec = VirtualMachineCloneSpec->new(
                  powerOn  => 0,
                  template => 0,
                  location => $relocate_spec,
                  );

               my $tfolder;

               if ( Opts::get_option('targetfolder') eq "none" ) {
                  $logger->info("No change of target folder desired");
                  $tfolder = $_->parent;
                  $logger->debug("Take current $tfolder folder");
               } else {
                  $logger->info( "New target folder " . Opts::get_option('targetfolder') );
                  my $folder_refurbish_name = Opts::get_option('targetfolder');
                  $tfolder = Vim::find_entity_view(
                     view_type => 'Folder',
                     filter => { "name" => $folder_refurbish_name } );
                  if ( defined $tfolder ) {
                     $logger->debug("Take new folder $tfolder");
                  } else {
                     $logger->error("Wrong target folder set - cannot find it");
                     $tfolder = $_->parent;
                     $logger->debug("Take current $tfolder folder");
                  }
               } ## end else [ if ( Opts::get_option(...))]

               $logger->info( "Cloning virtual machine " . $vm_name . " ..." );
               eval {
                  $_->CloneVM( folder => $tfolder,
                     name => $clone_name,
                     spec => $clone_spec );
                  $logger->info("Clone $clone_name of virtual machine $vm_name successfully created.");
               };
               if ($@) {
                  if ( ref($@) eq 'SoapFault' ) {
                     if ( ref( $@->detail ) eq 'FileFault' ) {
                        $logger->error("Failed to access the virtual machine files");
                        $retc = 50;
                     }
                     elsif ( ref( $@->detail ) eq 'InvalidState' ) {
                        $logger->error("The operation is not allowed in the current state.");
                        $retc = 51;
                     }
                     elsif ( ref( $@->detail ) eq 'NotSupported' ) {
                        $logger->error("Operation is not supported by the current agent");
                        $retc = 52;
                     }
                     elsif ( ref( $@->detail ) eq 'VmConfigFault' ) {
                        $logger->error("Virtual machine is not compatible with the destination host.");
                        $retc = 53;
                     }
                     elsif ( ref( $@->detail ) eq 'InvalidPowerState' ) {
                        $logger->error("The attempted operation cannot be performed in the current state.");
                        $retc = 54;
                     }
                     elsif ( ref( $@->detail ) eq 'DuplicateName' ) {
                        $logger->error("The name $clone_name already exists");
                        $retc = 55;
                     }
                     elsif ( ref( $@->detail ) eq 'NoDisksToCustomize' ) {
                        $logger->error("The virtual machine has no virtual disks that are suitable for customization");
                        $logger->error("or no guest is present on given virtual machine");
                        $retc = 56;
                     }
                     elsif ( ref( $@->detail ) eq 'HostNotConnected' ) {
                        $logger->error("Unable to communicate with the remote host, since it is disconnected");
                        $retc = 57;
                     }
                     elsif ( ref( $@->detail ) eq 'UncustomizableGuest' ) {
                        $logger->error("Customization is not supported for the guest operating system");
                        $retc = 58;
                     }
                     elsif ( ref( $@->detail ) eq 'FilesystemQuiesceFault' ) {
                        $logger->error("Cannot create a quiesced snapshot because the create snapshot operation exceeded");
                        $logger->error("the time limit for holding off I/O in the frozen virtual machine");
                        $retc = 59;
                     }
                     elsif ( ref( $@->detail ) eq 'RequestCanceled' ) {
                        $logger->error("The task was canceled by a user");
                        $retc = 60;
                     }
                     elsif ( ref( $@->detail ) eq 'DatacenterMismatch' ) {
                        $logger->error("Wrong target Datacenter for esx or folder set");
                        $retc = 60;
                     }
                     elsif ( ref( $@->detail ) eq 'NetworkCopyFault' ) {
                        $logger->error("Copy fault during network transfer");
                        $retc = 61;
                     }
                     else {
                        $logger->error( "Fault" . $@ );
                        $retc = 70;
                     }
                  } ## end if ( ref($@) eq 'SoapFault')
                  else {
                     $logger->error( "Fault" . $@ );
                     $retc = 80;
                  }
               } else {
                  $logger->debug("Change portgroup needed for nic 1 ?");
                  if ( Opts::get_option('pg1') eq "none" ) {
                     $logger->info("No Change of portgroup needed");
                  } else {
                     $logger->info("Change portgroup needed!");
                     $logger->debug( $dirs . "vmcpg.pl" );
                     $logger->debug( "  ==> Parameter: --vmname ", $clone_name, " --server ", Opts::get_option('server') );
                     $logger->debug( "                 --vnic 1  --username ", Opts::get_option('username'), " --password *******" );
                     $logger->debug( "                 --portgroup " . Opts::get_option('pg1') );
                     $logger->debug( "                 --log ", $logfile );
                     my @command = ( $dirs . "vmcpg.pl", "--vmname", $clone_name, "--server", Opts::get_option('server'), "--username", Opts::get_option('username'), "--password", Opts::get_option('password'), "--log", $logfile, "--vnic", "1", "--portgroup", Opts::get_option('pg1') );
                     if ( $logger->level() eq 10000 ) {
                        @command = ( @command, "--debug" );
                     }

                     $logger->info( "Change portgroup to " . Opts::get_option('pg1') . " now ..." );
                     if ( system(@command) == 0 ) {
                        $logger->info("VM $vm_name change portgroup successfully");
                     } else {
                        $logger->error("Cannot change portgroup for vm $vm_name - abort $?");
                        $retc = 41;
                     }
                  } ## end else [ if ( Opts::get_option(...))]
                  $logger->debug("Change portgroup needed for nic 2 ?");
                  if ( Opts::get_option('pg2') eq "none" ) {
                     $logger->info("No Change of portgroup needed");
                  } else {
                     $logger->info("Change portgroup needed!");
                     $logger->debug( $dirs . "vmcpg.pl" );
                     $logger->debug( "  ==> Parameter: --vmname ", $clone_name, " --server ", Opts::get_option('server') );
                     $logger->debug( "                 --vnic 2  --username ", Opts::get_option('username'), " --password *******" );
                     $logger->debug( "                 --portgroup " . Opts::get_option('pg2') );
                     $logger->debug( "                 --log ", $logfile );
                     my @command = ( $dirs . "vmcpg.pl", "--vmname", $clone_name, "--server", Opts::get_option('server'), "--username", Opts::get_option('username'), "--password", Opts::get_option('password'), "--log", $logfile, "--vnic", "2", "--portgroup", Opts::get_option('pg2') );
                     if ( $logger->level() eq 10000 ) {
                        @command = ( @command, "--debug" );
                     }

                     $logger->info( "Change portgroup to " . Opts::get_option('pg2') . " now ..." );
                     if ( system(@command) == 0 ) {
                        $logger->info("VM $vm_name change portgroup successfully");
                     } else {
                        $logger->error("Cannot change portgroup for vm $vm_name - abort $?");
                        $retc = 42;
                     }
                  } ## end else [ if ( Opts::get_option(...))]
               } ## end else [ if ($@) ]
            } ## end unless ($retc)
         } ## end if ($thost_view)
      } ## end else [ if ( !$thost_view ) ]
   } ## end foreach (@$vm_views)
} ## end if (@$vm_views)
else {
   $logger->error("No virtual machine found with name $vm_name");
   $retc = 30;
}

$logger->debug("end clone vm ");
Util::disconnect();

$logger->debug("End $prg - version $ver - rc=$retc");
exit($retc);

__END__
