package CGI::Header::PSGI;
use strict;
use warnings;
use CGI::Header;
use Exporter 'import';

our @EXPORT_OK = qw(psgi_header psgi_redirect);

sub psgi_header {
    my $self = shift;
    my @args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;

    unshift @args, '-type' if @args == 1;

    my $header = CGI::Header->new(
        -charset => $self->charset,
        @args,
    );

    $header->set( 'Pragma' => 'no-cache' ) if $self->cache;

    my $status = $header->delete('Status') || '200';
    $status =~ s/\D*$//;

    $status, [ $header->flatten ];
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
  use CGI::Header::PSGI qw(psgi_header psgi_redirect);

=head1 DESCRIPTION

This module is a mixin class to generate PSGI response headers.

=head2 METHODS

=over 4

=item  ($status_code, $headers_aref) = $query->psgi_header

=item  ($status_code, $headers_aref) = $query->psgi_redirect

=back

=head1 SEE ALSO

L<CGI::PSGI>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
