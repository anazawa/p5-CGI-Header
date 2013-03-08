package CGI::Header::Redirect;
use strict;
use warnings;
use base 'CGI::Header';
use Carp qw/carp croak/;

my %ALIAS = (
    content_type => 'type',     window_target => 'target',
    cookies      => 'cookie',   set_cookie    => 'cookie',
    uri          => 'location', url           => 'location',
);

sub get_alias {
    $ALIAS{ $_[1] };
}

sub new {
    my ( $class, @args ) = @_;
    unshift @args, '-location' if ref $args[0] ne 'HASH' and @args == 1;
    $class->SUPER::new( @args );
}

for my $method (qw/flatten get exists/) {
    my $orig = "SUPER::$method";
    my $code = sub {
        my $self = shift;
        my $header = $self->{header};
        local $header->{-location} = $self->_self_url if !$header->{-location};
        local $header->{-status} = '302 Found' if !defined $header->{-status};
        local $header->{-type} = q{} if !exists $header->{-type};
        $self->$orig( @_ );
    };

    no strict 'refs';
    *{ $method } = $code;
}

my %DELETE = (
    location => sub { croak $CGI::Header::MODIFY },
    status => sub {
        my ( $self, $prop ) = @_;
        my $value = defined wantarray && $self->get( $prop );
        $self->{header}->{$prop} = q{};
        $value;
    },
);

sub delete {
    my $self = shift;
    my $prop = $self->_normalize( shift );
    my $delete = $DELETE{$prop} || 'SUPER::delete';
    $self->$delete( "-$prop" );
}

sub _self_url {
    my $self = shift;
    $self->{_self_url} ||= $self->query->self_url;
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

=item $header = CGI::Header::Redirect->new( $url )

A shortcut for:

  my $h = CGI::Header::Redirect->new({ -location => $url });

=item $self = $header->clear

Unlike L<CGI::Header> objects, you cannot C<clear()> your
CGI::Header::Redirect object. The Location header always exists.

  $header->clear; # warn "Can't delete the Location header"

=item $bool = $header->is_empty

Always returns false.

=item $header->as_string

A shortcut for:

  $header->query->redirect( $header->header );

=back

=head1 SEE ALSO

L<CGI>, L<CGI::Header>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
