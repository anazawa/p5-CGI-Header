package CGI::Header;
use 5.008_009;
use strict;
use warnings;
use Carp qw/croak/;

our $VERSION = '0.57';

my %PropertyAlias = (
    'content-type'  => 'type',
    'cookie'        => 'cookies',
    'set-cookie'    => 'cookies',
    'window-target' => 'target',
);

sub _normalize {
    my $class = shift;
    my $prop = lc shift;
    $prop =~ s/^-//;
    $prop =~ tr/_/-/;
    $prop = $PropertyAlias{$prop} if exists $PropertyAlias{$prop};
    $prop;
}

sub new {
    my $class  = shift;
    my $args   = $class->BUILDARGS( @_ );
    my $self   = bless { %$args }, $class;
    my $header = $self->{header};

    for my $key ( keys %$header ) {
        my $prop = $self->_normalize( $key );
        next if $key eq $prop; # $key is normalized
        croak "Property '$prop' already exists" if exists $header->{$prop};
        $header->{$prop} = delete $header->{$key}; # rename $key to $prop
    }

    $self->BUILD( $args );

    $self;
}

sub BUILDARGS {
    my $class = shift;
    my @args  = ref $_[0] eq 'HASH' ? %{$_[0]} : @_;

    return {
        header => {},
        @args,
    };
}

sub BUILD {
    # do nothing. Override in subclass
}

sub header {
    $_[0]->{header};
}

sub query {
    my $self = shift;
    $self->{query} ||= $self->_build_query;
}

sub _build_query {
    require CGI;
    CGI::self_or_default();
}

sub get {
    my ( $self, $key ) = @_;
    my $prop = $self->_normalize( $key );
    $self->{header}->{$prop};
}

sub set {
    my ( $self, $key, $value ) = @_;
    my $prop = $self->_normalize( $key );
    $self->{header}->{$prop} = $value;
}

sub exists {
    my ( $self, $key ) = @_;
    my $prop = $self->_normalize( $key );
    exists $self->{header}->{$prop};
}

sub delete {
    my ( $self, $key ) = @_;
    my $prop = $self->_normalize( $key );
    delete $self->{header}->{$prop};
}

sub clear {
    my $self = shift;
    undef %{ $self->{header} };
    $self;
}

BEGIN {
    for my $method (qw/
        attachment
        charset
        cookies
        expires
        location
        nph
        p3p
        status
        target
        type
    /) {
        my $body = sub {
            my $self = shift;
            return $self->{header}->{$method} unless @_;
            $self->{header}->{$method} = shift;
            $self;
        };

        no strict 'refs';
        *{$method} = $body;
    }
}

sub redirect {
    my ( $self, $url, $status ) = @_;
    $self->status( $status || '302 Found' )->location( $url );
}

sub finalize {
    my $self = shift;
    my $query = $self->query;
    my $header = $self->{header};
    $query->print( $query->header($header) );
    return;
}

sub clone {
    my $self = shift;
    my %header = %{ $self->{header} };
    ref( $self )->new( %$self, header => \%header );
}

1;

__END__

=head1 NAME

CGI::Header - Handle CGI.pm-compatible HTTP header properties

=head1 SYNOPSIS

  use CGI;
  use CGI::Header;

  my $query = CGI->new;

  # CGI.pm-compatible HTTP header properties
  my $header = CGI::Header->new(
      query => $query,
      header => {
          attachment => 'foo.gif',
          charset    => 'utf-7',
          cookies    => [ $cookie1, $cookie2 ], # CGI::Cookie objects
          expires    => '+3d',
          nph        => 1,
          p3p        => [qw/CAO DSP LAW CURa/],
          target     => 'ResultsWindow',
          type       => 'image/gif'
      },
  );

  # update $header
  $header->set( 'Content-Length' => 3002 ); # overwrite
  $header->delete('Content-Disposition'); # => 3002
  $header->clear; # => $self

  $header->finalize;

=head1 VERSION

This document refers to CGI::Header version 0.57.

=head1 DEPENDENCIES

This module is compatible with CGI.pm 3.51 or higher.

=head1 DESCRIPTION

This module is a utility class to manipulate a hash reference
received by CGI.pm's C<header()> method.

This module isn't the replacement of the C<header()> method, but complements
CGI.pm.

This module can be used in the following situation:

=over 4

=item 1. $header is a hash reference which represents CGI response headers

For example, L<CGI::Application> implements C<header_add()> method
which can be used to add CGI.pm-compatible HTTP header properties.
Instances of CGI.pm-based applications often hold those properties.

  my $header = { type => 'text/plain' };

=item 2. Manipulates $header using CGI::Header

Since property names are case-insensitive,
application developers have to normalize them manually
when they specify header properties.
CGI::Header normalizes them automatically.

  use CGI::Header;

  my $h = CGI::Header->new( header => $header );
  $h->set( 'Content-Length' => 3002 ); # add Content-Length header

  $header;
  # => {
  #     'type' => 'text/plain',
  #     'content-length' => '3002',
  # }

