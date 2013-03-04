use strict;
use warnings;
use Test::MockTime qw/set_fixed_time/;
use CGI;
use CGI::Cookie;
use CGI::Header;
use Test::More skip_all => 'CGI::Header#as_string invokes CGI#header directly';

my $now = 1349043453;
set_fixed_time( $now );

my $CRLF = $CGI::CRLF;

my $cookie1 = CGI::Cookie->new( -name => 'foo', -value => 'bar' );
my $cookie2 = CGI::Cookie->new( -name => 'bar', -value => 'baz' );

subtest 'basic' => sub {
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
};

subtest 'NPH' => sub {
    local $ENV{SERVER_SOFTWARE} = 'Apache/1.3.27 (Unix)';
    local $ENV{SERVER_PROTOCOL} = 'HTTP/1.1';

    my $cgi    = CGI->new;
    my $header = CGI::Header->new( -nph => 1, -charset => $cgi->charset );

    my $got      = $header->as_string( $CRLF ) . $CRLF;
    my $expected = $cgi->header( -nph => 1 );

    is $got, $expected;
};

subtest 'cache()' => sub {
    my $cgi    = CGI->new;
    my $header = CGI::Header->new( -charset => $cgi->charset );

    $cgi->cache(1);
    $header->set( 'Pragma' => 'no-cache' );

    my $got      = $header->as_string( $CRLF ) . $CRLF;
    my $expected = $cgi->header;

    is $got, $expected;
};

subtest 'charset()' => sub {
    my $cgi    = CGI->new;
    my $header = CGI::Header->new( -charset => 'utf-8' );

    $cgi->charset( 'utf-8' );

    my $got      = $header->as_string( $CRLF ) . $CRLF;
    my $expected = $cgi->header;

    is $got, $expected;
};
