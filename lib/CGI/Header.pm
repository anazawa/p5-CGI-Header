package CGI::Header;
use 5.008_009;
use strict;
use warnings;
use CGI::Util qw//;
use Carp qw/carp croak/;
use Scalar::Util qw/refaddr/;
use List::Util qw/first/;

our $VERSION = '0.09';

my %header;

sub new {
    my $class = shift;
    my $header = ref $_[0] eq 'HASH' ? shift : { @_ };
    my $self = bless \do { my $anon_scalar }, $class;
    $header{ refaddr $self } = $header;
    $self;
}

sub header { $header{ refaddr $_[0] } }

sub DESTROY {
    my $self = shift;
    delete $header{ refaddr $self };
    return;
}

my %alias_of = (
    content_type => 'type',   window_target => 'target',
    cookies      => 'cookie', set_cookie    => 'cookie',
);

sub rehash {
    my $self   = shift;
    my $header = $header{ refaddr $self };

    for my $key ( keys %{$header} ) {
        my $norm = lc $key;
           $norm =~ s/^-//;
           $norm =~ tr/-/_/;
           $norm = '-' . ( $alias_of{$norm} || $norm );

        next if $key eq $norm;

        $header->{ $norm } = delete $header->{ $key };
    }

    $self;
}

my $get = sub { $_[0]->{$_[1]} };

my %get = (
    -content_disposition => sub {
        my $filename = $_[0]->{-attachment};
        $filename ? qq{attachment; filename="$filename"} : $get->( @_ );
    },
    -content_type => sub {
        my ( $type, $charset ) = @{ $_[0] }{qw/-type -charset/};
        return $type if $type and $type =~ /\bcharset\b/;
        return if defined $type and $type eq q{};
        $type ||= 'text/html';
        $charset ? "$type; charset=$charset" : $type;
    },
    -date => sub {
        my $is_fixed = first { $_[0]->{$_} } qw(-nph -expires -cookie);
        $is_fixed ? CGI::Util::expires() : $get->( @_ );
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
    -server => sub {
        $_[0]->{-nph} ? $ENV{SERVER_SOFTWARE} || 'cmdline' : $get->( @_ );
    },
    -set_cookie    => sub { $_[0]->{-cookie} },
    -window_target => sub { $_[0]->{-target} },
);

sub get {
    my $self = shift;
    my $norm = _normalize( shift );
    my $header = $header{ refaddr $self };
    $norm && ( $get{$norm} || $get )->( $header, $norm );
}

my $set = sub { $_[0]->{$_[1]} = $_[2] };

my %set = (
    -content_disposition => sub { $set->( @_ ); delete $_[0]->{-attachment} },
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
        $set->( @_ ) unless first { $_[0]->{$_} } qw(-nph -expires -cookie);
    },
    -expires => sub {
        carp "Can't assign to '-expires' directly, use expires() instead";
    },
    -p3p => sub {
        carp "Can't assign to '-p3p' directly, use p3p_tags() instead";
    },
    -server => sub { $_[0]->{-nph} || $set->( @_ ) },
    -set_cookie => sub {
        my ( $header, $value ) = @_[0, 2];
        delete $header->{-date} if $value;
        $header->{-cookie} = $value;
    },
    -window_target => sub { $_[0]->{-target} = $_[2] },
);

sub set {
    my $self = shift;
    my $norm = _normalize( shift );
    my $header = $header{ refaddr $self };
    ( $set{$norm} || $set )->( $header, $norm, @_ ) if $norm && @_;
    return;
}

my $exists = sub { exists $_[0]->{$_[1]} };

my %exists = (
    -content_type => sub { !defined $_[0]->{-type} || $_[0]->{-type} ne q{} },
    -content_disposition => sub { $exists->( @_ ) || $_[0]->{-attachment} },
    -date => sub {
        $exists->( @_ ) || first { $_[0]->{$_} } qw(-nph -expires -cookie);
    },
    -server => sub { $_[0]->{-nph} || $exists->( @_ ) },
    -set_cookie => sub { exists $_[0]->{-cookie} },
    -window_target => sub { exists $_[0]->{-target} },
);

sub exists {
    my $self = shift;
    my $norm = _normalize( shift );
    my $header = $header{ refaddr $self };
    $norm && ( $exists{$norm} || $exists )->( $header, $norm );
}

my $delete = sub { delete $_[0]->{$_[1]} };

