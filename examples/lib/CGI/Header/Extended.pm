package CGI::Header::Extended;
use strict;
use warnings;
use parent 'CGI::Header';

sub merge {
    my ( $self, @args ) = @_;

    if ( @args == 1 ) {
        my %other = %{ $args[0] };
        my $header = $self->header;
        ref( $self )->new( header => \%other ); # rehash %other
        %$header = ( %$header, %other );
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
