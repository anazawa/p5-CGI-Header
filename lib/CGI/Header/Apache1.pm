package CGI::Header::Apache1;
use strict;
use warnings;
use parent 'CGI::Header::Standalone';

sub finalize {
    my $self = shift;

    return $self->as_string if $self->nph or $self->query->nph;

    my $headers     = $self->as_arrayref;
    my $request_rec = $self->_request_rec;
    
    my $status = $self->status || '200';
       $status =~ s/\D*$//;

    my $headers_out = $status >= 200 && $status < 300 ? 'headers_out' : 'err_headers_out';  
       $headers_out = $request_rec->$headers_out;

    $request_rec->status( $status );

    for ( my $i = 0; $i < @$headers; $i += 2 ) {
        my $field = $headers->[$i];
        my $value = $self->_process_newline( $headers->[$i+1] );

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

sub _request_rec {
    $_[0]->query->r;
}

1;

__END__

=head1 NAME

CGI::Header::Apache2 - Adapter for Apache 2.0 mod_perl

=head1 SYNOPSIS

  use CGI::Header::Apache2;
  my $h = CGI::Header::Apache2->new;
  $h->finalize;

=head1 DESCRIPTION

This class inherits from L<CGI::Header::Standalone>, and also overrides
the C<finalize> method to adapt for Apache 2.0 L<mod_perl>.
The C<finalize> method updates L<Apache2::RequestRec> object (C<$r>)
and returns an empty string instead of the formatted response headers.
Unlike CGI.pm's C<header> method, this module doesn't depend on
L<Apache2::Response>'s C<send_cgi_header> method, and so you can send
headers effectively.

=head1 SEE ALSO

L<CGI::Header::PSGI>, L<Plack::Handler::Apache2>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