my %delete = (
    -content_disposition => sub { delete @{$_[0]}{$_[1], '-attachment'} },
    -content_type => sub {
        my $header = shift; 
        delete $header->{-charset};
        $header->{-type} = q{};
    },
    -date => sub {
        my ( $header, $norm ) = @_;
        delete $header->{-date};
    },
    -expires => sub { delete $_[0]->{-expires} },
    -p3p => sub { delete $_[0]->{-p3p} },
    -server => sub {
        my ( $header, $norm ) = @_;
        delete $header->{ $norm };
    },
    -set_cookie => sub { delete $_[0]->{-cookie} },
    -window_target => sub { delete $_[0]->{-target} },
);

sub delete {
    my $self   = shift;
    my $field  = shift;
    my $norm   = _normalize( $field ) || return;
    my $header = $header{ refaddr $self };

    if ( my $delete = $delete{$norm} ) {
        my $value = defined wantarray && $get{$norm}->($header, $norm);
        $delete->( $header, $norm );
        return $value;
    }

    delete $header->{ $norm };
}

my %is_excluded = map { $_ => 1 }
    qw( attachment charset cookie cookies nph target type );

sub _normalize {
    ( my $norm = lc shift ) =~ tr/-/_/;
    $is_excluded{ $norm } ? undef : "-$norm";
}

sub is_empty { !$_[0]->SCALAR }

sub clear {
    my $self = shift;
    my $header = $header{ refaddr $self };
    %{ $header } = ( -type => q{} );
    return;
}

sub clone {
    my $self = shift;
    my $header = $header{ refaddr $self };
    ref( $self )->new( %{$header} );
}

