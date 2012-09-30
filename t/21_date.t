use strict;
use warnings;
use CGI::Header;
use HTTP::Date;
use Test::More tests => 20;
use Test::Warn;

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

%adaptee = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
is $adapter{Date}, 'Sat, 07 Jul 2012 05:05:09 GMT';
ok exists $adapter{Date};
is delete $adapter{Date}, 'Sat, 07 Jul 2012 05:05:09 GMT';
is_deeply \%adaptee, {};

%adaptee = ( -nph => 1 );
is $adapter{Date}, time2str();
ok exists $adapter{Date};

%adaptee = ( -nph => 0 );
is $adapter{Date}, undef;
ok !exists $adapter{Date};

%adaptee = ( -cookie => 'ID=123456; path=/' );
is $adapter{Date}, time2str();
ok exists $adapter{Date};

%adaptee = ();
$adapter{Date} = 'Sat, 07 Jul 2012 05:05:09 GMT';
is $adaptee{-date}, 'Sat, 07 Jul 2012 05:05:09 GMT';

subtest '-expires' => sub {
    %adaptee = ( -expires => 1341637509 );
    is $adapter{Expires}, 'Sat, 07 Jul 2012 05:05:09 GMT';
    is $adapter->expires, 1341637509;
    is $adapter{Date}, time2str( time );
    #warning_is { delete $adapter{Date} } 'The Date header is fixed';
    #warning_is { $adapter{Date} = 'foo' } 'The Date header is fixed';

    %adaptee = ( -expires => q{} );
    is $adapter{Expires}, q{};

    #warning_is { $adapter{Expires} = '+3M' }
    #    "Can't assign to '-expires' directly, use expires() instead";

    %adaptee = ();
    is $adapter{Expires}, undef;
    is $adapter->expires, undef;

    %adaptee = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
    $adapter->expires( '+3M' );
    is_deeply \%adaptee, { -expires => '+3M' };

    my $now = 1341637509;
    $adapter->expires( $now );
    is $adapter->expires, $now, 'get expires()';
    is $adaptee{-expires}, $now;
};
