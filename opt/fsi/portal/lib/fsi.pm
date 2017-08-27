#!/usr/bin/env perl
#
#   fsi portal module
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
package fsi;
our $ver = '4.08.03 - 22.06.2017';
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
$SIG{CHLD} = 'IGNORE';
use Text::ParseWords;

use File::Basename;
use JSON;               


use Dancer2;
use Dancer2::Plugin::Ajax;
#use Dancer::Request::Upload;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 10;

use Text::CSV;

use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use DBI;
use File::Slurp;
use Template;
use Net::MAC;
use Config::General;
use File::Spec;
use File::Copy;
use File::Slurp;
use File::Path;
use Net::Ping;
use Crypt::SaltedHash;
use YAML::XS 'LoadFile';  
use XML::Simple qw(:strict);

use DateTime;
use DateTime::Format::Strptime;
use Date::Format;

use Net::LDAP;
use Net::LDAP::Util qw(ldap_error_text
                       ldap_error_name
                       ldap_error_desc
                       escape_dn_value
                       escape_filter_value
                      );

our $flvl     = 0;                                                                                                                 # function level
our $ll = " " x $flvl;
our $retc = 0;

my $rel_path = File::Spec->rel2abs(__FILE__);
our ( $volume, $dirs, $prg ) = File::Spec->splitpath($rel_path);
my $prgname = basename( $prg, '.pm' );
use Sys::Hostname;
our $host  = hostname;

use Log::Log4perl qw(:no_extra_logdie_message :levels);
use Log::Log4perl::Layout;

our %global = (
                "logprod"         => $TRACE,
                "logfile"         => $dirs . '../logs/' . $prgname,
                "logcfgfile"      => $dirs . '../etc/log4p_fsi',
                "logquietcfgfile" => $dirs . '../etc/log4p_fsi_quiet',
                "progdir"         => $dirs . '../bin',
                "toolsdir"        => $dirs . '../tools',
                "logdir"          => $dirs . '../logs',
                "sessiondir"      => $dirs . '../sessions',
                "rubbishdir"      => $dirs . '../rubbish',
                "bakdir"          => $dirs . '../../backup',
                "etcdir"          => $dirs . '../etc',
                "rcbindir"        => $dirs . '../bin/ctrl',                                                               # remote control bin dir
                "rcsysdir"        => $dirs . '../etc/sys',                                                                # remote control sys server config dir
                "templdir"        => $dirs . '../tools/template',                                                         # add server templates
                "tmpdir"          => $dirs . '../tmp',
                "symdir"          => $dirs . '../../pxe/pxelinux.cfg',
                "errmsg"          => "",
                "pingprot"        => "icmp",
                "pxeroot"         => $dirs . '../../pxe',
                "pxesysdir"       => $dirs . '../../pxe/sys',
                "pxedir"          => $dirs . '../../pxe/sys/*',
                "fsiinstdir"      => $dirs . '../../inst',
                "userxml"         => $dirs . "../etc/user.xml",
                "rzenvxml"        => $dirs . "../etc/rzenv.xml",
                "dbt_ov"          => 'entries',
                "dbt_stat"        => 'status',
                "dbt_worker"      => 'workstat', 
                "dbt_daemon"      => 'daemonstat', 
                "readtimediff"    => 5,
                "vienv"           => "unknown",
                "xeninstdir"      => "/var/fsi",
                "esxiinstdir"     => "/store/fsi",
                );

our $flash;

our %bldlvl_h;

unless ( -e $global{'rzenvxml'} ) {
   print "\n ERROR: cannot find config file for rz environment $global{'rzenvxml'} !\n\n";
   exit(102);
}
unless ( -e $global{'userxml'} ) {
   print "\n ERROR: cannot find user password file $global{'userxml'} !\n\n";
   exit(103);
}
unless ( -e $global{'logcfgfile'} ) {
   print "\n ERROR: cannot find config file for logs $global{'logcfgfile'} !\n\n";
   exit(101);
}
unless ( -e $global{'logquietcfgfile'} ) {
   print "\n ERROR: cannot find config file for logs $global{'logquietcfgfile'} !\n\n";
   exit(101);
}

my $conf = new Config::General("$global{'rzenvxml'}");
our %rzconfig = $conf->getall;


