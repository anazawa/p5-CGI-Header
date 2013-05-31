package CGI::Header::Standalone;
use strict;
use warnings;
use parent 'CGI::Header';
use Carp qw/croak/;

sub finalize {
    my $self     = shift;
    my $query    = $self->query;
    my $mod_perl = $self->_mod_perl;

    if ( !$mod_perl or $self->nph or $query->nph ) {
        return $query->print( $self->as_string );
    }

    require APR::Table if $mod_perl == 2;

    my $status_line = $self->status || '200 OK';
    my $headers     = $self->as_arrayref;
    my $request_rec = $self->_request_rec;

    my $status = $status_line;
       $status =~ s/\D*$//;

    my $headers_out = $status >= 200 && $status < 300 ? 'headers_out' : 'err_headers_out';  
       $headers_out = $request_rec->$headers_out;

    $request_rec->status_line( $status_line );

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

    $request_rec->send_http_header if $mod_perl == 1;

    1;
}

sub _mod_perl {
    $CGI::MOD_PERL;
}

sub _request_rec {
    $_[0]->query->r;
}

sub as_string {
    my $self    = shift;
    my $query   = $self->query;
    my $crlf    = $self->_crlf; # CGI.pm should be loaded
    my $headers = $self->as_arrayref;

    my @lines;

    # add Status-Line required by NPH scripts
    if ( $self->nph or $query->nph ) {
        my $protocol = $query->server_protocol;
        my $status = $self->_process_newline( $self->status || '200 OK' );
        push @lines, "$protocol $status$crlf";
    }

    # add response headers
    for ( my $i = 0; $i < @$headers; $i += 2 ) {
        my $field = $headers->[$i];
        my $value = $self->_process_newline( $headers->[$i+1] );
        push @lines, "$field: $value$crlf";
    }

    push @lines, $crlf; # add an empty line

    join q{}, @lines;
}

sub _process_newline {
    my $self  = shift;
    my $value = shift;
    my $crlf  = $self->_crlf;

    # CR escaping for values, per RFC 822:
    # > Unfolding is accomplished by regarding CRLF immediately
    # > followed by a LWSP-char as equivalent to the LWSP-char.
    $value =~ s/$crlf(\s)/$1/g;

    # All other uses of newlines are invalid input.
    if ( $value =~ /$crlf|\015|\012/ ) {
        # shorten very long values in the diagnostic
        $value = substr($value, 0, 72) . '...' if length $value > 72;
        croak "Invalid header value contains a newline not followed by whitespace: $value";
    }

    $value;
}

sub _crlf {
    $CGI::CRLF;
}

sub as_arrayref {
    my $self   = shift;
    my $query  = $self->query;
    my %header = %{ $self->header };
    my $nph    = delete $header{nph} || $query->nph;

    my ( $attachment, $charset, $cookies, $expires, $p3p, $status, $target, $type )
        = delete @header{qw/attachment charset cookies expires p3p status target type/};

    my @headers;

    push @headers, 'Server', $query->server_software if $nph;
    push @headers, 'Status', $status if $status;
    push @headers, 'Window-Target', $target if $target;

    if ( $p3p ) {
        my $tags = ref $p3p eq 'ARRAY' ? join ' ', @{$p3p} : $p3p;
        push @headers, 'P3P', qq{policyref="/w3c/p3p.xml", CP="$tags"};
    }

    my @cookies = ref $cookies eq 'ARRAY' ? @{$cookies} : $cookies;
       @cookies = map { $self->_bake_cookie($_) || () } @cookies;

    push @headers, map { ('Set-Cookie', $_) } @cookies;
    push @headers, 'Expires', $self->_date($expires) if $expires;
    push @headers, 'Date', $self->_date if $expires or @cookies or $nph;
    push @headers, 'Pragma', 'no-cache' if $query->cache;

    if ( $attachment ) {
        my $value = qq{attachment; filename="$attachment"};
        push @headers, 'Content-Disposition', $value;
    }

    push @headers, map { ucfirst $_, $header{$_} } keys %header;

    unless ( defined $type and $type eq q{} ) {
        my $value = $type || 'text/html';
        $charset = $query->charset if !defined $charset;
        $value .= "; charset=$charset" if $charset && $value !~ /\bcharset\b/;
        push @headers, 'Content-Type', $value;
    }

    \@headers;
}

sub _bake_cookie {
    my ( $self, $cookie ) = @_;
    ref $cookie eq 'CGI::Cookie' ? $cookie->as_string : $cookie;
}

sub _date {
    my ( $self, $expires ) = @_;
    CGI::Util::expires( $expires, 'http' );
}

1;

__END__

=head1 NAME

CGI::Header::Standalone - Alternative to CGI::Header

=head1 SYNOPSIS

  use CGI::Header::Standalone;
  my $h = CGI::Header::Standalone->new; # behaves like CGI::Header object

=head1 DESCRIPTION

This module inherits from L<CGI::Header>, and also adds the following methods
to the class:

=over 4

=item $headers = $header->as_arrayref

Returns an arrayref which contains key-value pairs of HTTP headers.

  $header->as_arrayref;
  # => [
  #     'Content-length' => '3002',
  #     'Content-Type'   => 'text/plain',
  # ]

This method helps you write an adapter for L<mod_perl> or a L<PSGI>
application which wraps your CGI.pm-based application without parsing
the return value of CGI.pm's C<header> method.

=item $header->as_string

Return the header fields as a formatted MIME header.
If the C<nph> property is set to true, the Status-Line is inserted to
the beginning of the response headers.

=back

This module overrides the following method of the superclass:

=over 4

=item $header->finalize

Behaves like CGI.pm's C<header> method.
In L<mod_perl> environment, unlike CGI.pm's C<header> method,
this method updates "headers_out" method of C<request_rec> object directly,
and so you can send headers effectively.

=back

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
