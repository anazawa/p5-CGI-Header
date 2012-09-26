use strict;
use warnings;
use CGI::Header;
use Test::More tests => 19;

my $class = 'CGI::Header';

my %alias = (
    TIEHASH => 'new',
    #FETCH   => 'get',
    #STORE   => 'set',
    #DELETE  => 'delete',
    #EXISTS  => 'exists',
);

can_ok $class, ( keys %alias, 'SCALAR' );

while ( my ($got, $expected) = each %alias ) {
    is $class->can($got), $class->can($expected);
}

my %adaptee;
tie my %adapter, $class, \%adaptee;

isa_ok tied %adapter, $class;

# SCALAR
%adaptee = ();
ok %adapter;
%adaptee = ( -type => q{} );
ok !%adapter;

# CLEAR
%adaptee = ();
%adapter = ();
is_deeply \%adaptee, { -type => q{} };

# EXISTS
%adaptee = ( -foo => 'bar', -bar => q{} );
ok exists $adapter{Foo};
ok !exists $adapter{Bar};
ok !exists $adapter{Baz};

# DELETE
%adaptee = ( -foo => 'bar', -bar => 'baz' );
is delete $adapter{Foo}, 'bar';
is_deeply \%adaptee, { -bar => 'baz' };

# FETCH
%adaptee = ( -foo => 'bar' );
is $adapter{Foo}, 'bar';
is $adapter{Bar}, undef;

# STORE
%adaptee = ();
$adapter{Foo} = 'bar';
is_deeply \%adaptee, { -foo => 'bar' };

