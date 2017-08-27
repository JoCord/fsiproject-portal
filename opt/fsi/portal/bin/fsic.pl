#!/usr/bin/perl -w
#
#   fsic.pl - fsi command line
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
our $ver = '2.02.08 - 19.6.2017';
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 10;
use Text::ParseWords;
use DBI;
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Slurp;
use Template;
use Net::MAC;
use File::Basename;
use File::Spec;
use Net::Ping;
use Config::General;
use List::Util qw(max);
my $rel_path = File::Spec->rel2abs(__FILE__);
my ( $volume, $dirs, $prg ) = File::Spec->splitpath($rel_path);
our $prgname = basename( $prg, '.pl' );
use Log::Log4perl qw(:no_extra_logdie_message :levels);

use Sys::Hostname;
our $host      = hostname;
our $quietmode = "no";

our $flvl     = 0;                                                                                                                 # function level
our $ll       = " " x $flvl;
our $loglevel = 0;
my $db;
our $retc = 0;
our $flag;
our $pool        = "";
our $server      = "";
our $flagcontent = "";
our $chksrv;
our $showsrv;
our $autoreboot = "no";
our $delsrvid;
our $delsrv;
our $logtyp;
our $vmcmd;
our $taskopt   = "";
our $taskblock = "";
our %cliparm = (
                 "server"         => "",                                                                                           # server to handle
                 "pool"           => "",                                                                                           # xenserver pool to handle
               );
               
our %global = (
                "logprod"         => $DEBUG,
                "logdir"          => $dirs . '../logs',
                "logfile"         => "no",
                "logcfgfile"      => $dirs . '../etc/log4p_fsic',
                "logquietcfgfile" => $dirs . '../etc/log4p_fsic_quiet',
                "progdir"         => $dirs,
                "tmpdir"          => $dirs . '../tmp',
                "toolsdir"        => $dirs . '../tools',
                "dbschema"        => $dirs . '../etc/db.sql',
                "dbt_ov"          => 'entries',
                "dbt_stat"        => 'status',
                "dbt_worker"      => 'workstat', 
                "dbt_daemon"      => 'daemonstat', 
                "errmsg"          => "",
                "pingprot"        => "icmp",
                "rzenvxml"        => $dirs . "../etc/rzenv.xml",
                "pxeroot"         => $dirs . '../../pxe',
                "pxesysdir"       => $dirs . '../../pxe/sys',
                "pxedir"          => $dirs . '../../pxe/sys/*',
                "rcdir"           => $dirs . 'ctrl',                                                                               # remote control bin dir
                "rcsysdir"        => $dirs . '../etc/sys',                                                                         # remote control sys server config dir
                "fsiinstdir"      => $dirs . '../../inst',
                "vienv"           => "",
                "pw"              => 4123123123213,
                "xeninstdir"      => "/var/fsi",
                "esxiinstdir"     => "/store/fsi",
                "ilousr"          => "Administrator",
                "ilopw"           => "vugzu265",
                "mhf"             => "",                                                                                           # if ha detected set mhf
                "daemon"          => 0,
                );
## This is so later we can re-parse the command line args later if we need to
our @ARGS    = @ARGV;
our $numargv = @ARGS;
our $job     = "none";

## Load function files
require "$Bin/../lib/func.pl";                                                                                                     # some general functions
require "$Bin/../lib/r_rcfunc.pl";                                                                                                 # remote control functions
require "$Bin/../lib/r_cli_help.pl";                                                                                               # help
require "$Bin/../lib/r_clifunc.pl";                                                                                                # cli functions
require "$Bin/../lib/r_db.pl";                                                                                                     # db general functions
require "$Bin/../lib/r_flags.pl";                                                                                                  # flag functions
require "$Bin/../lib/r_task.pl";                                                                                                   # task functions
require "$Bin/../lib/r_cl.pl";                                                                                                     # command line function
require "$Bin/../lib/r_xen.pl";                                                                                                    # some xenserver functions

unless ( -e $global{'logcfgfile'} ) {
   print "\n ERROR: cannot find config file for logs $global{'logcfgfile'} !\n\n";
   exit(101);
}
unless ( -e $global{'logquietcfgfile'} ) {
   print "\n ERROR: cannot find config file for logs $global{'logquietcfgfile'} !\n\n";
   exit(101);
}

