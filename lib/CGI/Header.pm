package CGI::Header;
use 5.008_009;
use strict;
use warnings;
use overload q{""} => 'as_string', fallback => 1;
#use CGI::Header::Dispatcher;
use CGI::Util qw//;
use Carp qw/carp croak/;
use Scalar::Util qw/refaddr/;
use List::Util qw/first/;

our $VERSION = '0.01';

my %header_of;

sub new {
    my $class = shift;
    my $header = ref $_[0] eq 'HASH' ? shift : { @_ };
    my $self = bless \do { my $anon_scalar }, $class;
    $header_of{ refaddr $self } = $header;
    $self;
}

sub header { $header_of{ refaddr shift } }

sub DESTROY {
    my $self = shift;
    delete $header_of{ refaddr $self };
    return;
}

my %get = (
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
    -expires => sub {
        my $header = shift;
        my $expires = $header->{-expires};
        $expires && CGI::Util::expires( $expires );
    },
    -p3p => sub {
        my $header = shift;
        my $tags = $header->{-p3p};
        $tags = join ' ', @{ $tags } if ref $tags eq 'ARRAY';
        $tags && qq{policyref="/w3c/p3p.xml", CP="$tags"};
    },
    -content_disposition => sub {
        my $header = shift;
        my $filename = $header->{-attachment};
        return qq{attachment; filename="$filename"} if $filename;
        $header->{-content_disposition};
    },
    -date => sub {
        my $header = shift;
        _is_fixed( $header ) ? CGI::Util::expires() : $header->{-date};
    },
);

sub get {
    my $self   = shift;
    my $norm   = _normalize( shift );
    my $header = $header_of{ refaddr $self };

    if ( my $handler = $get{$norm} ) {
        return $handler->( $header );
    }

    $header->{ $norm };
}

my %set = (
    -content_type => sub {
        my $header = shift;
        $header->{-type} = shift;
        $header->{-charset} = q{};
    },
    -expires => sub {
        carp "Can't assign to '-expires' directly, use expires() instead";
    },
    -p3p => sub {
        carp "Can't assign to '-p3p' directly, use p3p_tags() instead";
    },
    -content_disposition => sub {
        my ( $header, $value ) = @_; 
        delete $header->{-attachment} if $value;
        $header->{-content_disposition} = $value;
    },
    -cookie => sub {
        my ( $header, $value ) = @_;
        delete $header->{-date} if $value;
        $header->{-cookie} = $value;
    },
);

sub set {
    my $self   = shift;
    my $norm   = _normalize( shift );
    my $value  = shift;
    my $header = $header_of{ refaddr $self };

    if ( my $handler = $set{$norm} ) {
        $handler->( $header, $value );
    }
    else {
        $header->{ $norm } = $value;
    }

    return;
}

sub exists {
    my $self   = shift;
    my $norm   = _normalize( shift );
    my $header = $header_of{ refaddr $self };

    if ( $norm eq '-content_type' ) {
        return 1 if !defined $header->{-type} || $header->{-type} ne q{};
    }
    elsif ( $norm eq '-content_disposition' ) {
        return 1 if $header->{-attachment};
    }
    elsif ( $norm eq '-date' ) {
        return 1 if _is_fixed( $header );
    }

    $header->{ $norm };
}

sub delete {
    my $self   = shift;
    my $field  = shift;
    my $norm   = _normalize( $field );
    my $value  = defined wantarray && $self->get( $field );
    my $header = $header_of{ refaddr $self };

    if ( $norm eq '-content_type' ) {
        delete $header->{-charset};
        $header->{-type} = q{};
    }
    elsif ( $norm eq '-content_disposition' ) {
        delete $header->{-attachment};
    }

    delete $header->{ $norm };

    $value;
}

sub _is_fixed {
    my $header = shift;
    $header->{-nph} || $header->{-expires} || $header->{-cookie};
}

