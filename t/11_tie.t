use strict;
use warnings;
use CGI::Header;
use Test::More tests => 20;

my %alias = (
    'TIEHASH' => 'new',
    'FETCH'   => 'get',
    'STORE'   => 'set',
    'DELETE'  => 'delete',
    'EXISTS'  => 'exists',
    'CLEAR'   => 'clear',
);

can_ok 'CGI::Header', ( keys %alias, 'FIRSTKEY', 'NEXTKEY' );

my $class = 'CGI::Header';
while ( my ($got, $expected) = each %alias ) {
    is $class->can($got), $class->can($expected);
}

my $header = tie my %header, 'CGI::Header';

isa_ok tied %header, 'CGI::Header';

# SCALAR
%{ $header->header } = ();
ok %header;
%{ $header->header } = ( -type => q{} );
ok !%header;

# CLEAR
%{ $header->header } = ();
%header = ();
is_deeply $header->header, { -type => q{} };

# EXISTS
%{ $header->header } = ( -foo => 'bar', -bar => undef );
ok exists $header{Foo};
ok exists $header{Bar};
ok !exists $header{Baz};

# DELETE
%{ $header->header } = ( -foo => 'bar', -bar => 'baz' );
is delete $header{Foo}, 'bar';
is_deeply $header->header, { -bar => 'baz' };

# FETCH
%{ $header->header } = ( -foo => 'bar' );
is $header{Foo}, 'bar';
is $header{Bar}, undef;

# STORE
%{ $header->header } = ();
$header{Foo} = 'bar';
is_deeply $header->header, { -foo => 'bar' };

# FIRSTKEY and NEXTKEY
%{ $header->header } = ( -foo => 'bar' );
is_deeply [ sort keys %header ], [ 'Content-Type', 'Foo' ];

