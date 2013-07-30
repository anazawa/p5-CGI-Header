package CGI::Header::Extended;
use strict;
use warnings;
use parent 'CGI::Header';

sub merge {
    my ( $self, @args ) = @_;

    if ( @args == 1 ) {
        my %header = %{ $args[0] };
        my $header = $self->header;
        ref( $self )->new( header => \%header ); # rehash %header
        %$header = ( %$header, %header );
    }
    else {
        while ( my ($key, $value) = splice @args, 0, 2 ) {
            $self->set( $key => $value );
        }
    }

    $self;
}

sub replace {
    my $self = shift;
    $self->clear->merge(@_);
}

1;
