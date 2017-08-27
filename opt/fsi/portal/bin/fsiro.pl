#!/usr/bin/perl -w
# 
#   daemon to rename pxe symlink
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
our $ver = '1.05.02 - 23.5.2016';
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Proc::Daemon;
Proc::Daemon::Init;


use Config::General;
use English;
use File::Tail::App;

use File::Spec; 
use File::Basename;

use File::Path;
require "$Bin/../lib/func.pl";                                                                                                     # some general functions

my $continue = 1;
$SIG{TERM} = \&beende;
$SIG{INT} = \&beende;
$SIG{HUB} = \&beende;

my $rel_path = File::Spec->rel2abs( __FILE__ );
my ($volume,$dirs,$prg) = File::Spec->splitpath( $rel_path );
my $prgname = basename($prg, '.pl');

use Log::Log4perl qw(:no_extra_logdie_message);
my $conf_file = $dirs . '../etc/log4p_runonce';
my $logfile = sprintf "%s../logs/%s.log", $dirs, $prgname; 
sub log4p_logfile { return  $logfile };
Log::Log4perl->init( $conf_file );
my $logger = Log::Log4perl::get_logger();


my $pxepath=$dirs ."../../pxe/pxelinux.cfg/";


 
sub date_time {
   my $variante = $_[0];
   unless ( defined $variante ) {
      $variante = "n";
   }
   my $datetime = "";
   my ($sec, $min, $hour, $mday, $mon, $year) = localtime();

   $year += 1900;
   $mon += 1;
   $mon = $mon < 10 ? $mon = "0".$mon : $mon;
   $hour = $hour < 10 ? $hour = "0".$hour : $hour;
   $mday = $mday < 10 ? $mday = "0".$mday : $mday;
   $min = $min < 10 ? $min = "0".$min : $min;
   $sec = $sec < 10 ? $sec = "0".$sec : $sec;
   if ( $variante eq "s" ) {
      $datetime="$year$mon$mday$hour$min";   
   } else {
      $datetime="$year.$mon.$mday-$hour:$min:$sec";
   }
   return($datetime);
}

 
sub _wag_tail {
    my($line) = @_;
    
    # Jul 13 11:11:32 s0101583 in.tftpd[14702]: RRQ from 172.16.32.159 filename pxelinux.cfg/01-44-1e-a1-4f-5a-d8
    
    if ( $line =~ /in.tftpd/ ) {
      if ( $line =~ /filename pxelinux.cfg\/01/ ) {
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        $line =~ s/\n//;
        $logger->trace("conf line: [$line]");   
        $_ = $line;
        #  /((:?[a-fA-F0-9]{2}[:-]){5}[a-fA-F0-9]{2})/;
        # print "2: $1\n";
        
        my ($mac) = /((?:[0-9A-Fa-f]{2}[:-]){6}[0-9A-Fa-f]{2})/;
        
        $logger->info("-> new job for mac: $mac");
        
        my $symlink =  $pxepath . $mac;
        $logger->trace("  symlink: $symlink");
        
        if ( -e $symlink ) {
           $logger->info("  found symlink: $symlink - rename");
           my $newfile = $pxepath . $mac . "-" . TimeStamp(13);
           $logger->trace("  newfile: $newfile");
           my $rc=rename($symlink , $newfile);
           $logger->trace("  rc=$rc");
           if ( $rc ) {
              $logger->info("  rename ok");
           } else {
              $logger->error("  rename symlink: $!");
           }
        } else {
           $logger->info("  no symlink - do noting");
        }
      }  
    }
}
 
sub beende {
   my $signal=shift;
   $logger->debug("stop code: $signal");
   $logger->info("$prgname v. $ver end");
   $continue = 0;
}

# main

$logger->info("------------------------------------------------------------------");
$logger->info("$prgname v. $ver starting");
$logger->info("Init daemon ok - wait for nic connections ...");


while ($continue) {
   tail_app({
       'new'          => ['/var/log/messages'],
       'line_handler' => \&_wag_tail,
   });
}


