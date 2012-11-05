use strict;
use warnings;
use CGI::Header;
use Test::More tests => 19;

my %alias = (
    'TIEHASH' => 'new',
    'FETCH'   => 'get',
    'STORE'   => 'set',
    'DELETE'  => 'delete',
    'EXISTS'  => 'exists',
    'CLEAR'   => 'clear',
);

can_ok 'CGI::Header', ( keys %alias, 'SCALAR' );

my $class = 'CGI::Header';
while ( my ($got, $expected) = each %alias ) {
    is $class->can($got), $class->can($expected);
}

my %adaptee;
tie my %adapter, 'CGI::Header', \%adaptee;

isa_ok tied %adapter, 'CGI::Header';

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
ok exists $adapter{Bar};
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
