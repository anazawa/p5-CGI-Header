package CGI::Header::Extended;
use strict;
use warnings;
use parent 'CGI::Header';

sub merge {
    my ( $self, @args ) = @_;

    if ( @args == 1 ) {
        my $header = $self->header;
        my $other = ref( $self )->new( header => { %{$args[0]} } );
        %$header = ( %$header, %{ $other->header } );
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
