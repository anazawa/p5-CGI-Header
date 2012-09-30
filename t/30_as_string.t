use strict;
use warnings;

use Test::MockTime qw/set_fixed_time/;

use CGI;
use CGI::Cookie;
use CGI::Header;
use Test::More tests => 2;

my $now = 1349043453;
set_fixed_time( $now );

my $CRLF = $CGI::CRLF;

my $cookie1 = CGI::Cookie->new(
    -name  => 'foo',
    -value => 'bar',
);

my $cookie2 = CGI::Cookie->new(
    -name  => 'bar',
    -value => 'baz',
);

{
    my $header = CGI::Header->new(
        -attachment => 'genome.jpg',
        -charset    => 'utf-8',
        -cookie     => [ $cookie1, $cookie2 ],
        -expires    => '+3d',
        -nph        => 1,
        -p3p        => [qw/CAP DSP LAW CURa/],
        -target     => 'ResultsWindow',
        -type       => 'text/plain',
    );

    $header->set( Ingredients => join "$CRLF ", qw(ham eggs bacon) );

    my $got      = $header->as_string( $CRLF ) . $CRLF;
    my $expected = CGI->new->header( $header->header );

    is $got, $expected;
}

{
    local $ENV{SERVER_SOFTWARE} = 'Apache/1.3.27 (Unix)';
    local $ENV{SERVER_PROTOCOL} = 'HTTP/1.1';

    my $header   = CGI::Header->new( -nph => 1 );
    my $got      = $header->as_string( $CRLF ) . $CRLF;
    my $expected = CGI->new->header( $header->header );

    is $got, $expected;
}
