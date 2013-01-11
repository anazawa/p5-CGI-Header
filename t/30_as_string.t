use strict;
use warnings;
use Test::MockTime qw/set_fixed_time/;
use CGI;
use CGI::Cookie;
use CGI::Header;
use Test::More tests => 2;

# Tests whether or not CGI::Header is compatible with CGI::header()

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
    my @args = (
        -attachment  => 'genome.jpg',
        -cookie      => [ $cookie1, $cookie2 ],
        -expires     => '+3d',
        -nph         => 1,
        -p3p         => [qw/CAP DSP LAW CURa/],
        -target      => 'ResultsWindow',
        -type        => 'text/plain',
        -ingredients => join "$CRLF ", qw/ham eggs bacon/,
    );

    my $cgi    = CGI->new;
    my $header = CGI::Header->new( @args, -charset => $cgi->charset );

    my $got      = $header->as_string( $CRLF ) . $CRLF;
    my $expected = $cgi->header( @args );

    is $got, $expected;
}

{
    local $ENV{SERVER_SOFTWARE} = 'Apache/1.3.27 (Unix)';
    local $ENV{SERVER_PROTOCOL} = 'HTTP/1.1';

    my $cgi    = CGI->new;
    my $header = CGI::Header->new( -nph => 1, -charset => $cgi->charset );

    my $got      = $header->as_string( $CRLF ) . $CRLF;
    my $expected = CGI->new->header( -nph => 1 );

    is $got, $expected;
}
