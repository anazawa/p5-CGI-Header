package CGI::Header;
use 5.008_009;
use strict;
use warnings;
use overload q{""} => 'as_string', fallback => 1;
use Carp qw/carp croak/;
use CGI::Header::Dispatcher;
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

sub get    { shift->dispatch( 'get',    @_ ) }
sub set    { shift->dispatch( 'set',    @_ ) }
sub delete { shift->dispatch( 'delete', @_ ) }
sub exists { shift->dispatch( 'exists', @_ ) }

sub clear    { shift->dispatch('clear')   }
sub is_empty { !shift->dispatch('scalar') }

BEGIN {
    *TIEHASH = \&new;   *STORE  = \&set;    *FETCH  = \&get;
    *CLEAR   = \&clear; *EXISTS = \&exists; *DELETE = \&delete;
}

sub SCALAR { shift->dispatch('scalar') }

sub field_names { shift->dispatch('keys') }

sub flatten {
    my $self = shift;
    map { $_, $self->dispatch('get', $_) } $self->dispatch('keys');
}

sub each {
    my ( $self, $callback ) = @_;

    if ( ref $callback eq 'CODE' ) {
        for my $field ( $self->dispatch('keys') ) {
            $callback->( $field, $self->dispatch('get', $field) );
        }
    }
    else {
        croak 'Must provide a code reference to each()';
    }

    return;
}

sub as_string {
    my $self = shift;
    my $eol  = defined $_[0] ? shift : "\n";

    my @lines;

    if ( $self->nph ) {
        my $protocol = $ENV{SERVER_PROTOCOL} || 'HTTP/1.0';
        my $software = $ENV{SERVER_SOFTWARE} || 'cmdline';
        my $status   = $self->get('Status')  || '200 OK';
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