my %norm_of = (
    -attachment    => q{},        -charset => q{},
    -cookie        => q{},        -nph     => q{},
    -target        => q{},        -type    => q{},
    -window_target => q{-target}, -set_cookie => q{-cookie},
);

sub _normalize {
    my $field = lc shift;

    # transliterate dashes into underscores
    $field =~ tr{-}{_};

    # add an initial dash
    $field = "-$field";

    exists $norm_of{$field} ? $norm_of{ $field } : $field;
}

sub clone {
    my $self = shift;
    my $class = ref $self or croak "Can't clone non-object: $self";
    my $header = $header_of{ refaddr $self };
    $class->new( %{ $header } );
}

sub is_empty { !shift->SCALAR }

sub SCALAR {
    my $self = shift;
    my $header = $header_of{ refaddr $self };
    !defined $header->{-type} || first { $_ } values %{ $header };
}

sub clear {
    my $self = shift;
    my $header = $header_of{ refaddr $self };
    %{ $header } = ( -type => q{} );
    return;
}

sub attachment {
    my $self   = shift;
    my $header = $header_of{ refaddr $self };

    if ( @_ ) {
        my $filename = shift;
        delete $header->{-content_disposition} if $filename;
        $header->{-attachment} = $filename;
        return;
    }

    $header->{-attachment};
}

sub field_names {
    my $self   = shift;
    my $header = $header_of{ refaddr $self };
    my %header = %{ $header }; # copy

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
        push @fields, _denormalize( $norm ) if $value;
    }

    push @fields, 'Content-Type' if !defined $type or $type ne q{};

    @fields;
}

my %field_name_of = (
    -attachment => 'Content-Disposition', -cookie => 'Set-Cookie',
    -p3p        => 'P3P',                 -target => 'Window-Target',
    -type       => 'Content-Type',
);

sub _denormalize {
    my $norm = shift;

    unless ( exists $field_name_of{$norm} ) {
        ( my $field = $norm ) =~ s/^-//;
        $field =~ tr/_/-/;
        $field_name_of{ $norm } = ucfirst $field;
    }

    $field_name_of{ $norm };
}

sub nph {
    my $self   = shift;
    my $header = $header_of{ refaddr $self };
    
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
    my $header = $header_of{ refaddr $self };

    if ( @_ ) {
        $header->{-p3p} = @_ > 1 ? [ @_ ] : shift;
    }
    elsif ( my $tags = $header->{-p3p} ) {
        my @tags = ref $tags eq 'ARRAY' ? @{ $tags } : split ' ', $tags;
        return wantarray ? @tags : $tags[0];
    }

    return;
}

sub expires {
    my $self   = shift;
    my $header = $header_of{ refaddr $self };

    if ( @_ ) {
        my $expires = shift;
        delete $header->{-date} if $expires;
        $header->{-expires} = $expires;
        return;
    }

    $header->{-expires};
}

sub flatten {
    my $self = shift;

    my @headers;
    for my $field ( $self->field_names ) {
        my $value = $self->get( $field );
        my @values = ref $value eq 'ARRAY' ? @{ $value } : $value;
        push @headers, map { $field => $_ } @values;
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
    my $self = shift;
    my $eol  = defined $_[0] ? shift : "\015\012";

    my @lines;

    if ( $self->nph ) {
        my $software = $ENV{SERVER_SOFTWARE} || 'cmdline';
        my $protocol = $ENV{SERVER_PROTOCOL} || 'HTTP/1.0';
        my $status = $self->get( 'Status' ) || '200 OK';
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

#sub as_hashref {
#    my $self = shift;
#    my $this = refaddr $self;
#    tie my %header, ref $self, $header_of{ $this };
#    \%header;
#}

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

BEGIN {
    *TIEHASH = \&new;    *FETCH  = \&get;    *STORE = \&set;
    *EXISTS  = \&exists; *DELETE = \&delete; *CLEAR = \&clear;    
}

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