BEGIN {
    my @conflicts = (
        attachment => [ '-content_disposition' ],
        nph        => [ '-date', '-server' ],
        expires    => [ '-date' ],
    );

    while ( my ($method, $conflicts) = splice @conflicts, 0, 2 ) {
        my $norm = "-$method";
        my $code = sub {
            my $self   = shift;
            my $header = $header{ refaddr $self };
    
            if ( @_ ) {
                my $value = shift;
                delete @{ $header }{ @$conflicts } if $value;
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
        return ref $tags eq 'ARRAY' ? @{$tags} : split ' ', $tags;
    }

    return;
}

my %is_reserved = map { $_ => 1 } qw(
    -attachment -charset -cookie -expires -nph
    -p3p        -status  -target -type
);

sub field_names {
    my $self   = shift;
    my $header = $header{ refaddr $self };

    my @fields;

    my ( $nph, $cookie, $expires, $type )
        = @{ $header }{qw/-nph -cookie -expires -type/};

    push @fields, 'Server' if $nph;

    push @fields, 'Status'        if exists $header->{-status};
    push @fields, 'Window-Target' if exists $header->{-target};
    push @fields, 'P3P'           if exists $header->{-p3p};

    push @fields, 'Set-Cookie' if $cookie;
    push @fields, 'Expires'    if $expires;
    push @fields, 'Date'       if $expires or $cookie or $nph;

    push @fields, 'Content-Disposition' if $header->{-attachment};

    # not ordered
    for my $norm ( keys %{$header} ) {
        next if $is_reserved{$norm};
        push @fields, _ucfirst($norm);
    }

    push @fields, 'Content-Type' if !defined $type or $type ne q{};

    @fields;
}

sub _ucfirst {
    my $str = shift;
    $str =~ s/^-(\w)/\u$1/;
    $str =~ tr/_/-/;
    $str;
}

sub each {
    my $self   = shift;
    my $code   = shift;
    my $header = $header{ refaddr $self };

    croak 'Must provide a code reference to each()' if ref $code ne 'CODE';

    for my $field ( $self->field_names ) {
        my $norm  = _normalize( $field );
        my $value = ( $get{$norm} || $get )->( $header, $norm );

        if ( ref $value eq 'ARRAY' ) {
            for my $v ( @{$value} ) {
                $code->( $field, $v ); # multi-valued header
            }
        }
        else {
            $code->( $field, $value );
        }
    }

    return;
}

sub flatten {
    my $self = shift;

    my @headers;
    $self->each(sub {
        my ( $field, $value ) = @_;
        $value = $value->as_string if ref $value eq 'CGI::Cookie';
        push @headers, $field, $value;
    });

    @headers;
}

sub as_string {
    my $self   = shift;
    my $eol    = defined $_[0] ? shift : "\015\012";
    my $header = $header{ refaddr $self };

    my @lines;

    # add Status-Line
    if ( $header->{-nph} ) {
        my $protocol = $ENV{SERVER_PROTOCOL} || 'HTTP/1.0';
        my $status   = $header->{-status}    || '200 OK';
        push @lines, "$protocol $status";
    }

    # add response headers
    $self->each(sub {
        my ( $field, $value ) = @_;
        $value = $value->as_string if ref $value eq 'CGI::Cookie';
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
    local $Data::Dumper::Terse  = 1;

    Data::Dumper::Dumper({
        __PACKAGE__, {
            header => $header{ $this },
        },
        @_,
    });
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
This class is, so to speak, a subclass of Hash
because the function behaves like a hash,
while Perl5 doesn't provide a built-in class called Hash.

This module isn't the replacement of the function.
Although this class implements C<as_string()> method,
the function should stringify the reference in most cases.

This module can be used in the following situation:

=over 4

=item 1. $header is a hash reference which represents CGI response headers

For exmaple, L<CGI::Application> implements C<header_add()> method
which can be used to add CGI.pm-compatible HTTP header properties.
Instances of CGI applications often hold those properties.

  my $header = { -type => 'text/plain' };

=item 2. Manipulates $header using CGI::Header

Since property names are case-insensitive,
application developers have to normalize them manually
when they specify header properties.
CGI::Header normalizes them automatically.

  use CGI::Header;

  my $h = CGI::Header->new( $header );
  $h->set( 'Content-Length' => 3002 ); # add Content-Length header

  $header;
  # => {
  #     -type => 'text/plain',
  #     -content_length => '3002',
  # }

=item 3. Passes $header to CGI::header() to stringify the variable

  use CGI;

  print CGI::header( $header );
  # Content-length: 3002
  # Content-Type: text/plain; charset=ISO-8859-1
  #

C<header()> function just stringifies given header properties.
This module can be used to generate L<PSGI>-compatible header
array references. See also C<flatten()>.

=back

=head2 CLASS METHOD

=over 4

=item $header = CGI::Header->new({ -type => 'text/plain', ... })

Given a header hash reference, returns a CGI::Header object
which holds a reference to the original given argument:

  my $header = { -type => 'text/plain' };
  my $h = CGI::Header->new( $header );

The object updates the reference when called write methods like C<set()>,
C<delete()> or C<clear()>:

  # updates $header
  $h->set( 'Content-Length' => 3002 );
  $h->delete( 'Content-Disposition' );
  $h->clear;

It also has C<header()> method that would return the same reference:

  $h->header; # same reference as $header

=item $header = CGI::Header->new( -type => 'text/plain', ... )

A shortcut for:

  my $header = CGI::Header->new({ -type => 'text/plain', ... });

=back

=head2 INSTANCE METHODS

=over 4

=item $header->header

Returns the header hash reference associated with this CGI::Header object.

=item $self = $header->rehash

Rebuilds the header hash to normalize parameter names
without changing the reference. Returns this object itself.
If parameter names aren't normalized, the methods listed below won't work
as you expect.

  my $h1 = $header->header;
  # => {
  #     '-content_type'   => 'text/plain',
  #     'Set-Cookie'      => 'ID=123456; path=/',
  #     'expires'         => '+3d',
  #     '-target'         => 'ResultsWindow',
  #     '-content-length' => '3002',
  # }

  $header->rehash;

  my $h2 = $header->header; # same reference as $h1
  # => {
  #     '-type'           => 'text/plain',
  #     '-cookie'         => 'ID=123456; path=/',
  #     '-expires'        => '+3d',
  #     '-target'         => 'ResultsWindow',
  #     '-content_length' => '3002',
  # }

Normalized parameter names are:

=over 4

=item 1. lowercased

  'Content-Length' -> 'content-length'

=item 2. start with a dash

  'content-length' -> '-content-length'

=item 3. use underscores instead of dashes except for the first character

  '-content-length' -> '-content_length'

=back

C<CGI::header()> also accepts aliases of parameter names.
This module converts them as follows:

 '-content_type'  -> '-type'
 '-set_cookie'    -> '-cookie'
 '-cookies'       -> '-cookie'
 '-window_target' -> '-target'

NOTE: C<new()> doesn't check whether parameter names are normalized
or not at all,
and so you have to C<rehash()> the header hash explicitly
when you aren't sure that they are normalized.

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

=item $bool = $header->is_empty

Returns true if the header contains no key-value pairs.

  $header->clear;

  if ( $header->is_empty ) { # true
      ...
  }

=item $header->clear

This will remove all header fields.

=item $clone = $header->clone

Returns a copy of this CGI::Header object.
It's identical to:

  my %copy = %{ $header->header };
  my $clone = CGI::Header->new( \%copy );

=item $filename = $header->attachment

=item $header->attachment( $filename )

Can be used to turn the page into an attachment.
Represents suggested name for the saved file.

  $header->attachment( 'genome.jpg' );
  my $filename = $header->attachment; # => "genome.jpg"

In this case, the outgoing header will be formatted as:

  Content-Disposition: attachment; filename="genome.jpg"

=item @tags = $header->p3p_tags

=item $header->p3p_tags( @tags )

Represents P3P tags. The parameter can be an array or a space-delimited
string. Returns a list of P3P tags. (In scalar context,
returns the number of P3P tags.)

  $header->p3p_tags(qw/CAO DSP LAW CURa/);
  # or
  $header->p3p_tags( 'CAO DSP LAW CURa' );

  my @tags = $header->p3p_tags; # => ("CAO", "DSP", "LAW", "CURa")

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
  my $nph = $header->nph; # => 1

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

  print join @lines, "\n";
  # Content-length: 3002
  # Content-Type: text/plain

=item @headers = $header->flatten

Returns pairs of fields and values. 

  my @headers = $header->flatten;
  # => ( 'Content-length', '3002', 'Content-Type', 'text/plain' )

It's identical to:

  my @headers;
  $self->each(sub {
      my ( $field, $value ) = @_;
      push @headers, $field, "$value"; # force stringification
  });

This method can be used to generate L<PSGI>-compatible header array references:

  my $status_code = $header->delete( 'Status' ) || '200 OK';
  $status_code =~ s/\D*$//;

  $header->nph( 0 ); # removes the Server header
  my @headers = $header->flatten;

See also L<CGI::Emulate::PSGI>, L<CGI::PSGI>.


=item $header->as_string

=item $header->as_string( $eol )

Returns the header fields as a formatted MIME header.
The optional C<$eol> parameter specifies the line ending sequence to use.
The default is C<\015\012>.

When valid multi-line headers are included, this method will always output
them back as a single line, according to the folding rules of RFC 2616:
the newlines will be removed, while the white space remains.

Unlike CGI.pm, when invalid newlines are included,
this module removes them instead of throwing exceptions.

=back

=head2 tie() INTERFACE

  use CGI::Header;

  my $header = { -type => 'text/plain' };
  tie my %header => 'CGI::Header' => $header;

  # update $header
  $header{'Content-Length'} = 3002;
  delete $header{'Content-Disposition'};
  %header = ();

Above methods are aliased as follows:

  TIEHASH -> new
  FETCH   -> get
  STORE   -> set
  DELETE  -> delete
  CLEAR   -> clear
  EXISTS  -> exists
  SCALAR  -> !is_empty

See also L<perltie>.

NOTE: C<FIRSTKEY()> and C<NEXTKEY()> aren't implemented,
and so you can't iterate through the tied hash.

  # doesn't work
  keys %header;
  values %header;
  each %header;

=head1 LIMITATIONS

=over 4

=item Can't set '-content_type' to neither undef nor an empty string

  # wrong
  $header->set( 'Content-Type' => undef );
  $header->set( 'Content-Type' => q{} );

Use delete() instead:

  $header->delete( 'Content-Type' );

=item Can't assign to '-expires' directly, use expires() instead

  # wrong
  $header->set( 'Expires' => '+3d' );

Use expires() instead:

  $header->expires( '+3d' );

because the following behavior will surprize us:

  $header->set( 'Expires' => '+3d' );

  my $value = $header->get( 'Expires' );
  # => "Thu, 25 Apr 1999 00:40:33 GMT" (not "+3d")

=item Can't assign to '-p3p' directly, use p3p_tags() instead

C<CGI::header()> restricts where the policy-reference file is located,
and so you can't modify the location (C</w3c/p3p.xml>).
The following code doesn't work as you expect:

  # wrong
  $header->set( 'P3P' => '/path/to/p3p.xml' );

You're allowed to set P3P tags using C<p3p_tags()>.

=back

=head1 SEE ALSO

L<CGI>, L<Plack::Util>

=head1 BUGS

There are no known bugs in this module.
Please report problems to ANAZAWA (anazawa@cpan.org).
Patches are welcome.

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
