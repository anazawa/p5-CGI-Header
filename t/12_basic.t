use strict;
use warnings;
use CGI::Header;
use CGI::Cookie;
use CGI::Util 'expires';
use Test::More tests => 19;
use Test::Warn;
use Test::Exception;

my $class = 'CGI::Header';

can_ok $class, qw(
    new clone clear delete exists get set is_empty
    header field_names each flatten DESTROY
    p3p_tags expires nph attachment
);

subtest 'new()' => sub {
    my %header = ();
    my $header = $class->new( \%header );
    is $header->header, \%header;
    is_deeply $header->header, {};

    $header = $class->new;
    is_deeply $header->header, {};

    %header = ( -foo => 'bar' );
    $header = $class->new( \%header );
    is $header->header, \%header;
    is_deeply $header->header, { -foo => 'bar' };

    $header = $class->new( -foo => 'bar' );
    is_deeply $header->header, { -foo => 'bar' };
};

# initialize
my %header;
my $header = $class->new( \%header );

# exists()
%header = ( -foo => 'bar' );
ok $header->exists('Foo'), 'should return true';
ok !$header->exists('Bar'), 'should return false';

# get()
%header = ( -foo => 'bar' );
is $header->get('Foo'), 'bar';
is $header->get('Bar'), undef;

# clear()
%header = ( -foo => 'bar' );
$header->clear;
is_deeply \%header, { -type => q{} }, 'should be empty';

# set()
%header = ();
$header->set( Foo => 'bar' );
is_deeply \%header, { -foo => 'bar' };

# is_empty()
%header = ();
ok !$header->is_empty;
%header = ( -type => q{} );
ok $header->is_empty;

subtest 'delete()' => sub {
    %header = ();
    is $header->delete('Foo'), undef;
    %header = ( -foo => 'bar' );
    is $header->delete('Foo'), 'bar';
    is_deeply \%header, {};
};

subtest 'each()' => sub {
    my $header = CGI::Header->new(
        -status         => '304 Not Modified',
        -content_length => 12345,
    );

    my $expected = qr{^Must provide a code reference to each\(\)};
    throws_ok { $header->each } $expected;

    my @got;
    $header->each(sub {
        my ( $field, $value ) = @_;
        push @got, $field, $value;
    });

    my @expected = (
        'Status',         '304 Not Modified',
        'Content-length', '12345',
        'Content-Type',   'text/html; charset=ISO-8859-1',
    );

    is_deeply \@got, \@expected;
};

subtest 'flatten()' => sub {
    my $cookie1 = CGI::Cookie->new(
        -name  => 'foo',
        -value => 'bar',
    );

    my $cookie2 = CGI::Cookie->new(
        -name  => 'bar',
        -value => 'baz',
    );

    %header = (
        -status         => '304 Not Modified',
        -content_length => 12345,
        -cookie         => [ $cookie1, $cookie2 ],
    );

    my @got = $header->flatten;

    my @expected = (
        'Status',         '304 Not Modified',
        'Set-Cookie',      $cookie1,
        'Set-Cookie',      $cookie2,
        'Date',           expires(0, 'http'),
        'Content-length', '12345',
        'Content-Type',   'text/html; charset=ISO-8859-1',
    );

    is_deeply \@got, \@expected;
};

subtest 'status()' => sub {
    plan skip_all => 'obsolete';

    %header = ();
    is $header->status, 200;

    $header->status( 304 );
    is $header{-status}, '304 Not Modified';
    is $header->status, '304';

    my $expected = q{Unknown status code '999' passed to status()};
    warning_is { $header->status( 999 ) } $expected;
};

subtest 'target()' => sub {
    plan skip_all => 'obsolete';
    %header = ();
    is $header->target, undef;
    $header->target( 'ResultsWindow' );
    is $header->target, 'ResultsWindow';
    is_deeply \%header, { -target => 'ResultsWindow' };
};

subtest 'clone()' => sub {
    my $orig = $class->new( -foo => 'bar' );
    my $clone = $orig->clone;
    isnt $clone->header, $orig->header;
    is_deeply $clone->header, $orig->header;
};

subtest 'nph()' => sub {
    %header = ();

    $header->nph( 1 );
    ok $header->nph;
    ok $header{-nph} == 1;

    $header->nph( 0 );
    ok !$header->nph;
    ok $header{-nph} == 0;

    %header = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
    $header->nph( 1 );
    is_deeply \%header, { -nph => 1 }, '-date should be deleted';
};

subtest 'field_names()' => sub {
    %header = ( -type => q{} );
    is_deeply [ $header->field_names ], [], 'should return null array';

    %header = (
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

    my @got = $header->field_names;

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
    my $h = $class->new;
    $h->DESTROY;
    ok !$h->header;
};
