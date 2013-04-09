package CGI::Header::PSGI;
use strict;
use warnings;
use parent 'CGI::Header';

our $VERSION = '0.06';

sub finalize {
    my $self  = shift;
    my $query = $self->query;
    my %copy  = %{ $self->{header} };

    if ( $self->{handler} eq 'redirect' ) {
        $copy{location} = $query->self_url if !$copy{location};
        $copy{status} = '302 Found' if !defined $copy{status};
        $copy{type} = q{} if !exists $copy{type};
    }

    my ( $charset, $cookie, $expires, $nph, $target, $type )
        = delete @copy{qw/charset cookie expires nph target type/};

    my $status = delete $copy{status} || '200';
       $status =~ s/\D*$//;

    my @headers;

    push @headers, 'Server', $query->server_software if $nph or $query->nph;
    push @headers, 'Window-Target', $target if $target;

    if ( my $p3p = delete $copy{p3p} ) {
        my $tags = ref $p3p eq 'ARRAY' ? join ' ', @{$p3p} : $p3p;
        push @headers, 'P3P', qq{policyref="/w3c/p3p.xml", CP="$tags"};
    }

    my @cookies = ref $cookie eq 'ARRAY' ? @{$cookie} : $cookie;
       @cookies = map { $self->_bake_cookie($_) || () } @cookies;

    push @headers, 'Set-Cookie', \@cookies if @cookies;
    push @headers, 'Expires', $self->_date($expires) if $expires;
    push @headers, 'Date', $self->_date if $expires or @cookies or $nph;
    push @headers, 'Pragma', 'no-cache' if $query->cache;

    if ( my $attachment = delete $copy{attachment} ) {
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

    $status, \@headers;
}

sub _bake_cookie {
    my ( $self, $cookie ) = @_;
    ref $cookie eq 'CGI::Cookie' ? $cookie->as_string : $cookie;
}

sub _date {
    require CGI::Util;
    CGI::Util::expires( $_[1], 'http' );
}

1;
