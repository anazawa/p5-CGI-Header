package CGI::Header::PSGI;
use strict;
use warnings;
use CGI::Header;
use Carp qw/croak/;
use Exporter 'import';

our @EXPORT_OK = qw( psgi_header psgi_redirect );

sub psgi_header {
    my $self = shift;
    my @args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;
    my $crlf = $self->crlf;

    unshift @args, '-type' if @args == 1;

    my $header = CGI::Header->new(
        -charset => $self->charset,
        @args,
    );

    $self->charset( $header->header->{-charset} ); # "side effect"

    $header->nph( 0 ); # NPH scripts don't depend on this method.

    # Remove the Status header as per PSGI spec.
    my $status = $header->delete('Status') || '200';
       $status =~ s/\D*$//;

    # See Plack::Util::status_with_no_entity_body()
    if ( $status < 200 || $status == 204 || $status == 304 ) {
        $header->delete( $_ ) for qw( Content-Type Content-Length );
    }

    my @headers;
    $header->each(sub {
        my ( $field, $value ) = @_;

        # From RFC 822:
        # Unfolding is accomplished by regarding CRLF immediately
        # followed by a LWSP-char as equivalent to the LWSP-char.
        $value =~ s/$crlf(\s)/$1/g;

        # All other uses of newlines are invalid input.
        if ( $value =~ /$crlf|\015|\012/ ) {
            # shorten very long values in the diagnostic
            $value = substr($value, 0, 72) . '...' if length $value > 72;
            croak "Invalid header value contains a newline not followed by whitespace: $value";
        }

        push @headers, $field, $value;
    });

    push @headers, 'Pragma', 'no-cache' if $self->cache;

    return $status, \@headers;
}

sub psgi_redirect {
    my $self = shift;
    my @args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;

    unshift @args, '-location' if @args == 1;

    return $self->psgi_header(
        -location => $self->url,
        -status => '302',
        -type => q{},
        @args,
    );
}

1;

__END__

=head1 NAME

CGI::Header::PSGI - Mixin to generate PSGI response headers

=head1 SYNOPSIS

  use parent 'CGI';
  use CGI::Header::PSGI qw( psgi_header psgi_redirect );

  sub crlf { $CGI::CRLF }

=head1 DESCRIPTION

This module is a mixin class to generate PSGI response headers.

=head2 REQUIRED METHODS

Your class has to implement the following methods.

=over 4

=item $query->charset

Get or set the character set sent to the browser.

=item $query->url

Returns the script's URL.

=item $query->cache

=item $query->crlf

Returns the system specific line ending sequence.
If your class inherits from L<CGI>, you have to add this method by yourself.
On the other hand, L<CGI::Simple> has this attribute by default,
and so you don't have to do so.

=back

=head2 METHODS

By using this module, your class is capable of following methods.

=over 4

=item ($status_code, $headers_aref) = $query->psgi_header( %args )

Works like CGI.pm's C<header()>, but the return format is modified.
It returns an array with the status code and arrayref of header pairs
that PSGI requires.

=item ($status_code, $headers_aref) = $query->psgi_redirect( %args )

Works like CGI.pm's C<redirect()>, but the return format is modified.
It returns an array with the status code and arrayref of header pairs
that PSGI requires.

=back

=head1 SEE ALSO

L<CGI::PSGI>, L<CGI::Emulate::PSGI>, L<CGI::Simple>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
