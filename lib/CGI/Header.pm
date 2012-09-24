package CGI::Header;
use 5.008_009;
use strict;
use warnings;
use overload q{""} => 'as_string', fallback => 1;
use Carp qw/carp croak/;
use Scalar::Util qw/refaddr/;
use List::Util qw/first/;

our $VERSION = '0.01';

my %header_of;

sub new {
    my $class  = shift;
    my $header = ref $_[0] eq 'HASH' ? shift : { @_ };
    my $self   = bless \do { my $anon_scalar }, $class;
    my $this   = refaddr $self;

    $header_of{ $this } = $header;

    $self;
}

sub get {
    my $self   = shift;
    my $norm   = $self->_normalize( shift );
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    if ( $norm eq '-content_type' ) {
        my $type    = $header->{-type};
        my $charset = $header->{-charset};

        if ( defined $type and $type eq q{} ) {
            undef $charset;
            undef $type;
        }
        else {
            $type ||= 'text/html';

            if ( $type =~ /\bcharset\b/ ) {
                undef $charset;
            }
            elsif ( !defined $charset ) {
                $charset = 'ISO-8859-1';
            }
        }

        return $charset ? "$type; charset=$charset" : $type;
    }
    elsif ( $norm eq '-content_disposition' ) {
        if ( my $filename = $header->{-attachment} ) {
            return qq{attachment; filename="$filename"};
        }
    }
    elsif ( $norm eq '-date' ) {
        if ( $self->_date_header_is_fixed ) {
            require HTTP::Date;
            return HTTP::Date::time2str( time );
        }
    }
    elsif ( $norm eq '-expires' ) {
        if ( my $expires = $header->{-expires} ) {
            require CGI::Util;
            return CGI::Util::expires( $expires );
        }
    }
    elsif ( $norm eq '-p3p' ) {
        if ( my $p3p = $header->{-p3p} ) {
            my $tags = ref $p3p eq 'ARRAY' ? join ' ', @{ $p3p } : $p3p;
            return qq{policyref="/w3c/p3p.xml", CP="$tags"};
        }
    }

    $header->{ $norm };
}

sub set {
    my $self   = shift;
    my $norm   = $self->_normalize( shift );
    my $value  = shift;
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    if ( $norm eq '-date' ) {
        if ( $self->_date_header_is_fixed ) {
            return carp 'The Date header is fixed';
        }
    }
    elsif ( $norm eq '-content_type' ) {
        $header->{-type} = $value;
        $header->{-charset} = q{};
        delete $header->{ $norm };
        return;
    }
    elsif ( $norm eq '-content_disposition' ) {
        delete $header->{-attachment};
    }
    elsif ( $norm eq '-cookie' ) {
        delete $header->{-date};
    }
    elsif ( $norm eq '-p3p' or $norm eq '-expires' ) {
        carp "Can't assign to '$norm' directly, use accessors instead";
        return;
    }

    $header->{ $norm } = $value;

    return;
}

sub delete {
    my $self   = shift;
    my $field  = shift;
    my $norm   = $self->_normalize( $field );
    my $value  = defined wantarray && $self->get( $field );
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    if ( $norm eq '-date' ) {
        if ( $self->_date_header_is_fixed ) {
            return carp 'The Date header is fixed';
        }
    }
    elsif ( $norm eq '-content_type' ) {
        delete $header->{-charset};
        $header->{-type} = q{};
    }
    elsif ( $norm eq '-content_disposition' ) {
        delete $header->{-attachment};
    }

    delete $header->{ $norm };

    $value;
}

sub clear {
    my $self = shift;
    my $this = refaddr $self;
    %{ $header_of{$this} } = ( -type => q{} );
    return;
}

sub exists {
    my $self   = shift;
    my $norm   = $self->_normalize( shift );
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    if ( $norm eq '-content_type' ) {
        return !defined $header->{-type} || $header->{-type} ne q{};
    }
    elsif ( $norm eq '-content_disposition' ) {
        return 1 if $header->{-attachment};
    }
    elsif ( $norm eq '-date' ) {
        return 1 if first { $header->{$_} } qw(-nph -expires -cookie);
    }

    $header->{ $norm };
}

sub DESTROY {
    my $self = shift;
    my $this = refaddr $self;
    delete $header_of{ $this };
    return;
}

sub header {
    my $self = shift;
    my $this = refaddr $self;
    $header_of{ $this };
}

BEGIN {
    *TIEHASH = \&new;
    *STORE   = \&set;
    *FETCH   = \&get;
    *CLEAR   = \&clear;
    *EXISTS  = \&exists;
    *DELETE  = \&delete;
}

sub SCALAR {
    my $self = shift;
    my $this = refaddr $self;
    my $header = $header_of{ $this };
    !defined $header->{-type} || first { $_ } values %{ $header };
}

