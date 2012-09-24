use strict;
use warnings;
use CGI::Header;
use CGI::Cookie;
use CGI::Util 'expires';
use Test::More tests => 17;
use Test::Warn;
use Test::Exception;

my $class = 'CGI::Header';

can_ok $class, qw(
    new clone clear delete exists get set is_empty each flatten
    date status
    DESTROY
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
    my $expected = qr{^Must provide a code reference to each\(\)};
    throws_ok { $header->each } $expected;

    %header = (
        -status         => '304 Not Modified',
        -content_length => 12345,
    );

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
        'Set-Cookie',      [ $cookie1, $cookie2 ],
        'Date',           expires(0, 'http'),
        'Content-length', '12345',
        'Content-Type',   'text/html; charset=ISO-8859-1',
    );

    is_deeply \@got, \@expected;
};

subtest 'status()' => sub {
    %header = ();
    is $header->status, 200;

    $header->status( 304 );
    is $header{-status}, '304 Not Modified';
    is $header->status, '304';

    my $expected = q{Unknown status code '999' passed to status()};
    warning_is { $header->status( 999 ) } $expected;
};

subtest 'target()' => sub {
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

subtest 'DESTROY()' => sub {
    my $h = $class->new;
    $h->DESTROY;
    ok !$h->header;
};
