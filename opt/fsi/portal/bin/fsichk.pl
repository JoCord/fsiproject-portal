#!/usr/bin/perl -w
# 
#   fsichk.pl - symlink and log file check daemon
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
# close STDERR;
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Proc::Daemon;
Proc::Daemon::Init;

my $version="2.00.03 - 23.5.2016";
my $flvl     = 0;                                                                                                                  # function level

use Linux::Inotify2;
use Config::General;
use English;

use File::Spec; 
use File::Basename;
my $rel_path = File::Spec->rel2abs( __FILE__ );
my ($volume,$dirs,$prg) = File::Spec->splitpath( $rel_path );
my $prgname = basename($prg, '.pl');

use Log::Log4perl qw(:no_extra_logdie_message);
my $conf_file = $dirs . '../etc/log4p_fsichk';
my $logfile = sprintf "%s../logs/%s", $dirs, $prgname; 
sub log4p_logfile { return  $logfile };
Log::Log4perl->init( $conf_file );
my $logger = Log::Log4perl::get_logger();

my $symdir=$dirs . '../../pxe/pxelinux.cfg';


sub new_log {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;

   my $command=$dirs . "fsic.pl -q --chklog -l " . $logfile;
   $logger->trace("$ll  cmd: [$command]");
   my $eo = qx($command);
   $rc = $?;
   $logger->debug("$ll  rc=$rc");
   $rc = $rc >> 8 unless ( $rc == -1 );

   unless ($rc) {
      my $command=$dirs . "fsic.pl -q --chkiae -l " . $logfile;
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command);
      $rc = $?;
      $logger->debug("$ll  rc=$rc");
      $rc = $rc >> 8 unless ( $rc == -1 );
      unless ($rc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed chkiaecmd [$rc][$eo]");
      }
   } else {
      $logger->error("failed chklog cmd [$rc][$eo]");
   }

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
}
sub new_sym {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc = 0;

   my $command=$dirs . "fsic.pl -q --sym -l " . $logfile;

   $logger->trace("$ll  cmd: [$command]");
   my $eo = qx($command);
   $rc = $?;
   $logger->debug("$ll  rc=$rc");
   $rc = $rc >> 8 unless ( $rc == -1 );
   
   unless ($rc) {
      $logger->trace("$ll  ok");
   } else {
      $logger->error("failed cmd [$rc][$eo]");
   }

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
}


# main

$logger->info("------------------------------------------------------------------");
$logger->info("$prgname v. $version starting");

my $continue = 1;
$SIG{TERM} = sub { $continue = 0 };

my $inotify = new Linux::Inotify2 or $logger->logdie ("unable to create new inotify obejct: $!");

$logger->info(" create watch daemon for symlinks $symdir");
$inotify->watch($symdir, IN_DELETE | IN_MODIFY | IN_MOVE | IN_CREATE , sub {
   my $event = shift;
   my $name = $event->name;
   
   if ( $event->IN_MOVE ) {
      $logger->debug("move file [$name]");
      new_sym;
   } elsif ( $event->IN_MODIFY ) {
      $logger->debug("modify file [$name]");
      new_sym;
   } elsif ( $event->IN_CREATE ) {
      $logger->debug("modify file [$name]");
      new_sym;
   } elsif ( $event->IN_DELETE ) {
      $logger->debug("delete file [$name]");
      new_sym;
   } elsif ( $event->IN_Q_OVERFLOW ) {
      $logger->error("events for $name have been lost");
   }
   $logger->debug("sleep");
   sleep 5;
   
}) or $logger->logdie("watch creation failed: $!");



my @dirarray;

my $vibase=$dirs . '../../inst/';
opendir DIR, $vibase;
my @instdirs = grep { $_ =~ m/^esx|xen|co|rh/ } readdir DIR;
foreach my $instdir ( @instdirs ) {
   my $ksbase=$vibase . $instdir . "/ks/";
   $logger->trace("  dir: $ksbase");
   opendir LDIR, $ksbase;
   my @logdirs = grep { $_ =~ m/^log/ } readdir LDIR;
   foreach my $logdir ( @logdirs ) {
      my $logbase=$ksbase . $logdir;
      $logger->trace("  log dir: $logbase");
      push (@dirarray,$logbase);
   }
   closedir LDIR;
}
closedir DIR;

foreach my $logdir ( @dirarray ) {
   $logger->info(" Create log check daemon for $logdir");
   
   $inotify->watch($logdir, IN_DELETE | IN_MODIFY | IN_MOVE , sub {
      my $event = shift;
      my $name = $event->name;
      
      if ( $event->IN_MOVE ) {
         $logger->debug("move file [$name]");
         new_log;
      } elsif ( $event->IN_MODIFY ) {
         $logger->debug("modify file [$name]");
         new_log;
      } elsif ( $event->IN_DELETE ) {
         $logger->debug("delete file [$name]");
         new_log;
      } elsif ( $event->IN_Q_OVERFLOW ) {
         $logger->error("events for $name have been lost");
      }
      $logger->debug("sleep");
      sleep 5;
      
   }) or $logger->logdie("watch creation failed: $!");
}





$logger->info("Init daemon ok - waiting for new events ...");

while ($continue) {
   $inotify->poll;
}

$logger->info("$prgname v. $version end");