our %envconfig;
our @rzlist;
our %srlist;
our %vlanlist;
# our $srvid;                                                                                                                        # server id for job, know witch server to handle
our @markedsrv;
our @markedvm;
our $marksrvhash  = {};
our $serverhash_p = {};

our $loglevel = 0;

sub log4perl_logfile { return $global{'logfile'} }
Log::Log4perl->init($global{'logquietcfgfile'});

our $logger = Log::Log4perl::get_logger();
if ( $loglevel != 0 ) {
   $logger->level($loglevel);
}

# add functions
require "$Bin/../lib/func.pl";                                                                                                     # some general functions
require "$Bin/../lib/r_db.pl";                                                                                                     # db general functions
require "$Bin/../lib/r_flags.pl";                                                                                                  # flag functions
require "$Bin/../lib/r_task.pl";                                                                                                   # task functions
require "$Bin/../lib/r_func.pl";                                                                                                   # misc functions
require "$Bin/../lib/r_rcfunc.pl";                                                                                                 # remote control functions
require "$Bin/../lib/r_clifunc.pl";                                                                                                # cli functions
require "$Bin/../lib/r_xen.pl";                                                                                                    # xen functions

# add dancer sub routes for commands
require "$Bin/../lib/c_delsrv.pl";                                                                                                 # del server configs
require "$Bin/../lib/c_dellog.pl";                                                                                                 # del server configs
require "$Bin/../lib/c_instsrv.pl";                                                                                                # inst srv routines
require "$Bin/../lib/c_stopsrv.pl";                                                                                                # abort inst srv routines
require "$Bin/../lib/c_updsrv.pl";                                                                                                 # update server view
require "$Bin/../lib/c_ponsrv.pl";                                                                                                 # power on srv routines
require "$Bin/../lib/c_poffsrv.pl";                                                                                                # power off srv routines
require "$Bin/../lib/c_bootsrv.pl";                                                                                                # reboot srv routines
require "$Bin/../lib/c_shutdownsrv.pl";                                                                                            # shutdown srv routines
require "$Bin/../lib/c_setmaint.pl";                                                                                               # set mm mark
require "$Bin/../lib/c_exitmaint.pl";                                                                                              # mm exit mark

# add dancer sub routes
require "$Bin/../lib/s_addesxi.pl";                                                                                                # add esxi server routines
require "$Bin/../lib/s_addxen.pl";                                                                                                 # add xen server routines
require "$Bin/../lib/s_addlx.pl";                                                                                                  # add linux server routines
require "$Bin/../lib/s_admin.pl";                                                                                                  # admin routines
require "$Bin/../lib/s_ov_srv.pl";                                                                                                 # server overview routines
require "$Bin/../lib/s_ov_vc.pl";                                                                                                  # vc overview routines
require "$Bin/../lib/s_ov_xp.pl";                                                                                                  # xen pools overview routines
require "$Bin/../lib/s_ov_lx.pl";                                                                                                  # linux model overview routines
require "$Bin/../lib/s_showlog.pl";                                                                                                # show file routines
require "$Bin/../lib/s_editfile.pl";                                                                                               # edit file routines
require "$Bin/../lib/s_showvc.pl";                                                                                                 # show vc report
require "$Bin/../lib/s_showmodel.pl";                                                                                              # show lx model report
require "$Bin/../lib/s_showportallog.pl";                                                                                          # show portal log
require "$Bin/../lib/s_showsrv.pl";                                                                                                # show server detail view
require "$Bin/../lib/s_showxp.pl";                                                                                                 # show xen pool detail view
require "$Bin/../lib/s_xenvm.pl";                                                                                                  # xen vm routines
require "$Bin/../lib/a_status.pl";                                                                                                 # ajax fsi status return site
require "$Bin/../lib/s_user.pl";                                                                                                   # user
require "$Bin/../lib/s_mgmt_srs.pl";                                                                                               # manage fc lun srs in xenserver pool
require "$Bin/../lib/s_mgmt_srs-cr.pl";                                                                                            # create new lun srs
require "$Bin/../lib/s_mgmt_srs-del.pl";                                                                                           # delete existing lun srs


$logger->info("Starting $prg - version $ver");


$logger->debug(" read remote control structure config");

my %rccfg_h = ();

