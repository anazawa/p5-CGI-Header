package CGI::Header::Apache2;
use strict;
use warnings;
use parent 'CGI::Header::Standalone';

my %handler = (
    'Content-length' => 'set_content_length',
    'Content-Type'   => 'content_type',
    'Status'         => 'status_line',
);

sub finalize {
    my $self  = shift;
    my $query = $self->query;

    return $self->as_string if $self->nph or $query->nph;

    my $r           = $query->r;
    my $headers_out = $r->headers_out;  
    my $headers     = $self->as_arrayref;

    for ( my $i = 0; $i < @$headers; $i += 2 ) {
        my $field = $headers->[$i];
        my $value = $self->_process_newline( $headers->[$i+1] );

        if ( my $handler = $handler{$field} ) {
            $r->$handler( $value );
        }
        else {
            $headers_out->add( $field => $value );
        }
    }

    q{};
}

1;
