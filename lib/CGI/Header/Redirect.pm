package CGI::Header::Redirect;
use strict;
use warnings;
use base 'CGI::Header';

sub new {
    my ( $class, @args ) = @_;
}

sub as_string {
    my $self = shift;
    $self->query->redirect( $header->{header} );
}

1;
