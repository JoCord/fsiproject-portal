#!/usr/bin/perl -w
#
#   vctestconnect.pl - test connection to virtual center
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

my $retc = 0;

use File::Spec;
use File::Basename;
my $rel_path = File::Spec->rel2abs(__FILE__);
my ( $volume, $dirs, $prg ) = File::Spec->splitpath($rel_path);
my $prgname = basename( $prg, '.pl' );

my %opts = (

);

Opts::add_options(%opts);

Opts::parse();
Opts::validate();

print "\n Connect ...";
Util::connect();
print " done ?";

print "\n VirtualMachine suchen\n";
my $vm_views = Vim::find_entity_views( view_type => 'VirtualMachine');


print "\n Hosts suchen\n";
my $thost_view = Vim::find_entity_view( view_type => 'HostSystem' );

print Dumper(\$vm_views);
print Dumper(\$thost_view);

exit($retc);

__END__
