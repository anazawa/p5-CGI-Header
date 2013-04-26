package CGI::Header::Standalone;
use strict;
use warnings;
use parent 'CGI::Header';
use Carp qw/croak/;

sub as_arrayref {
    my $self   = shift;
    my $query  = $self->query;
    my %header = %{ $self->header };
    my $nph    = delete $header{nph} || $query->nph;

    my @headers;

    my ( $attachment, $charset, $cookies, $expires, $p3p, $status, $target, $type )
        = delete @header{qw/attachment charset cookies expires p3p status target type/};

    push @headers, 'Server', $query->server_software if $nph;
    push @headers, 'Status', $status        if $status;
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

sub as_string {
    my $self    = shift;
    my $headers = $self->as_arrayref;
    my $query   = $self->query;
    my $crlf    = $self->_crlf;

    my @lines;

    if ( $self->nph or $query->nph ) {
        my $protocol = $query->server_protocol;
        my $status   = $self->status || '200 OK';
        push @lines, "$protocol $status";
    }

    # CR escaping for values, per RFC 822
    while ( my ($field, $value) = splice @$headers, 0, 2 ) {
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

        push @lines, "$field: $value";
    }

    push @lines, q{}; # add an empty line

    join $crlf, @lines, q{};
}

sub _crlf {
    $CGI::CRLF;
}

1;
