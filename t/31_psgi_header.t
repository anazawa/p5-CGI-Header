use strict;
use warnings;
use Test::MockTime qw/set_fixed_time/;
use Test::More tests => 4;

my $now = 1349043453;
set_fixed_time( $now );

package CGI::PSGI::Extended;
use base 'CGI::PSGI';
use CGI::Header::PSGI qw( psgi_header psgi_redirect );

package main;

my $env = {
    SERVER_PROTOCOL => 'HTTP/1.1',
    SERVER_SOFTWARE => 'Apache/1.3.27 (Unix)',
};

subtest 'default' => sub {
    my $cgi_psgi = CGI::PSGI->new( $env );
    my $extended = CGI::PSGI::Extended->new( $env );
    is_deeply [ $extended->psgi_header ], [ $cgi_psgi->psgi_header ];
};

subtest 'NPH' => sub {
    plan skip_all => 'not implemented yet';
    my $cgi = CGI::PSGI::Extended->new( $env );
    my @args = ( -nph => 1 );
    my @got = $cgi->yet_another_psgi_header( @args );
    my @expected = $cgi->psgi_header( @args );
    is_deeply \@got, \@expected;
};

subtest 'cache()' => sub {
    plan skip_all => 'not implemented yet';
    my $cgi = CGI::PSGI::Extended->new( $env );
    $cgi->cache(1);
    is_deeply [ $cgi->yet_another_psgi_header ], [ $cgi->psgi_header ];
};

subtest 'charset()' => sub {
    plan skip_all => 'not implemented yet';
    my $cgi = CGI::PSGI::Extended->new( $env );
    $cgi->charset( 'utf-8' );
    is_deeply [ $cgi->yet_another_psgi_header ], [ $cgi->psgi_header ];
};
