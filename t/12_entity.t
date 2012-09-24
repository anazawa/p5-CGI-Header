use strict;
use warnings;
use CGI::Header;
use Test::More tests => 16;

my $class = 'CGI::Header';

can_ok $class, qw(
    TIEHASH FETCH STORE DELETE EXISTS CLEAR SCALAR DESTROY
    header field_names
    p3p_tags expires nph attachment
    _normalize _denormalize
);

subtest 'TIEHASH()' => sub {
    my %header = ();
    my $header = $class->TIEHASH( \%header );
    is $header->header, \%header;
    is_deeply $header->header, {};

    %header = ( -foo => 'bar' );
    $header = $class->TIEHASH( \%header );
    is $header->header, \%header;
    is_deeply $header->header, { -foo => 'bar' };

    $header = $class->TIEHASH;
    is_deeply $header->header, {};
};

my %adaptee;
my $adapter = tie my %adapter, $class, \%adaptee;

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

subtest 'nph()' => sub {
    %adaptee = ();

    $adapter->nph( 1 );
    ok $adapter->nph;
    ok $adaptee{-nph} == 1;

    $adapter->nph( 0 );
    ok !$adapter->nph;
    ok $adaptee{-nph} == 0;

    %adaptee = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
    $adapter->nph( 1 );
    is_deeply \%adaptee, { -nph => 1 }, '-date should be deleted';
};

subtest 'field_names()' => sub {
    %adaptee = ( -type => q{} );
    is_deeply [ $adapter->field_names ], [], 'should return null array';

    %adaptee = (
        -nph        => 1,
        -status     => 1,
        -target     => 1,
        -p3p        => 1,
        -cookie     => 1,
        -expires    => 1,
        -attachment => 1,
        -foo_bar    => 1,
        -foo        => q{},
        -bar        => undef,
    );

    my @got = $adapter->field_names;

    my @expected = qw(
        Status
        Window-Target
        P3P
        Set-Cookie
        Expires
        Date
        Content-Disposition
        Foo-bar
        Content-Type
    );

    is_deeply \@got, \@expected;
};

subtest 'DESTROY()' => sub {
    $adapter->DESTROY;
    ok !$adapter->header;
};
