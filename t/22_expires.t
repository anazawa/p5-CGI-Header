use strict;
use warnings;

use Test::MockTime qw/set_fixed_time/;

use CGI::Header;
use Test::More tests => 20;
use Test::Warn;

set_fixed_time( 1341637509 );
my $now = 'Sat, 07 Jul 2012 05:05:09 GMT';

my %adaptee;
my $adapter = tie my %adapter, 'CGI::Header', \%adaptee;

%adaptee = ();
ok !exists $adapter{Expires};
is $adapter{Expires}, undef;
is $adapter->expires, undef;
is delete $adapter{Expires}, undef;
is_deeply \%adaptee, {};

%adaptee = ( -expires => '+3d' );
ok exists $adapter{Expires};
ok exists $adapter{Date};
is $adapter{Expires}, 'Tue, 10 Jul 2012 05:05:09 GMT';
is $adapter{Date}, $now;
is $adapter->expires, '+3d';
is delete $adapter{Expires}, 'Tue, 10 Jul 2012 05:05:09 GMT';
is_deeply \%adaptee, {};

#warning_is { delete $adapter{Date} } 'The Date header is fixed';
#warning_is { $adapter{Date} = 'foo' } 'The Date header is fixed';

%adaptee = ( -expires => q{} );
ok exists $adapter{Expires};
ok !exists $adapter{Date};
is $adapter{Expires}, q{};
is $adapter{Date}, undef;
is $adapter->expires, q{};
is delete $adapter{Expires}, q{};
is_deeply \%adaptee, {};

#%adaptee = ( -expires => 0 );

# Follows the rule of least surprize.
# The following behavior will surprize us :)
#
#   $adapter{Expires} = '+3d';
#   my $value = $adapter{Expires}; # => 'Tue, 10 Jul 2012 05:05:09 GMT'
#

warning_is { $adapter{Expires} = '+3d' }
    "Can't assign to '-expires' directly, use expires() instead";

%adaptee = ();
$adapter->expires( '+3d' );
is_deeply \%adaptee, { -expires => '+3d' };

%adaptee = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
$adapter->expires( '+3d' );
is_deeply \%adaptee, { -expires => '+3d' };