for my $rcsubdir (grep { -d "$global{'rcbindir'}/$_" } read_dir($global{'rcbindir'})) {
   if ( -f "$global{'rcbindir'}/$rcsubdir/rc.xml" ) {
      $logger->trace("   found rc.xml in $rcsubdir - add config");
      my $tmprcconf = new Config::General("$global{'rcbindir'}/$rcsubdir/rc.xml");
      my %tmprccfg_h = $tmprcconf->getall;
      
      for my $what (keys %{ $tmprccfg_h{'ctrl'} }) {
         $rccfg_h{'ctrl'}{$what} = $tmprccfg_h{'ctrl'}{$what};
      }
   }
}

if($global{'logprod'} < 10000) {
   my $dumpout=Dumper(\%rccfg_h);
   $logger->trace("$ll Overview-Dump: $dumpout");  
}


$logger->trace("  read esxi build level");
my @files = glob $global{'etcdir'} . '/esxi??.csv';

foreach my $file (@files){
   my $file_base = fileparse($file, qr/\.csv/);
   my $csv = Text::CSV->new({sep_char => ','});
   open (CSV, "<", $file) or die $!;
   while (<CSV>) {
       if ($csv->parse($_)) {
           my @columns = $csv->fields();
           $bldlvl_h{$file_base}{$columns[3]}{'Name'} = $columns[0];
           $bldlvl_h{$file_base}{$columns[3]}{'Version'} = $columns[1];
           $bldlvl_h{$file_base}{$columns[3]}{'Release'} = $columns[2];
       }
       else {
           my $err = $csv->error_input;
           $logger->error("Failed to parse line: $err");
           $retc=99;
       }
   }
   close CSV;
}

if($global{'logprod'} < 10000) {
   my $dumpout=Dumper(\%bldlvl_h);
   $logger->trace("Build-level-Dump: $dumpout");  
}

$logger->trace("$ll  Host name: $host");
foreach my $rz ( keys %{ $rzconfig{'rz'} } ) {
   $logger->trace("$ll  Found RZ [$rz]");
   $logger->trace("$ll  Configure fsi srv: $rzconfig{'rz'}{$rz}{'vitemp'}");
   if ( "$host" eq "$rzconfig{'rz'}{$rz}{'vitemp'}" ) {
      $logger->debug("$ll  set RZ $rz");
      $global{'vienv'} = $rz;
      last;
   }
} ## end foreach my $rz ( keys %{ $rzconfig{'rz'} } )
if ( "$global{'vienv'}" eq "unknown" ) {
   $logger->error("no RZ environment found - abort");
   print "\n no RZ environment found - abort \n";
   $retc = 2;
}

unless ($retc) {
   if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'db'}{'port'} ) {
      $global{'port'}=$rzconfig{'rz'}{$global{'vienv'}}{'db'}{'port'};
   } else {
      $global{'port'}=5432;
   }
}
   
unless ($retc) {
   if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'db'}{'name'} ) {
      $global{'fsidb'}=$rzconfig{'rz'}{$global{'vienv'}}{'db'}{'name'};
   } else {
      $logger->error(" cannot find db name in config file [$global{'rzenvxml'}]- abort");
      $logger->error(" rz: $global{'vienv'} ");
      $retc=99;
   }
}

unless ($retc) {
   if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'db'}{'usr'} ) {
      $global{'fsiusr'}=$rzconfig{'rz'}{$global{'vienv'}}{'db'}{'usr'};
   } else {
      $logger->error(" cannot find db user in config file [$global{'rzenvxml'}]- abort");
      $retc=99;
   }
}

unless ($retc) {
   if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'db'}{'pw'} ) {
      $global{'fsipw'}=$rzconfig{'rz'}{$global{'vienv'}}{'db'}{'pw'};
   } else {
      $logger->error(" cannot find db user password in config file [$global{'rzenvxml'}]- abort");
      $retc=99;
   }
}

unless ($retc) {
   if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'db'}{'host'} ) {
      $global{'fsihost'}=$rzconfig{'rz'}{$global{'vienv'}}{'db'}{'host'};
   } else {
      $logger->error(" cannot find db hostname in config file [$global{'rzenvxml'}]- abort");
      $retc=99;
   }
}

unless ($retc) {
   foreach my $licsrv ( keys %{ $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'licip'} } ) {
      if ( $licsrv ne "none" ) {
         unless ( defined $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'licip'}{$licsrv}{'port'} ) {
            $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'licip'}{$licsrv}{'port'}=27000;
         }
      }
   }
}

