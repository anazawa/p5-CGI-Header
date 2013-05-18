use strict;
use warnings;
use Test::More tests => 1;

package CGI::Header::Extended;
use base 'CGI::Header';
use CGI::Cookie;

sub cookies {
    my $self    = shift;
    my $cookies = $self->header->{cookies} ||= [];

    return $cookies unless @_;

    if ( ref $_[0] eq 'HASH' ) {
        push @$cookies, map { CGI::Cookie->new($_) } @_;
    }
    else {
        push @$cookies, CGI::Cookie->new( @_ );
    }

    $self;
}

package main;

my $header = CGI::Header::Extended->new;

$header->cookies( ID => 123456 );

like $header->as_string, qr{Set-Cookie: ID=123456};
