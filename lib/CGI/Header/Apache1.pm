package CGI::Header::Apache1;
use strict;
use warnings;
use parent 'CGI::Header::Adapter';

sub finalize {
    my $self = shift;

    return $self->as_string if $self->nph;

    my $headers     = $self->as_arrayref;
    my $request_rec = $self->request_rec;

    my $status = $self->status || '200';
       $status =~ s/\D*$//;

    my $headers_out = $status >= 200 && $status < 300 ? 'headers_out' : 'err_headers_out';  
       $headers_out = $request_rec->$headers_out;

    $request_rec->status( $status );

    for ( my $i = 0; $i < @$headers; $i += 2 ) {
        my $field = $headers->[$i];
        my $value = $self->process_newline( $headers->[$i+1] );

        if ( $field eq 'Content-Type' ) {
            $request_rec->content_type( $value );
        }
        else {
            $headers_out->add( $field => $value );
        }
    }

    $request_rec->send_http_header;

    q{};
}

sub request_rec {
    $_[0]->query->r;
}

1;
