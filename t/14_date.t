use strict;
use warnings;
use CGI::Header;
use HTTP::Date;
use Test::More tests => 3;
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
        "Can't assign to '-expires' directly, use accessors instead";
};