unless ($retc) {
   foreach my $tempipnet ( keys %{ $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'ipnet'} } ) {
      unless ( defined $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'ipnet'}{$tempipnet}{'assign'} ) {
         $logger->trace("   set assign of $tempipnet to default Managmenet");
         $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'ipnet'}{$tempipnet}{'assign'}="Management";
      }
   }
}

unless ($retc) {
   foreach my $netname ( keys %{ $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'} } ) {
      $logger->trace("  Found network: $netname");
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'assign'} ) {
         $logger->trace("   found assign bond: $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'assign'}");
      } else {
         $logger->trace("   set assign to default Managmenet");
         $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'assign'}="Management";
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'tag'} ) {
         $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'web'} = sprintf "(%4s) %-30s %-20s %s", $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'vlan'}, "$netname(*)", $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'assign'}, $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'descr'};
      } else {
         $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'web'} = sprintf "(%4s) %-30s %-20s %s", $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'vlan'}, $netname, $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'assign'}, $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'descr'};   
      }
      $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'net'}{$netname}{'web'} =~ s/ /&nbsp;/g;
   }
   foreach my $sr ( keys %{ $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'} } ) {
      $logger->trace("  Found SR: $sr");
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'tag'} ) {
         $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'web'} = sprintf "%-30s %s:%s", "$sr(*)", $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'ip'}, $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'path'};
      } else {
         $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'web'} = sprintf "%-30s %s:%s", "$sr", $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'ip'}, $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'path'};
      }
      $rzconfig{'rz'}{$global{'vienv'}}{'xensrv'}{'sr'}{$sr}{'web'} =~ s/ /&nbsp;/g;
   }
   foreach my $vsw ( keys %{ $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'} } ) {
      $logger->trace("  Found virtual switch: $vsw");  
      my ( $vs, $lb, $mtu, $nic, $descript );
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'vs'} ) {
         $vs=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'vs'};
      } else {
         $vs="0";
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'lb'} ) {
         $lb=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'lb'};
      } else {
         $lb="-";
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'mtu'} ) {
         $mtu=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'mtu'};
      } else {
         $mtu="-";
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'nics'} ) {
         $nic=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'nics'};
      } else {
         $nic="-";
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'descr'} ) {
         $descript=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'descr'};
      } else {
         $descript="-";
      }
      $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'web'} = sprintf "%-20s  %2s  %-20s  %-6s  %-50s  %s", $vsw, $vs, $lb, $mtu, $nic, $descript;
      $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vsw'}{$vsw}{'web'} =~ s/ /&nbsp;/g;
   }
   foreach my $vmnet ( keys %{ $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'} } ) {
      $logger->trace("  Found virtual machine network: $vmnet");
      my ( $sw, $cf, $vlan, $mtu, $lb, $nic, $descript );
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'sw'} ) {
         $sw=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'sw'};
      } else {
         $sw="-";
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'lb'} ) {
         $lb=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'lb'};
      } else {
         $lb="-";
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'mtu'} ) {
         $mtu=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'mtu'};
      } else {
         $mtu="-";
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'nics'} ) {
         $nic=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'nics'};
      } else {
         $nic="-";
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'cf'} ) {
         $cf=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'cf'};
      } else {
         $cf="-";
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'vlan'} ) {
         $vlan=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'vlan'};
      } else {
         $vlan="-";
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'descr'} ) {
         $descript=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'descr'};
      } else {
         $descript="-";
      }
      $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'web'} = sprintf "%-20s  %2s  %-5s  %5s  %-6s  %-20s  %-50s  %s", $vmnet, $sw, $cf, $vlan, $mtu, $lb, $nic, $descript;
      $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'vmn'}{$vmnet}{'web'} =~ s/ /&nbsp;/g;
   }
}

