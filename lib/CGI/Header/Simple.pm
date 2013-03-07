package CGI::Header::Simple;
use strict;
use warnings;
use base 'CGI::Header';

sub _build_query {
    require CGI::Simple::Standard;
    CGI::Simple::Standard->loader( '_cgi_object' );
}

sub expires {
    my $self = shift;
    return $self->SUPER::expires( @_ ) unless $self->query->no_cache;
    return 'now' unless @_;
    croak $CGI::Header::MODIFY;
}

sub no_cache {
    my $self = shift;
    $self->query->no_cache(@_);
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

sub _flatten {
    my $self = shift;
    if ( $self->query->no_cache ) {
        my $clone = $self->clone;
        my $header = $clone->{header};
        $header->{-expires} = 'now';
        $header->{-pragma} = 'no-cache';
        $self = $clone;
    }
    $self->SUPER::flatten( @_ );
}

1;

__END__

=head1 NAME

CGI::Header::Simple -

=head1 SYNOPSIS

  use CGI::Simple;
  use CGI::Header::Simple;

  my $query = CGI::Simple->new;
  my $header = { -type = 'text/plain' };
  my $h = CGI::Header::Simple->new( $header, $query );

=head1 DESCRIPTION

This module is not the simplified version of L<CGI::Header>
but an adapter for L<CGI::Simple>. 

=cut
