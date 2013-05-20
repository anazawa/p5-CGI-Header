package CGI::Header::Standalone::Apache2;
use strict;
use warnings;
use parent 'CGI::Header::Standalone';

sub finalize {
    my $self        = shift;
    my $headers     = $self->as_arrayref;
    my $r           = $self->query->r;
    my $headers_out = $r->headers_out;  

    for ( my $i = 0; $i < @$headers; $i += 2 ) {
        my $field = $headers->[$i];
        my $value = $self->_process_newline( $headers->[$i+1] );

        if ( $field eq 'Content-Type' ) {
            $r->content_type( $value );
        }
        elsif ( $field eq 'Content-length' ) {
            $r->set_content_length( $value );
        }
        else {
            $headers_out->add( $field => $value );
        }
    }

    q{};
}

1;
