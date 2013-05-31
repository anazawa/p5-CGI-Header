package CGI::Header::Apache2;
use strict;
use warnings;
use parent 'CGI::Header::Adapter';
use APR::Table;

sub request_rec {
    $_[0]->query->r;
}

sub finalize {
    my $self        = shift;
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
        elsif ( $field eq 'Content-length' ) {
            $request_rec->set_content_length( $value );
        }
        else {
            $headers_out->add( $field => $value );
        }
    }

    return;
}

1;

__END__

=head1 NAME

CGI::Header::Apache1 - Adapter for Apache 2 mod_perl 2.x

=head1 SYNOPSIS

  use CGI::Header::Apache2;

=head1

Adapter for Apache2 mod_perl 2.x

=head1 SEE ALSO

L<Plack::Handler::Apache2>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
