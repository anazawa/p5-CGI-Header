use strict;
use warnings;
use Test::More tests => 7;

package CGI::PSGI::Extended;
use base 'CGI::PSGI';
use CGI::Header;

sub yet_another_psgi_header {
    my $self   = shift;
    my %header = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;
    my $header = CGI::Header->new(\%header, $self->env)->rehash;

    # breaks encapsulation
    $header{-charset} = $self->charset( $header{-charset} );

    $header->set( 'Pragma' => 'no-cache' ) if $self->cache;

    my $status = $header->delete('Status') || '200 OK';
    $status =~ s/\D*$//;

    if ( _status_with_no_entity_body($status) ) {
        $header->delete( $_ ) for qw( Content-Type Content-Length );
    }

    $status, [ $header->flatten ];
}

# copied from Plack::Util
sub _status_with_no_entity_body {
    my $status = shift;
    return $status < 200 || $status == 204 || $status == 304;
}

package main;

my $env = {
    SERVER_PROTOCOL => 'HTTP/1.1',
    SERVER_SOFTWARE => 'Apache/1.3.27 (Unix)',
};

{
    my $cgi = CGI::PSGI::Extended->new( $env );
    is_deeply [ $cgi->yet_another_psgi_header ], [ $cgi->psgi_header ];
}

{
    my $cgi = CGI::PSGI::Extended->new( $env );
    my @args = ( -charset => 'UTF-8' );
    my @got = $cgi->yet_another_psgi_header( @args );
    my @expected = $cgi->psgi_header( @args );
    is_deeply \@got, \@expected;
}

{
    my $cgi = CGI::PSGI::Extended->new( $env );
    my ( $status, $headers ) = $cgi->yet_another_psgi_header(
        -Status       => '304 Not Modified',
        Last_Modified => 'Sat, 07 Jul 2012 05:05:09 GMT',
    );
    is $status, 304;
    is_deeply $headers, [ 'Last-modified' => 'Sat, 07 Jul 2012 05:05:09 GMT' ];
}

{
    my $cgi = CGI::PSGI::Extended->new( $env );
    $cgi->cache(1);
    is_deeply [ $cgi->yet_another_psgi_header ], [ $cgi->psgi_header ];
}

{
    my $cgi = CGI::PSGI::Extended->new( $env );
    my ( $status, $headers ) = $cgi->yet_another_psgi_header({ NPH => 1 });
    is $status, 200;
    is_deeply $headers, [
        'Server'       => 'Apache/1.3.27 (Unix)',
        'Date'         => CGI::Util::expires(),
        'Content-Type' => 'text/html; charset=ISO-8859-1',
    ];
}
