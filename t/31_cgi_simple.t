use strict;
use warnings;
use Test::MockTime qw/set_fixed_time/;
use Test::More tests => 2;

set_fixed_time( 1341637509 );

package CGI::Simple::Header::Standalone;
use parent 'CGI::Header::Standalone';
use CGI::Simple::Util qw//;

sub _build_query {
    require CGI::Simple::Standard;
    CGI::Simple::Standard->loader('_cgi_object');
}

sub _crlf {
    $_[0]->query->crlf;
}

sub as_arrayref {
    my $self  = shift;
    my $query = $self->query;
    
    if ( $query->no_cache ) {
        $self = $self->clone->expires('now');
        unless ( $query->cache or $self->exists('Pragma') ) {
            $self->set( 'Pragma' => 'no-cache' );
        }
    }

    $self->SUPER::as_arrayref;
}

sub _bake_cookie {
    my ( $self, $cookie ) = @_;
    ref $cookie eq 'CGI::Simple::Cookie' ? $cookie->as_string : $cookie;
}

sub _date {
    my ( $self, $expires ) = @_;
    CGI::Simple::Util::expires( $expires, 'http' );
}

package main;

my $header = CGI::Simple::Header::Standalone->new;

$header->query->no_cache(1);

is_deeply $header->as_arrayref, [
    'Expires',      'Sat, 07 Jul 2012 05:05:09 GMT',
    'Date',         'Sat, 07 Jul 2012 05:05:09 GMT',
    'Pragma',       'no-cache',
    'Content-Type', 'text/html; charset=ISO-8859-1',
];

is $header->as_string, $header->query->header( $header->header );