if ( "$global{'logfile'}" eq "no" ) {                                                                                              # kein logfile auf command line
   $global{'logfile'} = sprintf "%s../logs/%s", $dirs, $prgname;
}

sub log4p_logfile { return $global{'logfile'} }
if ( "$quietmode" eq "yes" ) {
   Log::Log4perl->init( $global{'logquietcfgfile'} );
} else {
   Log::Log4perl->init( $global{'logcfgfile'} );
}
our $logger = Log::Log4perl::get_logger();
my $go = 4123123123213;
if ( $loglevel != 0 ) {
   $logger->level($loglevel);
}

# $logger->level(10000);
# main -----------------------------------------------------------------------------------------------------------------
if ( "$job" eq "none" ) {
   help();
}
$logger->info( "$ll" . "Starting $prg - version $ver" );
$logger->debug("$ll  start detecting rz environment");

unless ( -e $global{'rzenvxml'} ) {
   $logger->error("cannot find config file for rz environment $global{'rzenvxml'}");
   exit(102);
}
my $conf = new Config::General("$global{'rzenvxml'}");
our %rzconfig = $conf->getall;
foreach my $rz ( keys %{ $rzconfig{'rz'} } ) {
   $logger->trace("$ll  Found RZ [$rz]");
   if ( "$host" eq $rzconfig{'rz'}{$rz}{'vitemp'} ) {
      $logger->debug("$ll  set RZ $rz");
      $global{'vienv'} = $rz;
      last;
   }
} ## end foreach my $rz ( keys %{ $rzconfig{'rz'} } )
if ( "$global{'vienv'}" eq "" ) {
   $logger->error("no RZ environment found - abort");
   $retc = 2;
}

unless ($retc) {
   if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'port'} ) {
      $global{'port'} = $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'port'};
   } else {
      $global{'port'} = 5432;
   }
} ## end unless ($retc)
unless ($retc) {
   if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'newport'} ) {
      $global{'newport'} = $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'newport'};
   } else {
      $global{'newport'} = 5432;
   }
} ## end unless ($retc)

unless ($retc) {
   if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'name'} ) {
      $global{'fsidb'} = $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'name'};
   } else {
      $logger->error(" cannot find db name in config file [$global{'rzenvxml'}]- abort");
      $retc = 99;
   }
} ## end unless ($retc)

unless ($retc) {
   if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'usr'} ) {
      $global{'fsiusr'} = $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'usr'};
   } else {
      $logger->error(" cannot find db user in config file [$global{'rzenvxml'}]- abort");
      $retc = 99;
   }
} ## end unless ($retc)

unless ($retc) {
   if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'pw'} ) {
      $global{'fsipw'} = $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'pw'};
   } else {
      $logger->error(" cannot find db user password in config file [$global{'rzenvxml'}]- abort");
      $retc = 99;
   }
} ## end unless ($retc)

unless ($retc) {
   if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'host'} ) {
      $global{'fsihost'} = $rzconfig{'rz'}{ $global{'vienv'} }{'db'}{'host'};
   } else {
      $logger->error(" cannot find db hostname in config file [$global{'rzenvxml'}]- abort");
      $retc = 99;
   }
} ## end unless ($retc)


