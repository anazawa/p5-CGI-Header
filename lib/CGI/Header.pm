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

{
    my $get = sub { $_[0]->{$_[1]} };

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
            my $expires = $get->( @_ );
            $expires && CGI::Util::expires( $expires );
        },
        -p3p => sub {
            my $tags = $get->( @_ );
            $tags = join ' ', @{ $tags } if ref $tags eq 'ARRAY';
            $tags && qq{policyref="/w3c/p3p.xml", CP="$tags"};
        },
        -content_disposition => sub {
            my ( $header ) = @_;
            my $filename = $header->{-attachment};
            $filename ? qq{attachment; filename="$filename"} : $get->( @_ );
        },
        -date => sub {
            my ( $header ) = @_;
            my $is_fixed = first { $header->{$_} } qw(-nph -expires -cookie);
            $is_fixed ? CGI::Util::expires() : $get->( @_ );
        },
        -window_target => sub { shift->{-target} },
        -set_cookie    => sub { shift->{-cookie} },
    );

    sub get {
        my $self = shift;
        my $norm = _normalize( shift );
        my $header = $header_of{ refaddr $self };
        $norm && do { $get{$norm} || $get }->( $header, $norm );
    }
}

{
    my $set = sub { $_[0]->{$_[1]} = $_[2] };

    my %set = (
        -content_type => sub {
            my ( $header, $norm, $value ) = @_;
            $header->{-type} = $value;
            $header->{-charset} = q{};
        },
        -expires => sub {
            carp "Can't assign to '-expires' directly, use expires() instead";
        },
        -p3p => sub {
            carp "Can't assign to '-p3p' directly, use p3p_tags() instead";
        },
        -content_disposition => sub {
            my ( $header, $norm, $value ) = @_;
            delete $header->{-attachment} if $value;
            $set->( @_ );
        },
        -set_cookie => sub {
            my ( $header, $norm, $value ) = @_;
            delete $header->{-date} if $value;
            $header->{-cookie} = $value;
        },
        -date => sub {
            my ( $header, $norm ) = @_;
            return if first { $header->{$_} } qw(-nph -expires -cookie);
            $set->( @_ );
        },
        -window_target => sub {
            my ( $header, $norm, $value ) = @_;
            $header->{-target} = $value;
        },
    );

    sub set {
        my $self = shift;
        my $norm = _normalize( shift );
        my $header = $header_of{ refaddr $self };
        do { $set{$norm} || $set }->( $header, $norm, @_ ) if $norm;
        return;
    }
}

{
    my $exists = sub { $_[0]->{$_[1]} && 1 };

    my %exists = (
        -content_type => sub {
            my $header = shift;
            !defined $header->{-type} || $header->{-type} ne q{};
        },
        -content_disposition => sub {
            my ( $header ) = @_;
            return 1 if $header->{-attachment};
            $exists->( @_ );
        },
        -date => sub {
            my ( $header ) = @_;
            return 1 if first { $header->{$_} } qw(-nph -expires -cookie );
            $exists->( @_ );
        },
        -window_target => sub { shift->{-target} && 1 },
        -set_cookie    => sub { shift->{-cookie} && 1 },
    );

    sub exists {
        my $self = shift;
        my $norm = _normalize( shift );
        my $header = $header_of{ refaddr $self };
        $norm && do { $exists{$norm} || $exists }->( $header, $norm );
    }
}

{
    my $delete = sub { delete $_[0]->{$_[1]} };

    my %delete = (
        -content_type => sub {
            my ( $header ) = @_;
            delete $header->{-charset};
            $header->{-type} = q{};
            $delete->( @_ );
        },
        -content_disposition => sub {
            my ( $header ) = @_;
            delete $header->{-attachment};
            $delete->( @_ );
        },
        -window_target => sub { delete shift->{-target} },
        -set_cookie    => sub { delete shift->{-cookie} },
    );

    sub delete {
        my ( $self, $field ) = @_;
        my $norm = _normalize( $field );
        my $value = defined wantarray && $self->get( $field );
        my $header = $header_of{ refaddr $self };
        do { $delete{$norm} || $delete }->( $header, $norm ) if $norm;
        $value;
    }
}

{
    my %is_excluded = map { $_ => 1 }
        qw( -attachment -charset -cookie -nph -target -type );

    sub _normalize {
        my $norm = lc shift;
        $norm =~ tr/-/_/;
        $norm = "-$norm";
        $is_excluded{ $norm } ? q{} : $norm;
    }
}

sub clone {
    my $self = shift;
    my $class = ref $self or croak "Can't clone non-object: $self";
    my $header = $header_of{ refaddr $self };
    $class->new( %{ $header } );
}

sub is_empty { !shift->SCALAR }

sub clear {
    my $self = shift;
    my $header = $header_of{ refaddr $self };
    %{ $header } = ( -type => q{} );
    return;
}

BEGIN { # make accessors
    my $get_code = sub {
        my ( $norm, $conflict_with ) = @_;

        return sub {
            my $self   = shift;
            my $header = $header_of{ refaddr $self };
    
            if ( @_ ) {
                my $value = shift;
                delete $header->{ $conflict_with } if $value;
                $header->{ $norm } = $value;
            }

            $header->{ $norm };
        };
    };

    *attachment = $get_code->( '-attachment', '-content_disposition' );
    *nph        = $get_code->( '-nph',     '-date' );
    *expires    = $get_code->( '-expires', '-date' );
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
        push @headers, map { $field => "$_" } @values; # force stringify
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
    my $header = $header_of{ refaddr $self };

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

sub as_hashref {
    my $self = shift;
    tie my %header, ref $self, $header_of{ refaddr $self };
    \%header;
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

BEGIN {
    *TIEHASH = \&new;    *FETCH  = \&get;    *STORE = \&set;
    *EXISTS  = \&exists; *DELETE = \&delete; *CLEAR = \&clear;    
}

sub SCALAR {
    my $self = shift;
    my $header = $header_of{ refaddr $self };
    !defined $header->{-type} || first { $_ } values %{ $header };
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
