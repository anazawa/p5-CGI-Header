package CGI::Header::Simple;
use strict;
use warnings;
use base 'CGI::Header';

sub _build_query {
    require CGI::Simple::Standard;
    CGI::Simple::Standard->loader( '_cgi_object' );
}

sub clear {
    my $self = shift;
    $self->qeury->no_cache( 0 );
    $self->SUPER::clear;
}

sub SCALAR {
    my $self = shift;
    $self->query->no_cache or $self->SUPER::SCALAR;
}

sub flatten {
    my $self = shift;
    if ( $self->query->no_cache ) {
        my $header = $self->{header};
        local $header->{-expires} = 'now';
        local $header->{-pragma} = 'no-cache';
        return $self->SUPER::flatten( @_ );
    }
    $self->SUPER::flatten( @_ );
}

1;
