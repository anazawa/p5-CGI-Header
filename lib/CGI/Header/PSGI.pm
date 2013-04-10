package CGI::Header::PSGI;
use strict;
use warnings;
use base 'CGI::Header';
use Carp qw/croak/;

our $VERSION = '0.06';

sub new {
    my $class  = shift;
    my $self   = $class->SUPER::new( @_ )->rehash;
    my $header = $self->header;

    if ( exists $header->{status} ) {
        my $status = delete $header->{status};
        $self->{status} = $status if !exists $self->{status};
    }

    $self;
}

sub status {
    my $self = shift;
    return $self->{status} unless @_;
    $self->{status} = shift;
    $self;
}

sub status_code {
    my $self = shift;
    my $code = $self->{status};
    $code = '302' if $self->{handler} eq 'redirect' and !defined $code;
    $code = '200' if !$code;
    $code =~ s/\D*$//;
    $code;
}

sub crlf {
    $CGI::CRLF;
}

sub as_arrayref {
    my $self  = shift;
    my $crlf  = $self->crlf;
    my $query = $self->query;
    my %copy  = %{ $self->{header} };
    my $nph   = delete $copy{nph} || $query->nph;

    if ( $self->{handler} eq 'redirect' ) {
        $copy{location} = $query->self_url if !$copy{location};
        $copy{type} = q{} if !exists $copy{type};
    }

    my ( $attachment, $charset, $cookie, $expires, $p3p, $target, $type )
        = delete @copy{qw/attachment charset cookie expires p3p target type/};

    my @headers;

    push @headers, 'Server', $query->server_software if $nph;
    push @headers, 'Window-Target', $target if $target;

    if ( $p3p ) {
        my $tags = ref $p3p eq 'ARRAY' ? join ' ', @{$p3p} : $p3p;
        push @headers, 'P3P', qq{policyref="/w3c/p3p.xml", CP="$tags"};
    }

    my @cookies = ref $cookie eq 'ARRAY' ? @{$cookie} : $cookie;
       @cookies = map { $self->_bake_cookie($_) || () } @cookies;

    push @headers, map { ('Set-Cookie', $_) } @cookies;
    push @headers, 'Expires', $self->_date($expires) if $expires;
    push @headers, 'Date', $self->_date if $expires or @cookies or $nph;
    push @headers, 'Pragma', 'no-cache' if $query->cache;

    if ( $attachment ) {
        my $value = qq{attachment; filename="$attachment"};
        push @headers, 'Content-Disposition', $value;
    }

    push @headers, map { ucfirst $_, $copy{$_} } keys %copy;

    if ( !defined $type or $type ne q{} ) {
        $charset = $query->charset unless defined $charset;
        my $ct = $type || 'text/html';
        $ct .= "; charset=$charset" if $charset && $ct !~ /\bcharset\b/;
        push @headers, 'Content-Type', $ct;
    }

    my @array;
    while ( my ($field, $value) = splice @headers, 0, 2 ) {
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

        push @array, $field, $value;
    }

    \@array;
}

sub _bake_cookie {
    my ( $self, $cookie ) = @_;
    ref $cookie eq 'CGI::Cookie' ? $cookie->as_string : $cookie;
}

sub _date {
    CGI::Util::expires( $_[1], 'http' );
}

1;