=item 3. Passes $header to CGI::header() to stringify the variable

  use CGI;

  print CGI::header( $header );
  # Content-length: 3002
  # Content-Type: text/plain; charset=ISO-8859-1
  #

C<header()> function just stringifies given header properties.
This module can be used to generate L<PSGI>-compatible response header
array references. See L<CGI::Header::PSGI>.

=back

=head2 ATTRIBUTES

=over 4

=item $header->query

Returns your current query object. This attribute defaults to the Singleton
instance of CGI.pm (C<$CGI::Q>), which is shared by functions exported
by the module.

=item $hashref = $header->header

Returns the header hash reference associated with this CGI::Header object.
This attribute defaults to a reference to an empty hash.
The hashref will be passed to CGI.pm's C<header> method to generate
CGI response headers. See C<CGI::Header#as_string>.

=back

=head2 METHODS

=over 4

=item $value = $header->get( $field )

=item $value = $header->set( $field => $value )

Get or set the value of the header field.
The header field name (C<$field>) is not case sensitive.

  # field names are case-insensitive
  $header->get('Content-Length');
  $header->get('content-length');

The C<$value> argument must be a plain string:

  $header->set( 'Content-Length' => 3002 );
  my $length = $header->get('Content-Length'); # => 3002

=item $bool = $header->exists( $field )

Returns a Boolean value telling whether the specified field exists.

  if ( $header->exists('ETag') ) {
      ...
  }

=item $value = $header->delete( $field )

Deletes the specified field form CGI response headers.
Returns the value of the deleted field.

  my $value = $header->delete('Content-Disposition'); # => 'inline'

=item $self = $header->clear

This will remove all header properties.

=item $header->finalize

Sends the response headers to the browser.

Valid multi-line header input is accepted when each line is separated
with a CRLF value (C<\r\n> on most platforms) followed by at least one space.
For example:

  $header->set( Ingredients => "ham\r\n\seggs\r\n\sbacon" );

Invalid multi-line header input will trigger in an exception.
When multi-line headers are received, this method will always output them
back as a single line, according to the folding rules of RFC 2616:
the newlines will be removed, while white space remains.

It's identical to:

  print STDOUT $query->header( $header->header );

=item $header->clone

Returns a copy of this C<CGI::Header> object.
The C<query> object is shared. 
The C<header> hashref is copied shallowly.
It's identical to:

  # surface copy
  my %header = %{ $original->header };

  my $clone = CGI::Header->new(
      query  => $original->query, # shares query object
      header => \%header
  );

=back

=head2 PROPERTIES

The following methods were named after property names recognized by
CGI.pm's C<header> method. Most of these methods can both be used to
read and to set the value of a property.

If you pass an argument to the method, the property value will be set,
and also the current object itself will be returned; therefore you can
chain methods as follows:

  $header->type('text/html')->charset('utf-8');

If no argument is supplied, the property value will be returned.
If the given property doesn't exist, C<undef> will be returned.

=over 4

=item $self = $header->attachment( $filename )

=item $filename = $header->attachment

Get or set the C<attachment> property.
Can be used to turn the page into an attachment.
Represents suggested name for the saved file.

  $header->attachment('genome.jpg');

In this case, the outgoing header will be formatted as:

  Content-Disposition: attachment; filename="genome.jpg"

=item $self = $header->charset( $character_set )

=item $character_set = $header->charset

Get or set the C<charset> property. Represents the character set sent to
the browser.

=item $self = $header->cookies( $cookie )

=item $self = $header->cookies([ $cookie1, $cookie2, ... ])

=item $cookies = $header->cookies

Get or set the C<cookies> property.
The parameter can be a L<CGI::Cookie> object or an arrayref which consists of
L<CGI::Cookie> objects.

=item $self = $header->expires( $format )

=item $format = $header->expires

Get or set the C<expires> property.
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

=item $self = $header->location( $url )

=item $url = $header->location

Get or set the Location header.

  $header->location('http://somewhere.else/in/movie/land');

=item $self = $header->nph( $bool )

=item $bool = $header->nph

Get or set the C<nph> property.
If set to a true value, will issue the correct headers to work
with a NPH (no-parse-header) script.

  $header->nph(1);

=item $tags = $header->p3p

=item $self = $header->p3p( $tags )

Get or set the C<p3p> property.
The parameter can be an arrayref or a space-delimited
string.

  $header->p3p([qw/CAO DSP LAW CURa/]);
  # or
  $header->p3p('CAO DSP LAW CURa');

In this case, the outgoing header will be formatted as:

  P3P: policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"

=item $self = $header->redirect( $url[, $status] );

Sets redirect URL with an optional HTTP status of the response,
which defaults to C<302 Found>. Returns this object itself.

  $header->redirect('http://somewhere.else/in/movie/land');

=item $self = $header->status( $status )

=item $status = $header->status

Get or set the Status header.

  $header->status('304 Not Modified');

=item $self = $header->target( $window_target )

=item $window_target = $header->target

Get or set the Window-Target header.

  $header->target('ResultsWindow');

=item $self = $header->type( $media_type )

=item $media_type = $header->type

