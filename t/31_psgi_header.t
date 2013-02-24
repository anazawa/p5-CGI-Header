use strict;
use warnings;
use Test::MockTime qw/set_fixed_time/;
#use Test::More tests => 5;
use Test::More skip_all => 'this test itself is unstable';


my $now = 1349043453;
set_fixed_time( $now );

package CGI::PSGI::Extended;
use base 'CGI::PSGI';
use CGI::Header::PSGI qw(psgi_header psgi_redirect);

sub crlf { $CGI::CRLF }

package main;

my $env = {
    SERVER_PROTOCOL => 'HTTP/1.1',
    SERVER_SOFTWARE => 'Apache/1.3.27 (Unix)',
};

subtest 'basic' => sub {
    my $query = CGI::PSGI::Extended->new( $env );

    my @expected = ( 'Content-Type', 'text/html; charset=ISO-8859-1' );
    is_deeply [ $query->psgi_header ], [ 200, \@expected ];

    my @got = $query->psgi_header(
        -status => '304 Not Modified',
        -etag   => 'Foo',
    );
    is_deeply \@got, [ 304, ['Etag', 'Foo'] ];
};

subtest 'default' => sub {
    my $got = CGI::PSGI::Extended->new( $env );
    my $expected = CGI::PSGI->new( $env );
    is_deeply [ $got->psgi_header ], [ $expected->psgi_header ];
};

subtest 'cache()' => sub {
    my $query = CGI::PSGI::Extended->new( $env );
    $query->cache(1);

    my @expected = (
        'Content-Type', 'text/html; charset=ISO-8859-1',
        'Pragma',       'no-cache',
    );

    is_deeply [ $query->psgi_header ], [ 200, \@expected ];
};

subtest 'charset()' => sub {
    my $expected = CGI::PSGI->new( $env );
    my $got = CGI::PSGI::Extended->new( $env );
    $expected->charset( 'utf-8' );
    $got->charset( 'utf-8' );
    is_deeply [ $got->psgi_header ], [ $expected->psgi_header ];
};

subtest 'psgi_redirect()' => sub {
    my $query = CGI::PSGI::Extended->new( $env );
    my $url = 'http://localhost/';
    my @expected = ( 'Location', $url );
    is_deeply [ $query->psgi_redirect($url) ], [ 302, \@expected ];
};
