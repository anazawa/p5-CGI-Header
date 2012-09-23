use strict;
use warnings;
use CGI::Header::Entity;
use Test::More tests => 16;

my $class = 'CGI::Header::Entity';

can_ok $class, qw(
    TIEHASH FETCH STORE DELETE EXISTS CLEAR SCALAR DESTROY
    header field_names
    p3p_tags expires nph attachment
    _normalize _denormalize _date_header_is_fixed
);

subtest 'TIEHASH()' => sub {
    my $got = $class->TIEHASH;
    isa_ok $got, $class;
    is_deeply $got->header, { -type => q{} };
    my %adaptee;
    $got = $class->TIEHASH( \%adaptee );
    is $got->header, \%adaptee;
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
