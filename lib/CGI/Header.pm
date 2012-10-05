package CGI::Header;
use 5.008_009;
use strict;
use warnings;
use overload q{""} => 'as_string', fallback => 1;
use CGI::Util qw//;
use Carp qw/carp croak/;
use Scalar::Util qw/refaddr/;
use List::Util qw/first/;

our $VERSION = '0.02';

my %header;

sub new {
    my $class = shift;
    my $header = ref $_[0] eq 'HASH' ? shift : { @_ };
    my $self = bless \do { my $anon_scalar }, $class;
    $header{ refaddr $self } = $header;
    $self;
}

sub header { $header{ refaddr shift } }

sub DESTROY {
    my $self = shift;
    delete $header{ refaddr $self };
    return;
}

my %get = (
    -content_disposition => sub {
        my ( $header, $norm ) = @_;
        my $filename = $header->{-attachment};
        $filename ? qq{attachment; filename="$filename"} : $header->{ $norm };
    },
    -content_type => sub {
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
    -date => sub {
        my ( $header, $norm ) = @_;
        my $is_fixed = first { $header->{$_} } qw(-nph -expires -cookie);
        $is_fixed ? CGI::Util::expires() : $header->{ $norm };
    },
    -expires => sub {
        my $expires = shift->{-expires};
        $expires && CGI::Util::expires( $expires )
    },
    -p3p => sub {
        my $tags = shift->{-p3p};
        $tags = join ' ', @{ $tags } if ref $tags eq 'ARRAY';
        $tags && qq{policyref="/w3c/p3p.xml", CP="$tags"};
    },
    -set_cookie    => sub { shift->{-cookie} },
    -window_target => sub { shift->{-target} },
);

sub get {
    my $self   = shift;
    my $norm   = _normalize( shift ) || return;
    my $header = $header{ refaddr $self };

    if ( my $get = $get{$norm} ) {
        return $get->( $header, $norm );
    }
    
    $header->{ $norm };
}

my %set = (
    -content_disposition => sub {
        my ( $header, $norm, $value ) = @_;
        delete $header->{-attachment};
        $header->{ $norm } = $value;
    },
    -content_type => sub {
        my ( $header, $norm, $value ) = @_;
        if ( defined $value and $value ne q{} ) {
            @{ $header }{qw/-type -charset/} = ( $value, q{} );
        }
        else {
            carp "Can't set '$norm' to neither undef nor an empty string";
        }
    },
    -date => sub {
        my ( $header, $norm, $value ) = @_;
        return if first { $header->{$_} } qw(-nph -expires -cookie);
        $header->{ $norm } = $value;
    },
    -expires => sub {
        carp "Can't assign to '-expires' directly, use expires() instead";
    },
    -p3p => sub {
        carp "Can't assign to '-p3p' directly, use p3p_tags() instead";
    },
    -set_cookie => sub {
        my ( $header, $norm, $value ) = @_;
        delete $header->{-date} if $value;
        $header->{-cookie} = $value;
    },
    -window_target => sub {
        my ( $header, $norm, $value ) = @_;
        $header->{-target} = $value;
    },
);

sub set {
    my $self   = shift;
    my $norm   = _normalize( shift ) || return;
    my $header = $header{ refaddr $self };

    if ( my $set = $set{$norm} ) {
        $set->( $header, $norm, @_ );
    }
    else {
        $header->{ $norm } = shift;
    }

    return;
}

my %exists = (
    -content_type => sub {
        my $header = shift;
        !defined $header->{-type} || $header->{-type} ne q{};
    },
    -content_disposition => sub {
        my ( $header, $norm ) = @_;
        exists $header->{ $norm } || $header->{-attachment};
    },
    -date => sub {
        my ( $header, $norm ) = @_;
        exists $header->{ $norm }
            || first { $header->{$_} } qw(-nph -expires -cookie );
    },
    -set_cookie    => sub { exists shift->{-cookie} },
    -window_target => sub { exists shift->{-target} },
);

sub exists {
    my $self   = shift;
    my $norm   = _normalize( shift ) || return;
    my $header = $header{ refaddr $self };

    if ( my $exists = $exists{$norm} ) {
        return $exists->( $header, $norm );
    }

    exists $header->{ $norm };
}

my %delete = (
    -content_disposition => sub { delete shift->{-attachment} },
    -content_type => sub {
        my $header = shift;
        delete $header->{-charset};
        $header->{-type} = q{};
    },
    -date    => sub {},
    -expires => sub {},
    -p3p     => sub {},
    -set_cookie    => sub { delete shift->{-cookie} },
    -window_target => sub { delete shift->{-target} },
);

sub delete {
    my $self   = shift;
    my $field  = shift;
    my $norm   = _normalize( $field ) || return;
    my $header = $header{ refaddr $self };

    if ( my $delete = $delete{$norm} ) {
        my $value  = defined wantarray && $self->get( $field );
        $delete->( $header, $norm );
        delete $header->{ $norm };
        return $value;
    }

    delete $header->{ $norm };
}

my %is_ignored = map { $_ => 1 }
    qw( -attachment -charset -cookie -cookies -nph -target -type );

sub _normalize {
    my $norm = lc shift;
    $norm =~ tr/-/_/;
    $norm = "-$norm";
    $is_ignored{ $norm } ? undef : $norm;
}

sub clone {
    my $self = shift;
    my $class = ref $self or croak "Can't clone non-object: $self";
    my $header = $header{ refaddr $self };
    $class->new( %{ $header } );
}

sub is_empty { !shift->SCALAR }

sub clear {
    my $self = shift;
    my $header = $header{ refaddr $self };
    %{ $header } = ( -type => q{} );
    return;
}

BEGIN {
    my %conflict_with = (
        attachment => '-content_disposition',
        nph        => '-date',
        expires    => '-date',
    );

    while ( my ($method, $conflict_with) = CORE::each %conflict_with ) {
        my $norm = "-$method";
        my $code = sub {
            my $self   = shift;
            my $header = $header{ refaddr $self };
    
            if ( @_ ) {
                my $value = shift;
                delete $header->{ $conflict_with } if $value;
                $header->{ $norm } = $value;
            }

            $header->{ $norm };
        };

        no strict 'refs';
        *{ $method } = $code;
    }
}

sub p3p_tags {
    my $self   = shift;
    my $header = $header{ refaddr $self };

    if ( @_ ) {
        $header->{-p3p} = @_ > 1 ? [ @_ ] : shift;
    }
    elsif ( my $tags = $header->{-p3p} ) {
        my @tags = ref $tags eq 'ARRAY' ? @{ $tags } : split ' ', $tags;
        return wantarray ? @tags : $tags[0];
    }

    return;
}

sub field_names {
    my $self   = shift;
    my $header = $header{ refaddr $self };
    my %header = %{ $header }; # copy

    my @fields;

    push @fields, 'Status'        if delete $header{-status};
    push @fields, 'Window-Target' if delete $header{-target};
    push @fields, 'P3P'           if delete $header{-p3p};

    push @fields, 'Set-Cookie' if my $cookie  = delete $header{-cookie};
    push @fields, 'Expires'    if my $expires = delete $header{-expires};
    push @fields, 'Date' if delete $header{-nph} or $cookie or $expires;

    push @fields, 'Content-Disposition' if delete $header{-attachment};

    my $type = delete @header{qw/-charset -type/};

    # not ordered
    for my $norm ( keys %header ) {
        next unless defined $header{ $norm };

        push @fields, do {
            my $field = $norm;
            $field =~ s/^-(\w)/\u$1/;
            $field =~ tr/_/-/;
            $field;
        };
    }

    push @fields, 'Content-Type' if !defined $type or $type ne q{};

    @fields;
}

sub flatten {
    my $self = shift;

    my @headers;
    for my $field ( $self->field_names ) {
        my $value = $self->get( $field );
        my @values = ref $value eq 'ARRAY' ? @{ $value } : $value;
        push @headers, map { $field => "$_" } @values; # force stringification
    }

    @headers;
}

sub each {
    my ( $self, $callback ) = @_;

    if ( ref $callback eq 'CODE' ) {
        my @headers = $self->flatten;
        while ( my ($field, $value) = splice @headers, 0, 2 ) {
            $callback->( $field, $value );
        }
    }
    else {
        croak 'Must provide a code reference to each()';
    }

    return;
}

sub as_string {
    my $self   = shift;
    my $eol    = defined $_[0] ? shift : "\015\012";
    my $header = $header{ refaddr $self };

    my @lines;

    if ( $header->{-nph} ) {
        my $software = $ENV{SERVER_SOFTWARE} || 'cmdline';
        my $protocol = $ENV{SERVER_PROTOCOL} || 'HTTP/1.0';
        my $status   = $header->{-status}    || '200 OK';
        push @lines, "$protocol $status";
        push @lines, "Server: $software";
    }

    $self->each(sub {
        my ( $field, $value ) = @_;
        $value =~ s/$eol(\s)/$1/g;
        $value =~ s/$eol|\015|\012//g;
        push @lines, "$field: $value";
    });

    join $eol, @lines, q{};
}

sub dump {
    my $self = shift;
    my $this = refaddr $self;

    require Data::Dumper;

    local $Data::Dumper::Indent = 1;

    my %dump = (
        __PACKAGE__, {
            header => $header{ $this },
        },
        @_,
    );

    Data::Dumper::Dumper( \%dump );
}

BEGIN {
    *TIEHASH = \&new;    *FETCH  = \&get;    *STORE = \&set;
    *EXISTS  = \&exists; *DELETE = \&delete; *CLEAR = \&clear;    
}

sub SCALAR {
    my $self = shift;
    my $header = $header{ refaddr $self };
    !defined $header->{-type} || first { $_ } values %{ $header };
}

sub STORABLE_freeze {
    my ( $self, $cloning ) = @_;
    ( q{}, $header{ refaddr $self } );
}

sub STORABLE_thaw {
    my ( $self, $serialized, $cloning, $header ) = @_;
    $header{ refaddr $self } = $header;
    $self;
}

1;

__END__

=head1 NAME

CGI::Header - Adapter for CGI::header() function

=head1 SYNOPSIS

  use CGI::Header;

  my $header = {
      -attachment => 'foo.gif',
      -charset    => 'utf-7',
      -cookie     => [ $cookie1, $cookie2 ], # CGI::Cookie objects
      -expires    => '+3d',
      -nph        => 1,
      -p3p        => [qw/CAO DSP LAW CURa/],
      -target     => 'ResultsWindow',
      -type       => 'image/gif',
  };

  my $h = CGI::Header->new( $header );

  # update $header
  $h->set( 'Content-Length' => 3002 );
  $h->delete( 'Content-Disposition' );
  $h->clear;

  my @headers = $h->flatten;
  # => ( 'Content-length', '3002', 'Content-Type', 'text/plain' )

  print $h->as_string;
  # Content-length: 3002
  # Content-Type: text/plain

  $h->header; # same reference as $header

=head1 DESCRIPTION

This module is a utility class to manipulate a hash reference
which L<CGI>'s C<header()> function receives.

=head2 METHODS

=over 4

=item $header = CGI::Header->new({ -type => 'text/plain', ... })

Given a header hash reference, returns a CGI::Header object
which holds a reference to the original given argument.
The object updates the reference when called write methods like C<set()>,
C<delete()> or C<clear()>. It also has C<header()> method that
would return the same reference.

  my $header = { -type => 'text/plain' };
  my $h = CGI::Header->new( $header );
  $h->header; # same reference as $header

=item $value = $header->get( $field )

=item $header->set( $field => $value )

Get or set the value of the header field.
The header field name (C<$field>) is not case sensitive.
You can use underscores as a replacement for dashes in header names.

  # field names are case-insensitive
  $header->get( 'Content-Length' );
  $header->get( 'content_length' );

The C<$value> argument may be a plain string or
a reference to an array of L<CGI::Cookie> objects for the Set-Cookie header.

  $header->set( 'Content-Length' => 3002 );
  $header->set( 'Set-Cookie' => [$cookie1, $cookie2] );

=item $bool = $header->exists( $field )

Returns a Boolean value telling whether the specified field exists.

  if ( $header->exists('ETag') ) {
      ...
  }

=item $value = $header->delete( $field )

Deletes the specified field form CGI response headers.
Returns the value of the deleted field.

  my $value = $header->delete( 'Content-Disposition' ); # => 'inline'

=item @fields = $header->field_names

Returns the list of distinct field names present in the header.
The field names have case as returned by C<CGI::header()>.

  my @fields = $header->field_names;
  # => ( 'Set-Cookie', 'Content-length', 'Content-Type' )

=item $header->each( \&callback )

Apply a subroutine to each header field in turn.
The callback routine is called with two parameters;
the name of the field and a value.
If the Set-Cookie header is multi-valued, then the routine is called
once for each value.
Any return values of the callback routine are ignored.

  my @lines;

  $header->each(sub {
      my ( $field, $value ) = @_;
      push @lines, "$field: $value";
  });

=item @headers = $header->flatten

Returns pairs of fields and values. It's identical to:

  my @headers;

  $header->each(sub {
      my ( $field, $value ) = @_;
      push @headers, $field, $value;
  });

=item $header->clear

This will remove all header fields.

Internally, this method is a shortcut for:

  %{ $header->header } = ( -type => q{} );

=item $bool = $header->is_empty

Returns true if the header contains no key-value pairs.

  $header->clear;

  if ( $header->is_empty ) { # true
      ...
  }

=item $clone = $header->clone

Returns a copy of this CGI::Header object.
It's identical to:

  my %copy = %{ $header->header };
  my $clone = CGI::Header->new( \%copy );

=item $header->as_string

=item $header->as_string( $eol )

Returns the header fields as a formatted MIME header.
The optional C<$eol> parameter specifies the line ending sequence to use.
The default is C<\015\012>.

The following:

  use CGI;
  print CGI::header( $header->header );

is identical to:

  my $CRLF = $CGI::CRLF;
  print $header->as_string( $CRLF ), $CRLF;

When valid multi-line headers are included, this method will always output
them back as a single line, according to the folding rules of RFC 2616:
the newlines will be removed, while the white space remains.

Unlike CGI.pm, when invalid newlines are included,
this module removes them instead of throwing exceptions.

=item $filename = $header->attachment

=item $header->attachment( $filename )

Can be used to turn tha page into an attachment.
Represents suggested name for the saved file.

  $header->attachment( 'genome.jpg' );

In this case, the outgoing will be formatted as:

  Content-Disposition: attachment; filename="genome.jpg"

=item @tags = $header->p3p_tags

=item $header->p3p_tags( @tags )

Represents P3P tags. The parameter can be an array or a space-delimited
string. Returns a list of P3P tags.

  $header->p3p_tags(qw/CAO DSP LAW CURa/);

In this case, the outgoing header will be formatted as:

  P3P: policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"

=item $format = $header->expires

=item $header->expires( $format )

The Expires header gives the date and time after which the entity
should be considered stale. You can specify an absolute or relative
expiration interval. The following forms are all valid for this field:

  $header->expires( '+30s' ); # 30 seconds from now
  $header->expires( '+10m' ); # ten minutes from now
  $header->expires( '+1h'  ); # one hour from now
  $header->expires( 'now'  ); # immediately
  $header->expires( '+3M'  ); # in three months
  $header->expires( '+10y' ); # in ten years time

  # at the indicated time & date
  $header->expires( 'Thu, 25 Apr 1999 00:40:33 GMT' );

=item $header->nph

If set to a true value, will issue the correct headers to work
with a NPH (no-parse-header) script.

  $header->nph( 1 );

=back

=head1 SEE ALSO

L<CGI>, L<Plack::Util>

=head1 BUGS AND LIMITATIONS

This module is beta state. API may change without notice.

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
