package CGI::Header;
use 5.008_009;
use strict;
use warnings;
use overload q{""} => 'as_string', fallback => 1;
use CGI::Util qw//;
use Carp qw/carp croak/;
use Scalar::Util qw/refaddr/;
use List::Util qw/first/;

our $VERSION = '0.01';

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

    my $value;
    if ( my $get = $get{$norm} ) {
        $value = $get->( $header, $norm );
    }
    else {
        $value = $header->{ $norm };
    }

    $value;
}

my %set = (
    -content_disposition => sub {
        my ( $header, $norm, $value ) = @_;
        delete $header->{-attachment};
        $header->{ $norm } = $value;
    },
    -content_type => sub {
        my ( $header, $norm, $value ) = @_;
        if ( $value ) {
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
    my $value  = shift;
    my $header = $header{ refaddr $self };

    if ( my $set = $set{$norm} ) {
        $set->( $header, $norm, $value );
    }
    else {
        $header->{ $norm } = $value;
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

    my $bool;
    if ( my $exists = $exists{$norm} ) {
        $bool = $exists->( $header, $norm );
    }
    else {
        $bool = exists $header->{ $norm };
    }

    $bool;
}

my %delete = (
    -content_disposition => sub { delete shift->{-attachment} },
    -content_type => sub {
        my $header = shift;
        delete $header->{-charset};
        $header->{-type} = q{};
    },
    -set_cookie    => sub { delete shift->{-cookie} },
    -window_target => sub { delete shift->{-target} },
);

sub delete {
    my $self   = shift;
    my $field  = shift;
    my $norm   = _normalize( $field ) || return;
    my $value  = defined wantarray && $self->get( $field );
    my $header = $header{ refaddr $self };

    if ( my $delete = $delete{$norm} ) {
        $delete->( $header, $norm );
    }

    delete $header->{ $norm };

    $value;
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
    while ( my ($norm, $value) = CORE::each %header ) {
        next unless $value;

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

CGI::Header - Emulates CGI::header()

=head1 SYNOPSIS

  use CGI::Header;

  my $header = CGI::Header->new(
      -attachment => 'foo.gif',
      -charset    => 'utf-7',
      -cookie     => $cookie, # CGI::Cookie object
      -expires    => '+3d',
      -nph        => 1,
      -p3p        => [qw/CAO DSP LAW CURa/],
      -target     => 'ResultsWindow',
      -type       => 'image/gif',
  );

  $header->set( 'Content-Length' => 3002 );
  my $value = $header->get( 'Status' );
  my $bool = $header->exists( 'ETag' );
  $header->delete( 'Content-Disposition' );

  $header->attachment( 'genome.jpg' );
  $header->expires( '+3M' );
  $header->nph( 1 );
  $header->p3p_tags(qw/CAO DSP LAW CURa/);

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

=item $header->attachment( $filename )

A shortcut for

  $header->set(
      'Content-Disposition' => qq{attachment; filename="$filename"}
  );

=item $header->p3p_tags( $tags )

A shortcut for

  $header->set(
      'P3P' => qq{policyref="/w3c/p3p.xml", CP="$tags"}
  ); 

=item $header->expires

=item $header->header

=back

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
