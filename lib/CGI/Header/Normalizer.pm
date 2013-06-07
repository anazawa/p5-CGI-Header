package CGI::Header::Normalizer;
use strict;
use warnings;

sub new {
    my $class = shift;
    bless { alias => {}, @_ }, $class;
}

sub alias {
    $_[0]->{alias};
}

sub normalize {
    my ( $self, $key ) = @_;
    my $alias = $self->{alias};
    my $prop = lc $key;
    $prop =~ s/^-//;
    $prop =~ tr/_/-/;
    $prop = $alias->{$prop} if exists $alias->{$prop};
    $prop;
}

1;