unless ($retc) {
   foreach my $nfsstorage ( keys %{ $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'nfs'} } ) {
      my ( $exportsrv, $pfad, $descript );
      $logger->trace("  Found nfs: $nfsstorage");
      if ( defined "$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'nfs'}{$nfsstorage}{'srv'}" ) {
         $exportsrv=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'nfs'}{$nfsstorage}{'srv'};
      } else {
         $logger->error("nfs setting for esxi need ip/dns name");
         exit 99;
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'nfs'}{$nfsstorage}{'path'} ) {
         $pfad=$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'nfs'}{$nfsstorage}{'path'};
      } else {
         $logger->error("nfs setting for esxi need path");
         exit 99;
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'nfs'}{$nfsstorage}{'descr'} ) {
         $descript="$rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'nfs'}{$nfsstorage}{'descr'}";
      } else {
         $descript="";
      }
      $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'nfs'}{$nfsstorage}{'web'} = sprintf "nfs_%-37s %-17s %-50s %s", $nfsstorage, $exportsrv, $pfad, $descript;
      $rzconfig{'rz'}{$global{'vienv'}}{'esxi'}{'nfs'}{$nfsstorage}{'web'} =~ s/ /&nbsp;/g;
   }
}

unless ($retc) {
   foreach my $nfsexport ( keys %{ $rzconfig{'rz'}{$global{'vienv'}}{'lx'}{'nfs'} } ) {
      my ( $exportsrv, $pfad, $descript );
      $logger->trace("  Found nfs export: $nfsexport");
      if ( defined "$rzconfig{'rz'}{$global{'vienv'}}{'lx'}{'nfs'}{$nfsexport}{'srv'}" ) {
         $exportsrv=$rzconfig{'rz'}{$global{'vienv'}}{'lx'}{'nfs'}{$nfsexport}{'srv'};
      } else {
         $logger->error("nfs setting for linux need ip/dns name");
         exit 99;
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'lx'}{'nfs'}{$nfsexport}{'path'} ) {
         $pfad=$rzconfig{'rz'}{$global{'vienv'}}{'lx'}{'nfs'}{$nfsexport}{'path'};
      } else {
         $logger->error("nfs setting for linux need path");
         exit 99;
      }
      if ( defined $rzconfig{'rz'}{$global{'vienv'}}{'lx'}{'nfs'}{$nfsexport}{'descr'} ) {
         $descript="$rzconfig{'rz'}{$global{'vienv'}}{'lx'}{'nfs'}{$nfsexport}{'descr'}";
      } else {
         $descript="";
      }
      $rzconfig{'rz'}{$global{'vienv'}}{'lx'}{'nfs'}{$nfsexport}{'web'} = sprintf "/mnt/%-37s %-17s %-50s %s", $nfsexport, $exportsrv, $pfad, $descript;
      $rzconfig{'rz'}{$global{'vienv'}}{'lx'}{'nfs'}{$nfsexport}{'web'} =~ s/ /&nbsp;/g;
   }
}

$logger->trace("  add remote control hash to rzconfig hash");
for my $what (keys %{ $rccfg_h{'ctrl'} }) {
   $rzconfig{'rz'}{$global{'vienv'}}{'remote'}{'ctrl'}{$what} = $rccfg_h{'ctrl'}{$what};
}

if ($global{'logprod'} < 10000) {
   my $dump=Dumper(\%rzconfig);
   $logger->trace("  rz dump: [$dump]");
}


$logger->debug(" read template config");

my %templcfg_h = ();

for my $templsubdir (grep { -d "$global{'templdir'}/$_" } read_dir($global{'templdir'})) {
   $logger->trace("   found template dir: $templsubdir");
   my ($templbase, $templname) = split('-\s*', $templsubdir);
   if ( defined $templname ) {
      $templcfg_h{'templ'}{$templbase}{$templname}={};
   } else {
      $logger->warn("  no template name define for $templsubdir - ignore");
   }
}

if ($global{'logprod'} < 10000) {
   my $dumpout=Dumper(\%templcfg_h);
   $logger->trace("$ll Template List: $dumpout");  
}

$logger->trace("  add install template hash to rzconfig hash");
for my $what (keys %{ $templcfg_h{'templ'} }) {
   $rzconfig{'rz'}{$global{'vienv'}}{'templ'}{$what} = $templcfg_h{'templ'}{$what};
}


if ($global{'logprod'} < 10000) {
   my $dump=Dumper(\%rzconfig);
   $logger->trace("  rz dump: [$dump]");
}

any qr{.*} => sub {
   if ( session('logged_in') ) {
      return redirect '/overview';
   } else {
      return redirect '/logout';
   }
};
   
if ( $global{'vienv'} eq "unknown" ) {
   $logger->error(" unknown environment - please call support team");
   exit 100;
} elsif ( $retc ) {
   $logger->error(" error [$retc] - please call support team");
   exit $retc;
} else {
   $logger->info(" Start fsi portal now");
}

true;
