package CGI::Header::Redirect;
use strict;
use warnings;
use base 'CGI::Header';

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

for my $method (qw/flatten get exists SCALAR/) {
    my $super = "SUPER::$method";
    my $code = sub {
        my $self = shift;
        my $header = $self->{header};
        local $header->{-location} = $self->_self_url if !$header->{-location};
        local $header->{-status} = '302 Found' if !defined $header->{-status};
        local $header->{-type} = q{} if !exists $header->{-type};
        $self->$super( @_ );
    };

    no strict 'refs';
    *{ $method } = $code;
}

sub _self_url {
    my $self = shift;
    $self->{self_url} ||= $self->query->self_url;
}

# NOTE: Cannot delete the Location header
sub clear {
    my $self = shift;
    %{ $self->{header} } = ( -type => q{}, -status => q{} );
    $self->query->cache( 0 );
    $self;
}

sub as_string {
    my $self = shift;
    $self->query->redirect( $self->{header} );
}

1;