Get or set the C<type> property. Represents the media type of the message
content.

  $header->type('text/html');

=back

=head2 NORMALIZING PROPERTY NAMES

Normalized property names are:

=over 4

=item 1. lowercased

  'Content-Length' -> 'content-length'

=item 2. use dashes instead of underscores in property name

  'content_length' -> 'content-length'

=back

CGI.pm's C<header> method also accepts aliases of property names.
This module converts them as follows:

 'content-type'  -> 'type'
 'cookie'        -> 'cookies'
 'set-cookie'    -> 'cookies'
 'window-target' -> 'target'

If a property name is duplicated, throws an exception:

  my $header = CGI::Header->new(
      header => {
          -Type        => 'text/plain',
          Content_Type => 'text/html',
      }
  );
  # die "Property 'type' already exists"

=head1 EXAMPLES

=head2 WRITING Blosxom PLUGINS

The following plugin just adds the Content-Length header
to CGI response headers sent by blosxom.cgi:

  package content_length;
  use Blosxom::Header;

  sub start {
      !$blosxom::static_entries;
  }

  sub last {
      my $h = Blosxom::Header->instance;
      $h->set( 'Content-Length' => length $blosxom::output );
  }

C<Blosxom::Header> is defined as follows:

  package Blosxom::Header;
  use parent 'CGI::Header';
  use Carp qw/croak/;

  our $INSTANCE;

  sub new {
      my $class = shift;
      croak "Private method 'new' called for $class";
  }

  sub instance {
      my $class = shift;
      $INSTANCE ||= $class->SUPER::new( header => $blosxom::header );
  }

  sub has_instance {
      $INSTANCE;
  }

Since L<Blosxom|http://blosxom.sourceforge.net/> depends on the procedural
interface of CGI.pm, you don't have to pass C<$query> to C<new()>
in this case.

=head2 HANDLING HTTP COOKIES

It's up to you to decide how to manage HTTP cookies.
The following method behaves like L<Mojo::Message::Response>'s C<cookies>
method:

  use parent 'CGI::Header';
  use CGI::Cookie;

  sub cookies {
      my $self    = shift;
      my $cookies = $self->header->{cookies} ||= [];

      return $cookies unless @_;

      if ( ref $_[0] eq 'HASH' ) {
          push @$cookies, map { CGI::Cookie->new($_) } @_;
      }
      else {
          push @$cookies, CGI::Cookie->new( @_ );
      }

      $self;
  }

You can use the C<cookies> method as follows:

  # get an arrayref which consists of CGI::Cookie objects
  my $cookies = $header->cookies;

  # push a CGI::Cookie object onto the "cookies" property
  $header->cookies( ID => 123456 );
  $header->cookies({ name => 'ID', value => 123456 });

=head2 WORKING WITH CGI::Simple

Since L<CGI::Simple> is "a relatively lightweight drop in
replacement for CGI.pm", this module is compatible with the module.
If you're using the procedural interface of the module
(L<CGI::Simple::Standard>), you need to override the C<_build_query> method
as follows:

  use parent 'CGI::Header';
  use CGI::Simple::Standard;

  sub _build_query {
      # NOTE: loader() is designed for debugging
      CGI::Simple::Standard->loader('_cgi_object');
  }

=head1 LIMITATIONS

Since the following strings conflict with property names,
you can't use them as field names (C<$field>):

  "Attachment"
  "Charset"
  "Cookie"
  "Cookies"
  "NPH"
  "Target"
  "Type"

=over 4

=item Content-Type

If you don't want to send the Content-Type header,
set the C<type> property to an empty string, though it's far from intuitive
manipulation:

  $header->type(q{});

  # doesn't work as you expect
  $header->delete('Content-Type');
  $header->type(undef);

=item Date

If one of the following conditions is met, the Date header will be set
automatically, and also the header field will become read-only:

  if ( $header->nph or $header->cookie or $header->expires ) {
      $header->set( 'Date' => 'Thu, 25 Apr 1999 00:40:33 GMT' ); # wrong
      $header->delete('Date'); # wrong
  }

=item P3P

You can't assign to the P3P header directly:

  # wrong
  $header->set( 'P3P' => '/path/to/p3p.xml' );

C<CGI::header()> restricts where the policy-reference file is located,
and so you can't modify the location (C</w3c/p3p.xml>).
You're allowed to set P3P tags using C<p3p()>.

=item Pragma

If the following condition is met, the Pragma header will be set
automatically, and also the header field will become read-only:

  if ( $header->query->cache ) {
      $header->set( 'Pragma' => 'no-cache' ); # wrong
      $header->delete('Pragma'); # wrong
  }

=item Server

If the following condition is met, the Server header will be set
automatically, and also the header field will become read-only: 

  if ( $header->nph ) {
      $header->set( 'Server' => 'Apache/1.3.27 (Unix)' ); # wrong
      $header->delete('Server'); # wrong
  }


=back

=head1 SEE ALSO

L<CGI>, L<HTTP::Headers>

=head1 BUGS

There are no known bugs in this module.
Please report problems to ANAZAWA (anazawa@cpan.org).
Patches are welcome.

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
