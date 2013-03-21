package CGI::Header::Redirect;
use strict;
use warnings;
use base 'CGI::Header';
use Carp qw/carp croak/;

my %IS_RESERVED_NAME = map { $_, 1 }
    qw( -attachment -charset -cookie -cookies -nph -target -type -uri -url );

our %ALIASED_TO = (
    %CGI::Header::ALIASED_TO,
    -uri => '-location',
    -url => '-location',
);

sub get_alias {
    $ALIASED_TO{ $_[1] };
}

sub is_reserved_name {
    $IS_RESERVED_NAME{ $_[1] };
}

sub new {
    my ( $class, @args ) = @_;
    unshift @args, '-location' if ref $args[0] ne 'HASH' and @args == 1;
    $class->SUPER::new( @args );
}

my %GET = (
    content_type => sub {
        my $self = shift; 
        my $header = $self->{header};
        local $header->{-type} = q{} if !exists $header->{-type};
        $self->SUPER::get('Content-Type');
    },
    location => sub {
        my ( $self, $prop ) = @_; 
        $self->{header}->{$prop} || $self->_self_url;
    },
    status => sub {
        my ( $self, $prop ) = @_; 
        my $status = $self->{header}->{$prop};
        defined $status ? ( $status ne q{} ? $status : undef ) : '302 Found';
    },
);

sub get {
    my $self = shift;
    my $field = $self->normalize_field_name( shift );
    my $get = $GET{$field} || 'SUPER::get';
    $self->$get( "-$field" );
}

my %EXISTS = (
    content_type => sub {
        my $self = shift;
        my $header = $self->{header};
        my $type = exists $header->{-type} ? $header->{-type} : q{};
        !defined $type or $type ne q{};
    },
    location => sub {
        1;
    },
    status => sub {
        my ( $self, $prop ) = @_;
        my $status = $self->{header}->{$prop};
        !defined $status or $status ne q{};
    },
);

sub exists {
    my $self = shift;
    my $field = $self->normalize_field_name( shift );
    my $exists = $EXISTS{$field} || 'SUPER::exists';
    $self->$exists( "-$field" );
}

my %DELETE = (
    content_type => sub {
        my ( $self, $prop ) = @_;
        delete $self->{header}->{-type};
    },
    location => sub { croak "Can't delete the Location header" },
    status => sub {
        my ( $self, $prop ) = @_;
        $self->{header}->{$prop} = q{};
    },
);

sub delete {
    my $self  = shift;
    my $field = $self->normalize_field_name( shift );

    if ( my $delete = $DELETE{$field} ) {
        my $value = defined wantarray && $self->get( $field );
        $self->$delete( "-$field" );
        return $value;
    }

    $self->SUPER::delete( $field );
}

sub SCALAR {
    1;
}

sub clear {
    my $self = shift;
    carp "Can't delete the Location header";
    %{ $self->{header} } = ( -type => q{}, -status => q{} );
    $self->query->cache( 0 );
    $self;
}

sub flatten {
    my $self = shift;
    my $header = $self->{header};
    local $header->{-location} = $self->_self_url if !$header->{-location};
    local $header->{-status} = '302 Found' if !defined $header->{-status};
    local $header->{-type} = q{} if !exists $header->{-type};
    $self->SUPER::flatten( @_ );
}

sub _self_url {
    my $self = shift;
    $self->{_self_url} ||= $self->query->self_url;
}

sub as_string {
    my $self = shift;
    $self->query->redirect( $self->{header} );
}

1;

__END__

=head1 NAME

CGI::Header::Redirect - Adapter for CGI::redirect() function

=head1 SYNOPSIS

  use CGI::Header::Redirect;

  my $header = CGI::Header::Redirect->new(
      -uri    => 'http://somewhere.else/in/movie/land',
      -nph    => 1,
      -status => '301 Moved Permanently',
  );

=head1 DESCRIPTION

=head2 INHERITANCE

CGI::Header::Redirect is a subclass of L<CGI::Header>.

=head2 OVERRIDDEN METHODS

=over 4

=item $alias = CGI::Header::Redirect->get_alias( $prop )

C<uri> and C<url> are the alias of C<location>.

  CGI::Header::Redirect->get_alias('uri'); # => 'location'
  CGI::Header::Redirect->get_alias('url'); # => 'location'

=item $header = CGI::Header::Redirect->new( $url )

A shortcut for:

  my $h = CGI::Header::Redirect->new({ -location => $url });

=item $self = $header->clear

Unlike L<CGI::Header> objects, you cannot C<clear()> your
CGI::Header::Redirect object completely. The Location header always exists.

  $header->clear; # warn "Can't delete the Location header"

=item $bool = $header->is_empty

Always returns false.

=item $header->as_string

A shortcut for:

  $header->query->redirect( $header->header );

=back

=head1 LIMITATIONS

=over 4

=item Location

You can't delete the Location header. The header field always exists.

  # wrong
  $header->set( 'Location' => q{} );
  $header->set( 'Location' => undef );
  $header->delete('Location');

  if ( $header->exists('Location') ) { # always true
      ...
  }

=item Status

You can set the Status header to neither C<undef> nor an empty string:

  # wrong
  $header->set( 'Status' => undef );
  $header->set( 'Status' => q{} );

Use C<delete()> instead:

  $header->delete('Status');

=back

=head1 SEE ALSO

L<CGI>, L<CGI::Header>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
