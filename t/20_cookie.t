use strict;
use warnings;
use Test::More tests => 2;
use Test::Output;

package CGI::Header::Extended;
use parent 'CGI::Header';
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

is $header->cookies( ID => 123456 ), $header;
stdout_like { $header->finalize } qr{Set-Cookie: ID=123456};
