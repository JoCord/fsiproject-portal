#!/usr/bin/perl -w
#
#   fsi psgi start file
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
our $ver = '4.03.01 - 19.5.2016';
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use fsi;
#my $app = fsi->to_app;

#use Plack::Builder;
#use Dancer2::Debugger;
#my $debugger = Dancer2::Debugger->new;
#
#
#builder {
#   enable 'Deflater';
#   enable 'Session', store => 'File';
#   enable 'Debug';
#   enable 'Debug', panels => [ qw<DBITrace Memory Timer> , [ 'Ajax',log_limit => 100,]];
#   enable 'Debug::TraceENV', method => [qw/store delete/]; # just enable STORE and DELETE methods
#   fsi->to_app;
#};
#
#builder {
#    $debugger->mount;
#    mount '/' => builder {
#        $debugger->enable;
#        fsi->to_app;
#    }
#};


#$app;
fsi->to_app;