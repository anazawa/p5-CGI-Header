package CGI::Header;
use 5.008_009;
use strict;
use warnings;
use overload q{""} => 'as_string', fallback => 1;
use Carp qw/carp croak/;
use CGI::Util qw//;
use HTTP::Date qw//;
use List::Util qw/first/;
use Scalar::Util qw/refaddr/;
use Storable qw//;

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

sub header {
    my $self = shift;
    my $this = refaddr $self;
    $header_of{ $this };
}

sub DESTROY {
    my $self = shift;
    my $this = refaddr $self;
    delete $header_of{ $this };
    return;
}

my %content_type = (
    get => sub {
        my $header  = shift;
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

        $charset ? "$type; charset=$charset" : $type;
    },
    set => sub {
        my ( $header, $value ) = @_;
        $header->{-type} = $value;
        $header->{-charset} = q{};
    },
    exists => sub {
        my $header = shift;
        !defined $header->{-type} || $header->{-type} ne q{};
    },
    delete => sub {
        my $header = shift;
        delete $header->{-charset};
        $header->{-type} = q{};
    },
);

my %expires = (
    get => sub {
        my $header = shift;
        my $expires = $header->{-expires};
        $expires && CGI::Util::expires( $expires );
    },
    set => sub {
        carp "Can't assign to '-expires' directly, use accessors instead";
    },
);

my %p3p = (
    get => sub {
        my $header = shift;
        my $p3p = $header->{-p3p};
        my $tags = ref $p3p eq 'ARRAY' ? join ' ', @{ $p3p } : $p3p;
        $tags && qq{policyref="/w3c/p3p.xml", CP="$tags"};
    },
    set => sub {
        carp "Can't assign to '-p3p' directly, use accessors instead";
    },
);

my %content_disposition = (
    get => sub {
        my $header = shift;
        my $filename = $header->{-attachment};
        return qq{attachment; filename="$filename"} if $filename;
        $header->{-content_disposition};
    },
    set => sub {
        my ( $header, $value ) = @_;
        delete $header->{-attachment};
        $header->{-content_disposition} = $value;
    },
    exists => sub {
        my $header = shift;
        $header->{-attachment} || $header->{-content_disposition};
    },
    delete => sub {
        my $header = shift;
        delete $header->{-attachment};
    },
);

my %date = (
    get => sub {
        my $header = shift;
        my $is_fixed = first { $header->{$_} } qw(-nph -expires -cookie);
        return HTTP::Date::time2str( time ) if $is_fixed;
        $header->{-date};
    },
    set => sub {
        my ( $header, $value ) = @_;
        my $is_fixed = first { $header->{$_} } qw(-nph -expires -cookie);
        return carp 'The Date header is fixed' if $is_fixed;
        $header->{-date} = $value;
    },
    exists => sub {
        my $header = shift;
        $header->{-date} || first { $header->{$_} } qw(-nph -expires -cookie);
    },
    delete => sub {
        my $header = shift;
        my $is_fixed = first { $header->{$_} } qw(-nph -expires -cookie);
        return carp 'The Date header is fixed' if $is_fixed;
    },
);

my %cookie = (
    set => sub {
        my ( $header, $value ) = @_;
        delete $header->{-date};
        $header->{-cookie} = $value;
    },
);

my %handler = (
    -content_disposition => \%content_disposition,
    -content_type        => \%content_type,
    -cookie              => \%cookie,
    -date                => \%date,
    -expires             => \%expires,
    -p3p                 => \%p3p,
);

sub get {
    my $self   = shift;
    my $norm   = $self->_normalize( shift );
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    return unless $norm;

    if ( my $get = $handler{$norm}{get} ) {
        return $get->( $header );
    }

    $header->{ $norm };
}