unless ($retc) {
   $logger->trace("$ll  start db connect");
   $db = db_connect();
   if ( "$db" eq "undef" ) {
      $logger->error("cannot connect to db - abort");
      $retc = 99;
   } else {
      if ( "$job" eq "new" ) {
         $logger->info("$ll  delete old db table if exist and create new one");
         $retc = db_new($db);
      } elsif ( "$job" eq "chkcfg" ) {
         $retc = db_reload();
      } elsif ( "$job" eq "chkall" ) {
         $logger->info("$ll  check all xen flags");
         if ( $global{'daemon'} ) {
            $logger->info("$ll  start daemon mode");
            my $running = 1;
            while ($running) {
               set_daemon($db, "all","running");
               $retc = check_all($db);
               if ($retc) {
                  $logger->info("$ll  abort daemon mode");
                  set_daemon($db, "all","off");
                  $running = 0;
               } else {
                  my $daemon_sleep_time=5;
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'daemonsleep'} ) {
                     $daemon_sleep_time=$rzconfig{'rz'}{ $global{'vienv'} }{'daemonsleep'};
                  }
                  $logger->info("$ll sleep $daemon_sleep_time seconds");
                  set_daemon($db, "all","sleeping");
                  sleep $daemon_sleep_time;
               }
            } ## end while ($running)
         } else {
            $logger->trace("$ll  no daemon mode - run onced");
            $retc = check_all($db);
         }
      } elsif ( "$job" eq "upd" ) {
         $logger->info("$ll  update server $chksrv");
         $retc = upd_srv( $chksrv, $autoreboot );
         my $rc = check_patch_srv( $chksrv, $db );
         if ($rc) {
            $retc = $rc;
         }
      } elsif ( "$job" eq "getmac" ) {
         $logger->info("$ll  get mac from server $server");
         my $srvmac = db_get_mac($server);
         if ( $srvmac eq "" ) {
            $logger->info("$ll   cannot get mac from server $server");
         } else {
            $logger->info("$ll   server mac: $srvmac");
            if ( $quietmode eq "yes" ) {
               print "$srvmac\n";
            }
         } ## end else [ if ( $srvmac eq "" ) ]
      } elsif ( "$job" eq "getcontrol" ) {
         $logger->info("$ll  get control from server $server");
         my $srvctrl = db_get_control($server);
         if ( $srvctrl eq "" ) {
            $logger->info("$ll   cannot get control from server $server");
         } else {
            $logger->info("$ll   server control: $srvctrl");
            if ( $quietmode eq "yes" ) {
               print "$srvctrl\n";
            }
         } ## end else [ if ( $srvctrl eq "" ) ]
      } elsif ( "$job" eq "gettyp" ) {
         $logger->info("$ll  get typ from server $server");
         my $srvtyp = db_get_typ_srv($server);
         if ( $srvtyp eq "" ) {
            $logger->info("$ll   cannot get typ from server $server");
         } else {
            $logger->info("$ll   server typ: $srvtyp");
            if ( $quietmode eq "yes" ) {
               print "$srvtyp\n";
            }
         } ## end else [ if ( $srvtyp eq "" ) ]
      } elsif ( "$job" eq "taskfind" ) {
         $logger->info("$ll  find fsi task");
         my $id = task_findid( $taskopt, $taskblock );
         if ($id) {
            $logger->info("$ll  found task: $id");
            $retc = $id;
         } else {
            $logger->warn("$ll  cannot find task");
            $retc = -1;
         }
      } elsif ( "$job" eq "taskstat" ) {
         $logger->info("$ll  get fsi status");
         $retc = task_status();
      } elsif ( "$job" eq "workerlist" ) {
         $logger->info("$ll  show fsi worker list");
         $retc = worker_list();

      } elsif ( "$job" eq "tasklist" ) {
         $logger->info("$ll  show fsi task list");
         $retc = task_list();
      } elsif ( "$job" eq "vmxen" ) {
         $logger->info("$ll  xen vm task");
         $retc = vmxen($vmcmd);
      } elsif ( "$job" eq "taskadd" ) {
         $logger->info("$ll  add task to fsi task list");
         my $newid = task_add($taskopt);
         if ($newid) {
            if ( "$quietmode" eq "yes" ) {
               print $newid;
            }
            $retc = 0;
         } else {
            if ( "$quietmode" eq "yes" ) {
               print "ERROR";
            }
            $retc = 66;
         } ## end else [ if ($newid) ]
      } elsif ( "$job" eq "workeradd" ) {
         $logger->info("$ll  add worker entry to fsi worker db");
         $retc = worker_add($taskopt);
      } elsif ( "$job" eq "taskok" ) {
         $logger->info("$ll  test if task ok");
         my $taskok = task_ok($taskopt);
         if ($taskok) {
            if ( "$quietmode" eq "yes" ) {
               print "OK";
            }
            $retc = 1;
         } else {
            if ( "$quietmode" eq "yes" ) {
               print "NOT OK";
            }
            $retc = 0;
         } ## end else [ if ($taskok) ]
      } elsif ( "$job" eq "taskdel" ) {
         $logger->info("$ll  del task in fsi task list");
         $retc = task_del($taskopt);
      } elsif ( "$job" eq "workerdel" ) {
         $logger->info("$ll  del entry in fsi worker stat list");
         $retc = worker_del($taskopt);
      } elsif ( "$job" eq "setsym" ) {
         $logger->info("$ll  set symlink for server installation");
         $retc = set_sym( $db, $chksrv );
      } elsif ( "$job" eq "delsym" ) {
         $logger->info("$ll  delete symlink for server installation");
         $retc = del_sym( $db, $chksrv );
      } elsif ( "$job" eq "chkpoolrun" ) {
         $logger->info("$ll  check where pool.run dir exist");
         $retc = check_poolrun_dir($db);
      } elsif ( "$job" eq "install" ) {
         $logger->info("$ll  power on server");
         $retc = remote_control( $db, $chksrv, "poweroff" );
         sleep 3;
         unless ($retc) { $retc = remote_control( $db, $chksrv, "setnic" ); }
         unless ($retc) { $retc = set_sym( $db, $chksrv ); }
         unless ($retc) { $retc = remote_control( $db, $chksrv, "poweron" ); }
         unless ($retc) { $retc = set_flag( $db, "s_patchlevel",  $chksrv, "" ); }
         unless ($retc) { $retc = set_flag( $db, "s_patchlevels", $chksrv, "" ); }
         unless ($retc) { $retc = set_flag( $db, "s_insterr",     $chksrv, "" ); }
         unless ($retc) { $retc = set_flag( $db, "s_msg",         $chksrv, "" ); }
         unless ($retc) { $retc = set_flag( $db, "s_instrun",     $chksrv, "" ); }
         unless ($retc) { $retc = set_flag( $db, "s_block",       $chksrv, "" ); }
         unless ($retc) { $retc = set_flag( $db, "s_online",      $chksrv, "" ); }
         unless ($retc) { $retc = set_flag( $db, "s_instwait",    $chksrv, "" ); }
         unless ($retc) { $retc = set_flag( $db, "s_xenmaster",   $chksrv, "" ); }
         unless ($retc) { $retc = del_instdate( $db, $chksrv ); }
         unless ($retc) { $retc = set_instdate( $db, TimeStamp(12), $chksrv ); }
      } elsif ( "$job" eq "abort" ) {
         $logger->info("$ll  abort install server");
         $retc = remote_control( $db, $chksrv, "poweroff" );
         unless ($retc) { $retc = remote_control( $db, $chksrv, "sethd" ); }
         unless ($retc) { $retc = del_sym( $db, $chksrv ); }
         unless ($retc) { $retc = del_instdate( $db, $chksrv ); }
         unless ($retc) { $retc = set_flag( $db, "s_inststart", $chksrv, "" ); }
      } elsif ( "$job" eq "srvon" ) {
         $logger->info("$ll  power on server");
         $retc = remote_control( $db, $chksrv, "poweron" );
      } elsif ( "$job" eq "dpcd" ) {
         $logger->info("$ll  delete pool config dir [$pool]");
         $retc = del_pool_cfg_dir( $db, $pool );
      } elsif ( "$job" eq "dprd" ) {
         $logger->info("$ll  delete pool run dir [$pool]");
         $retc = del_pool_run_dir( $db, $pool );
      } elsif ( "$job" eq "haon" ) {
         $logger->info("$ll  enable ha if configure [$pool]");
         if ( check_pool_exist( $db, $pool ) ) {
            if ( check_ha_enable( $db, $pool ) ) {
               $logger->info("$ll  pool $pool ha is already enabled");
            } else {
               $logger->debug("$ll  pool ha disabled - start enable");
               $retc = hafile( $db, $pool, "enable" );
               unless ($retc) {
                  $retc = set_haon($pool);
               }
            } ## end else [ if ( check_ha_enable( $db, $pool ) ) ]
         } else {
            $logger->error("cannot find pool [$pool] in db - abort");
            $retc=99;
         }
      } elsif ( "$job" eq "haoff" ) {
         $logger->info("$ll  disable ha if configure [$pool]");
         if ( check_pool_exist( $db, $pool ) ) {
            unless ( check_ha_enable( $db, $pool ) ) {
               $logger->info("$ll  pool $pool ha is already disabled");
            } else {
               $logger->debug("$ll  pool ha enabled - start disable");
               $retc = set_haoff($pool);
               unless ($retc) {
                  $retc = hafile( $db, $pool, "disable" );
               }
            } ## end else
         } else {
            $logger->error("cannot find pool [$pool] in db - abort");
            $retc=99;
         }
      } elsif ( "$job" eq "chkha" ) {
         $logger->info("$ll  check ha for pool [$pool]");
         if ( "$pool" eq "all" ) {
            $logger->info("$ll  check all pools ha status");
            $retc = check_ha_pool_all($db);
         } else {
            $logger->info("$ll check pool $pool ha status");
            $retc = $retc = del_flag_dbcontrol( $db, "s_xenha", $pool );
            $retc = check_ha_pool( $db, $pool );
         }
      } elsif ( "$job" eq "srvoff" ) {
         $logger->info("$ll power off server");
         $retc = remote_control( $db, $chksrv, "poweroff" );
      } elsif ( "$job" eq "pooloff" ) {
         $logger->info("$ll power off pool");
         $retc = power_off_pool( $db, $pool );
      } elsif ( "$job" eq "chkmaster" ) {
         $logger->info("$ll check xen master");
         $logger->trace("$ll [$pool] ");
         if ( "$pool" eq "" ) {
            $logger->info("$ll no pool specified - check master on all pools");
            $retc = check_master($db);
         } elsif ( "$pool" eq "all" ) {
            $logger->info("$ll pool with parameter all, check master on all pools");
            $retc = check_master($db);
         } else {
            $logger->info("$ll check master only on pool $pool");
            $retc = check_master_pool( $db, $pool );
         }
      } elsif ( "$job" eq "chkonsrv" ) {
         $logger->info("$ll check if server [$chksrv] online");
         $retc = check_srvon( $db, $chksrv );
      } elsif ( "$job" eq "chkon" ) {
         $logger->info("$ll check if server online");
         if ( $global{'daemon'} ) {
            $logger->info("$ll start daemon mode");
#            $SIG{'INT'} = 'set_daemon($db, "online","off")';            
#            $SIG{'TERM'} = 'set_daemon($db, "online","off")';            
            my $running = 1;
            while ($running) {
               set_daemon($db, "online","running");
               $retc = check_on($db);
               if ($retc) {
                  set_daemon($db, "online","off");
                  $logger->info("$ll abort daemon mode");
                  $running = 0;
               } else {
                  my $daemon_sleep_time=5;
                  if ( defined $rzconfig{'rz'}{ $global{'vienv'} }{'daemonsleep'} ) {
                     $daemon_sleep_time=$rzconfig{'rz'}{ $global{'vienv'} }{'daemonsleep'};
                  }
                  $logger->info("$ll sleep $daemon_sleep_time seconds");
                  set_daemon($db, "online","sleeping");
                  sleep $daemon_sleep_time;
               }
            } ## end while ($running)
         } else {
            $logger->trace("$ll no daemon mode - run onced");
            $retc = check_on($db);
         }
      } elsif ( "$job" eq "delflag" ) {
         $logger->info("$ll del flag in db");
         $logger->trace("$ll [$server] ");
         if ( ( "$server" eq "" ) && ( "$pool" eq "" ) ) {
            $logger->info("$ll no server and pool specified - delete flag on all server");
            $retc = del_flag( $db, $flag );
         } elsif ( "$server" eq "all" ) {
            $logger->info("$ll server with parameter all, delete flag for all server");
            $retc = del_flag( $db, $flag );
         } elsif ( "$pool" ne "" ) {
            $logger->info("$ll pool specified - delete flag on pool");
            $retc = del_flag_dbcontrol( $db, $flag, $pool );
         } elsif ( "$server" ne "" ) {
            $logger->info("$ll delete flag only on server $server");
            $retc = del_flag_srv( $db, $flag, $server );
         } else {
            $logger->error("unknown error - call js");
            $retc = 99;
         }
      } elsif ( "$job" eq "setflag" ) {
         $logger->info("$ll set flag in db");
         if ( $flagcontent eq "" ) {
            $logger->error("no flag content for $flag in db entered - abort");
            $retc = 55;
         }
         unless ($retc) {
            if ( ( "$server" eq "" ) && ( "$pool" eq "" ) ) {
               $logger->info("$ll no special server given, set flag for all server");
               $retc = set_flag( $db, $flag, "all", $flagcontent );
            } elsif ( "$server" eq "all" ) {
               $logger->info("$ll server with parameter all, set flag for all server");
               $retc = set_flag( $db, $flag, "all", $flagcontent );
            } elsif ( "$pool" ne "" ) {
               $logger->info("$ll pool with name - set flag on all server in pool");
               $retc = set_flag_pool( $db, $flag, $pool, $flagcontent );
            } elsif ( "$server" ne "" ) {
               $logger->info("$ll set flag only for $server");
               $retc = set_flag( $db, $flag, $server, $flagcontent );
            } else {
               $logger->error("unknown error - call js");
               $retc = 99;
            }
         } ## end unless ($retc)
      } elsif ( "$job" eq "chkiae" ) {
         $logger->info("$ll check if alls server installation ended");
         $retc = check_iallend($db);
      } elsif ( "$job" eq "chkiend" ) {
         $logger->info("$ll check if $chksrv installation ended");
         $retc = check_instend( $chksrv, $db );
      } elsif ( "$job" eq "chkpatch" ) {
         $logger->info("$ll check $chksrv patches");
         if ( "$chksrv" eq "all" ) {
            $retc = check_patch_all($db);
         } else {
            $retc = check_patch_srv( $chksrv, $db );
         }
      } elsif ( "$job" eq "chkpatchp" ) {
         $logger->info("$ll check xen pool $chksrv patches");
         $retc = check_patch_pool( $chksrv, $db );
      } elsif ( "$job" eq "boothd" ) {
         $logger->info("$ll set hp server force boot to hd");
         $retc = remote_control( $db, $chksrv, "sethd" );
      } elsif ( "$job" eq "bootnic" ) {
         $logger->info("$ll set hp server force boot to nic");
         $retc = remote_control( $db, $chksrv, "setnic" );
      } elsif ( "$job" eq "update" ) {
         $logger->info("$ll update server liste with new one or delete old not existing server");
         $retc = db_update($db);
      } elsif ( "$job" eq "deldb" ) {
         $logger->info("$ll delete server liste");
         $retc = db_drop( $global{'dbt_ov'}, $db );
         unless ($retc) {
            $retc = db_drop( $global{'dbt_stat'}, $db );
         }
      } elsif ( "$job" eq "delsrv" ) {
         $logger->info("$ll delete server $delsrv");
         $retc = del_srv( $delsrv, $db );
      } elsif ( "$job" eq "delid" ) {
         $logger->info("$ll delete server $delsrvid");
         $retc = del_srvid( $delsrvid, $db );
      } elsif ( "$job" eq "chklog" ) {
         $logger->info("$ll check if logfiles exist for server installation");
         $retc = check_log($db);
      } elsif ( "$job" eq "sortid" ) {
         $logger->info("$ll sort server id");
         $retc = sort_srvid($db);
      } elsif ( "$job" eq "show" ) {
         $logger->info("$ll show server configs");
         $retc = show_server( $db, $showsrv );
      } elsif ( "$job" eq "xpc" ) {
         $logger->info("$ll set xen pool counter");
         $retc = set_poolcounter($db);
      } elsif ( "$job" eq "sym" ) {
         $logger->info("$ll check symlink config");
         $retc = check_syms($db);
      } else {
         $logger->warn("$ll unsupported job - abort");
      }
      if ( $retc == 1 ) {
         my $rc = db_disconnect($db);
      } elsif ($retc) {
         if ( $global{'errmsg'} ) {
            $logger->error("$global{'errmsg'}");
         } else {
            $logger->error("error - see above");
         }
      } else {
         $retc = db_disconnect($db);
      }
   } ## end else [ if ( "$db" eq "undef" ) ]
} ## end unless ($retc)

$logger->info( "$ll" . "end - rc=$retc" );
exit $retc;

__END__