sub is_empty { not shift->SCALAR }

BEGIN {
    require Storable;
    *clone = \&Storable::dclone;
}

sub field_names {
    my $self   = shift;
    my $this   = refaddr $self;
    my %header = %{ $header_of{$this} }; # copy

    my @fields;

    push @fields, 'Status'        if delete $header{-status};
    push @fields, 'Window-Target' if delete $header{-target};
    push @fields, 'P3P'           if delete $header{-p3p};

    push @fields, 'Set-Cookie' if my $cookie  = delete $header{-cookie};
    push @fields, 'Expires'    if my $expires = delete $header{-expires};
    push @fields, 'Date' if delete $header{-nph} or $cookie or $expires;

    push @fields, 'Content-Disposition' if delete $header{-attachment};

    my $type = delete @header{ '-charset', '-type' };

    # not ordered
    while ( my ($norm, $value) = each %header ) {
        next unless $value;
        push @fields, $self->_denormalize( $norm );
    }

    push @fields, 'Content-Type' if !defined $type or $type ne q{};

    @fields;
}

sub flatten {
    my $self = shift;
    map { $_, $self->get($_) } $self->field_names;
}

sub each {
    my ( $self, $callback ) = @_;

    if ( ref $callback eq 'CODE' ) {
        for my $field ( $self->field_names ) {
            $callback->( $field, $self->get($field) );
        }
    }
    else {
        croak 'Must provide a code reference to each()';
    }

    return;
}

sub attachment {
    my $self   = shift;
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    if ( @_ ) {
        my $filename = shift;
        delete $header->{-content_disposition};
        $header->{-attachment} = $filename;
        return;
    }

    $header->{-attachment};
}

sub expires {
    my $self   = shift;
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    if ( @_ ) {
        my $expires = shift;
        delete $header->{-date}; # if $expires;
        $header->{-expires} = $expires;
        return;
    }

    $header->{-expires};
}

sub nph {
    my $self   = shift;
    my $this   = refaddr $self;
    my $header = $header_of{ $this };
    
    if ( @_ ) {
        my $nph = shift;
        delete $header->{-date} if $nph;
        $header->{-nph} = $nph;
        return;
    }

    $header->{-nph};
}

sub p3p_tags {
    my $self   = shift;
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    if ( @_ ) {
        $header->{-p3p} = @_ > 1 ? [ @_ ] : shift;
    }
    elsif ( my $tags = $header->{-p3p} ) {
        my @tags = ref $tags eq 'ARRAY' ? @{ $tags } : split ' ', $tags;
        return wantarray ? @tags : $tags[0];
    }

    return;
}

sub target {
    my $self = shift;
    my $this = refaddr $self;
    my $header = $header_of{ $this };
    $header->{-target} = shift if @_;
    $header->{-target};
}

sub get_cookie {
    my $self   = shift;
    my $name   = shift;
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    my @cookies = do {
        my $cookies = $header->{-cookie};
        return unless $cookies;
        ref $cookies eq 'ARRAY' ? @{ $cookies } : $cookies;
    };

    my @values;
    for my $cookie ( @cookies ) {
        next unless ref $cookie eq 'CGI::Cookie';
        next unless $cookie->name eq $name;
        push @values, $cookie;
    }

    wantarray ? @values : $values[0];
}

sub dump {
    my $self = shift;
    my $this = refaddr $self;

    require Data::Dumper;

    local $Data::Dumper::Indent = 1;

    my %dump = (
        __PACKAGE__, {
            header => $header_of{ $this },
        },
        @_,
    );

    Data::Dumper::Dumper( \%dump );
}

sub _date_header_is_fixed {
    my $self = shift;
    my $this = refaddr $self;
    my $header = $header_of{ $this };
    $header->{-expires} || $header->{-cookie} || $header->{-nph};
}

sub content_type {
    my $self = shift;

    return $self->set( 'Content-Type' => shift ) if @_;

    my ( $media_type, $rest ) = do {
        my $content_type = $self->get( 'Content-Type' );
        return q{} unless defined $content_type;
        split /;\s*/, $content_type, 2;
    };

    $media_type =~ s/\s+//g;
    $media_type = lc $media_type;

    wantarray ? ($media_type, $rest) : $media_type;
}

sub date {
    my ( $self, $time ) = @_;

    require HTTP::Date;

    if ( defined $time ) {
        $self->set( Date => HTTP::Date::time2str($time) );
    }
    elsif ( my $date = $self->get('Date') ) {
        return HTTP::Date::str2time( $date );
    }

    return;
}

