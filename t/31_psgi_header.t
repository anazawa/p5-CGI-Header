use strict;
use warnings;
use Test::MockTime qw/set_fixed_time/;
use Test::More tests => 4;

my $now = 1349043453;
set_fixed_time( $now );

package CGI::PSGI::Extended;
use base 'CGI::PSGI';
use CGI::Header;

sub yet_another_psgi_header {
    my $self = shift;
    my @args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;

    my $header = CGI::Header->new(
        -charset => $self->charset,
        @args,
        -env => $self->env,
    );

    $header->set( 'Pragma' => 'no-cache' ) if $self->cache;

    my $status = $header->delete('Status') || '200 OK';
    $status =~ s/\D*$//;

    my @headers = $header->flatten;

    # remove the Server header
    splice @headers, 0, 2 if $header->nph;

    $status, \@headers;
}

package main;

my $env = {
    SERVER_PROTOCOL => 'HTTP/1.1',
    SERVER_SOFTWARE => 'Apache/1.3.27 (Unix)',
};

subtest 'default' => sub {
    my $cgi = CGI::PSGI::Extended->new( $env );
    is_deeply [ $cgi->yet_another_psgi_header ], [ $cgi->psgi_header ];
};

subtest 'NPH' => sub {
    my $cgi = CGI::PSGI::Extended->new( $env );
    my @args = ( -nph => 1 );
    my @got = $cgi->yet_another_psgi_header( @args );
    my @expected = $cgi->psgi_header( @args );
    is_deeply \@got, \@expected;
};

subtest 'cache()' => sub {
    my $cgi = CGI::PSGI::Extended->new( $env );
    $cgi->cache(1);
    is_deeply [ $cgi->yet_another_psgi_header ], [ $cgi->psgi_header ];
};

subtest 'charset()' => sub {
    my $cgi = CGI::PSGI::Extended->new( $env );
    $cgi->charset( 'utf-8' );
    is_deeply [ $cgi->yet_another_psgi_header ], [ $cgi->psgi_header ];
};
