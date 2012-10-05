use strict;
use warnings;

use Test::MockTime qw/set_fixed_time/;

use CGI::Header;
use Test::More tests => 19;
use Test::Warn;

set_fixed_time( 1341637509 );
my $now = 'Sat, 07 Jul 2012 05:05:09 GMT';

my %adaptee;
my $adapter = tie my %adapter, 'CGI::Header', \%adaptee;

%adaptee = ();
is $adapter{Date}, undef;
ok !exists $adapter{Date};
is delete $adapter{Date}, undef;
is_deeply \%adaptee, {};

%adaptee = ( -date => q{} );
is $adapter{Date}, q{};
ok exists $adapter{Date};
is delete $adapter{Date}, q{};
is_deeply \%adaptee, {};

%adaptee = ( -date => 'Sat, 07 Jul 2012 05:05:10 GMT' );
is $adapter{Date}, 'Sat, 07 Jul 2012 05:05:10 GMT';
ok exists $adapter{Date};
is delete $adapter{Date}, 'Sat, 07 Jul 2012 05:05:10 GMT';
is_deeply \%adaptee, {};

%adaptee = ( -nph => 1 );
is $adapter{Date}, $now;
ok exists $adapter{Date};

%adaptee = ( -nph => 0 );
is $adapter{Date}, undef;
ok !exists $adapter{Date};

%adaptee = ( -cookie => 'ID=123456; path=/' );
is $adapter{Date}, $now;
ok exists $adapter{Date};

%adaptee = ();
$adapter{Date} = 'Sat, 07 Jul 2012 05:05:09 GMT';
is_deeply \%adaptee, { -date => 'Sat, 07 Jul 2012 05:05:09 GMT' };