sub set {
    my $self   = shift;
    my $norm   = $self->_normalize( shift );
    my $value  = shift;
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    return unless $norm;

    if ( my $set = $handler{$norm}{set} ) {
        $set->( $header, $value );
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

    return unless $norm;

    if ( my $delete = $handler{$norm}{delete} ) {
        $delete->( $header );
    }

    delete $header->{ $norm };

    $value;
}

sub exists {
    my $self   = shift;
    my $norm   = $self->_normalize( shift );
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    return unless $norm;

    if ( my $exists = $handler{$norm}{exists} ) {
        return $exists->( $header );
    }

    $header->{ $norm };
}

sub clear {
    my $self = shift;
    my $this = refaddr $self;
    %{ $header_of{$this} } = ( -type => q{} );
    return;
}

BEGIN {
    *TIEHASH = \&new;   *STORE  = \&set;    *FETCH  = \&get;
    *CLEAR   = \&clear; *EXISTS = \&exists; *DELETE = \&delete;
}

sub SCALAR {
    my $self = shift;
    my $this = refaddr $self;
    my $header = $header_of{ $this };
    !defined $header->{-type} || first { $_ } values %{ $header };
}

sub is_empty { !shift->SCALAR }

sub field_names {
    my $self   = shift;
    my $this   = refaddr $self;
    my %header = %{ $header_of{$this} }; # shallow copy

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
    while ( my ($norm, $value) = CORE::each %header ) {
        push @fields, $self->_denormalize( $norm ) if $value;
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
    my $self   = shift;
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    if ( @_ ) {
        $header->{-target} = shift;
        return;
    }

    $header->{-target};
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

sub expires {
    my $self   = shift;
    my $this   = refaddr $self;
    my $header = $header_of{ $this };

    if ( @_ ) {
        my $expires = shift;
        delete $header->{-date} if $expires;
        $header->{-expires} = $expires;
    }
    elsif ( my $expires = $self->get('Expires') ) {
        return HTTP::Date::str2time( $expires );
    }

    return;
}

sub date {
    my $self     = shift;
    my $time     = shift;
    my $this     = refaddr $self;
    my $header   = $header_of{ $this };
    my $is_fixed = first { $header->{$_} } qw(-nph -expires -cookie);

    if ( defined $time ) {
        return carp 'The Date header is fixed' if $is_fixed;
        $header->{-date} = HTTP::Date::time2str( $time );
    }
    elsif ( $is_fixed ) {
        return time;
    }
    elsif ( my $date = $header->{-date} ) {
        return HTTP::Date::str2time( $date );
    }

    return;
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
        next unless ref $cookie   eq 'CGI::Cookie';
        next unless $cookie->name eq $name;
        push @values, $cookie;
    }

    wantarray ? @values : $values[0];
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
        $self->set( 'Set-Cookie' => [ $new_cookie ] );
        return;
    }
    elsif ( ref $cookies ne 'ARRAY' ) {
        $cookies = [ $cookies ];
        $self->set( 'Set-Cookie' => $cookies );
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

BEGIN { *clone = \&Storable::dclone }

sub STORABLE_freeze {
    my ( $self, $cloning ) = @_;
    my $this = refaddr $self;
    ( q{}, $header_of{$this} );
}

sub STORABLE_thaw {
    my ( $self, $serialized, $cloning, $header ) = @_;
    my $this = refaddr $self;
    $header_of{ $this } = $header;
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

  my $header = CGI::Header->new(
      -attachment => 'genome.jpg',
      -charset    => 'utf-8',
      -cookie     => 'ID=123456; path=/',
      -expires    => '+3M',
      -nph        => 1,
      -p3p        => [qw/CAO DSP LAW CURa/],
      -target     => 'ResultsWindow',
      -type       => 'text/plain',
  );

  $header->set( 'Content-Length' => 12345 );
  $header->delete( 'Content-Disposition' );
  my $value = $header->get( 'Status' );
  my $bool = $header->exists( 'ETag' );

  $header->attachment( 'genome.jpg' );
  $header->expires( '+3M' );
  $header->nph( 1 );
  $header->p3p_tags(qw/CAO DSP LAW CURa/);
  $header->target( 'ResultsWindow' );

=head1 DESCRIPTION

Accepts the same arguments as CGI::header() does.
Generates the same HTTP response headers as the subroutine does.

=head2 METHODS

=over 4

=item $header = CGI::Header->new( -type => 'text/plain', ... )

Construct a new CGI::Header object.
You might pass some initial attribute-value pairs as parameters to
the constructor:

  my $header = CGI::Header->new(
      -attachment => 'genome.jpg',
      -charset    => 'utf-8',
      -cookie     => 'ID=123456; path=/',
      -expires    => '+3M',
      -nph        => 1,
      -p3p        => [qw/CAO DSP LAW CURa/],
      -target     => 'ResultsWindow',
      -type       => 'text/plain',
  );

=item $value = $eader->get( $field )

=item $header->set( $field => $value )

=item $bool = $header->exists( $field )

Returns a Boolean value telling whether the specified field exists.

  if ( $header->exists('ETag') ) {
      ...
  }

=item $value = $header->delete( $field )

Deletes the specified field.

  $header->delete( 'Content-Disposition' );
  my $value = $header->delete( 'Content-Disposition' ); # inline

=item @fields = $header->field_names

Returns the list of field names present in the header.

  my @fields = $header->field_names;
  # => ( 'Set-Cookie', 'Content-length', 'Content-Type' )

=item $header->each( \&callback )

Apply a subroutine to each header field in turn.
The callback routine is called with two parameters;
the name of the field and a value.
Any return values of the callback routine are ignored.

  my @lines;

  $self->each(sub {
      my ( $field, $value ) = @_;
      push @lines, "$field: $value";
  });

=item @headers = $header->flatten

Returns pairs of fields and values.

  my @headers = $header->flatten;
  # => ( 'Status', '304 Nod Modified', 'Content-Type', 'text/plain' )

=item $header->clear

This will remove all header fields.

=item $bool = $header->is_empty

Returns true if the header contains no key-value pairs.

  $header->clear;

  if ( $header->is_empty ) { # true
      ...
  }

=item $clone = $header->clone

Returns a copy of this CGI::Header object.

=item $header->as_string

=item $header->as_string( $eol )

Returns the header fields as a formatted MIME header.
The optional C<$eol> parameter specifies the line ending sequence to use.
The default is C<\n>.

=back

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
