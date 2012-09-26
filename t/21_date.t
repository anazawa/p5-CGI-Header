use strict;
use warnings;
use CGI::Header;
use HTTP::Date;
use Test::More tests => 5;
use Test::Warn;

my %adaptee;
my $adapter = tie my %adapter, 'CGI::Header', \%adaptee;

%adaptee = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
$adapter{Set_Cookie} = 'ID=123456; path=/';
is_deeply \%adaptee, { -cookie => 'ID=123456; path=/' };

subtest 'Date' => sub {
    %adaptee = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
    ok exists $adapter{Date};

    %adaptee = ();
    $adapter{Date} = 'Sat, 07 Jul 2012 05:05:09 GMT';
    is $adaptee{-date}, 'Sat, 07 Jul 2012 05:05:09 GMT';
    is $adapter{Date}, 'Sat, 07 Jul 2012 05:05:09 GMT';
};

subtest 'Expires' => sub {
    %adaptee = ( -expires => 1341637509 );
    is $adapter{Expires}, 'Sat, 07 Jul 2012 05:05:09 GMT';
    #is $adapter->expires, 'Sat, 07 Jul 2012 05:05:09 GMT';
    #ok $adapter->_date_header_is_fixed;
    is $adapter{Date}, time2str( time );
    warning_is { delete $adapter{Date} } 'The Date header is fixed';
    warning_is { $adapter{Date} = 'foo' } 'The Date header is fixed';

    %adaptee = ( -expires => q{} );
    is $adapter{Expires}, q{};
    #is $adapter{Expires}, undef;
    #ok !$adapter->_date_header_is_fixed;

    warning_is { $adapter{Expires} = '+3M' }
        "Can't assign to '-expires' directly, use expires() instead";
};

subtest 'date()' => sub {
    plan skip_all => 'obsolete';
    
    %adaptee = ();
    is $adapter->date, undef;
    my $now = 1341637509;
    $adapter->date( $now );
    is $adapter->date, $now;
    is $adaptee{-date}, 'Sat, 07 Jul 2012 05:05:09 GMT';
};

subtest 'expires()' => sub {
    %adaptee = ();
    is $adapter->expires, undef;

    %adaptee = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
    $adapter->expires( '+3M' );
    is_deeply \%adaptee, { -expires => '+3M' };

    my $now = 1341637509;
    $adapter->expires( $now );
    is $adapter->expires, $now, 'get expires()';
    is $adaptee{-expires}, $now;

    $now++;
    $adapter->expires( 'Sat, 07 Jul 2012 05:05:10 GMT' );
    #is $adapter->expires, $now, 'get expires()';
    is $adapter->expires, 'Sat, 07 Jul 2012 05:05:10 GMT';
};
