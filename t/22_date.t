use strict;
use warnings;
use CGI::Header;
use Test::More tests => 2;

my %header;
my $header = CGI::Header->new( \%header );

subtest 'date()' => sub {
    %header = ();
    is $header->date, undef;
    my $now = 1341637509;
    $header->date( $now );
    is $header->date, $now;
    is $header{-date}, 'Sat, 07 Jul 2012 05:05:09 GMT';
};

subtest 'expires()' => sub {
    %header = ();
    is $header->expires, undef;

    %header = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
    $header->expires( '+3M' );
    is_deeply \%header, { -expires => '+3M' };

    my $now = 1341637509;
    $header->expires( $now );
    is $header->expires, $now, 'get expires()';
    is $header{-expires}, $now;

    #$now++;
    #$header->expires( 'Sat, 07 Jul 2012 05:05:10 GMT' );
    #is $header->expires, $now, 'get expires()';
    #is $header{-expires}, 'Sat, 07 Jul 2012 05:05:10 GMT';
};