sub set_cookie {
    my ( $self, $name, $value ) = @_;

    require CGI::Cookie;

    my $new_cookie = CGI::Cookie->new(do {
        my %args = ref $value eq 'HASH' ? %{ $value } : ( value => $value );
        $args{name} = $name;
        \%args;
    });

    my $cookies = $self->get( 'Set-Cookie' );

    if ( !$cookies ) {
        return $self->set( 'Set-Cookie' => [ $new_cookie ] );
    }
    elsif ( ref $cookies ne 'ARRAY' ) {
        $self->set( 'Set-Cookie' => $cookies = [ $cookies ] );
    }

    my $set;
    for my $cookie ( @{$cookies} ) {
        next unless ref $cookie   eq 'CGI::Cookie';
        next unless $cookie->name eq $name;
        $cookie = $new_cookie;
        $set++;
        last;
    }

    push @{ $cookies }, $new_cookie unless $set;

    return;
}

sub status {
    my $self   = shift;
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    require HTTP::Status;

    if ( @_ ) {
        my $code = shift;
        my $message = HTTP::Status::status_message( $code );
        return $header->{-status} = "$code $message" if $message;
        carp "Unknown status code '$code' passed to status()";
    }
    elsif ( my $status = $header->{-status} ) {
        return substr( $status, 0, 3 );
    }
    else {
        return '200';
    }

    return;
}

sub as_string {
    my $self   = shift;
    my $eol    = defined $_[0] ? shift : "\n";
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    my @lines;

    if ( $header->{-nph} ) {
        my $protocol = $ENV{SERVER_PROTOCOL} || 'HTTP/1.0';
        my $software = $ENV{SERVER_SOFTWARE} || 'cmdline';
        my $status   = $header->{-status}    || '200 OK';
        push @lines, "$protocol $status";
        push @lines, "Server: $software";
    }

    $self->each(sub {
        my ( $field, $value ) = @_;
        my @values = ref $value eq 'ARRAY' ? @{ $value } : $value;
        push @lines, "$field: $_" for @values;
    });

    # CR escaping for values, per RFC 822
    for my $line ( @lines ) {
        $line =~ s/$eol(\s)/$1/g;
        next unless $line =~ m/$eol|\015|\012/;
        $line = substr $line, 0, 72 if length $line > 72;
        croak "Invalid header value contains a new line ",
              "not followed by whitespace: $line";
    }

    join $eol, @lines, q{};
}

sub STORABLE_freeze {
    my ( $self, $cloning ) = @_;
    ( q{}, $header_of{ refaddr $self } );
}

sub STORABLE_thaw {
    my ( $self, $serialized, $cloning, $header ) = @_;
    $header_of{ refaddr $self } = $header;
    $self;
}

my %norm_of = (
    -attachment => q{},        -charset       => q{},
    -cookie     => q{},        -nph           => q{},
    -set_cookie => q{-cookie}, -target        => q{},
    -type       => q{},        -window_target => q{-target},
);

sub _normalize {
    my $class = shift;
    my $field = lc shift;

    # transliterate dashes into underscores
    $field =~ tr{-}{_};

    # add an initial dash
    $field = "-$field";

    exists $norm_of{$field} ? $norm_of{ $field } : $field;
}

my %field_name_of = (
    -attachment => 'Content-Disposition', -cookie => 'Set-Cookie',
    -p3p        => 'P3P',                 -target => 'Window-Target',
    -type       => 'Content-Type',
);

sub _denormalize {
    my ( $class, $norm ) = @_;

    unless ( exists $field_name_of{$norm} ) {
        ( my $field = $norm ) =~ s/^-//;
        $field =~ tr/_/-/;
        $field_name_of{ $norm } = ucfirst $field;
    }

    $field_name_of{ $norm };
}

1;

__END__

=head1 NAME

CGI::Header - Emulates CGI::header()

=head1 SYNOPSIS

  use CGI::Header;
  use CGI::Cookie;

  my $cookie = CGI::Cookie->new(
      -name  => 'ID',
      -value => 123456,
  );

  my $header = CGI::Header->new(
      -attachment => 'genome.jpg',
      -charset    => 'utf-8',
      -cookie     => $cookie,
      -expires    => '+3M',
      -nph        => 1,
      -p3p        => [qw/CAO DSP LAW CURa/],
      -target     => 'ResultsWindow',
      -type       => 'text/plain',
  );

  print $header->as_string;

=head1 DESCRIPTION

Accepts the same arguments as CGI::header() does.
Generates the same HTTP response headers as the subroutine does.

=head2 METHODS

=over 4

=item $header = CGI::Header->new( -type => 'text/plain', ... )

=item $value = $eader->get( $field )

=item $header->set( $field => $value )

=item $bool = $header->exists( $field )

=item $deleted = $header->delete( $field )

=item $header->clear

=item @fields = $header->field_names

=item $header->each( \&callback )

=item @headers = $header->flatten

=item $bool = $header->is_empty

=item $clone = $header->clone

=back

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
