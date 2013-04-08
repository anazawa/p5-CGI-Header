use strict;
use warnings;
use Test::MockTime qw/set_fixed_time/;
use CGI;
use CGI::Header;
use CGI::Cookie;
use CGI::Util;
use Test::More tests => 9;
use Test::Exception;

set_fixed_time( 1341637509 );

can_ok 'CGI::Header', qw(
    new header query rehash clone clear delete exists get set
    p3p expires nph attachment flatten
);

subtest 'normalize_property_name()' => sub {
    my @data = (
        'Foo'      => 'foo',
        'Foo-Bar'  => 'foo-bar',
        '-foo'     => 'foo',
        '-foo_bar' => 'foo-bar',
        '-content_type'  => 'type',
        '-cookies'       => 'cookie',
        '-set_cookie'    => 'cookie',
        '-window_target' => 'target',
    );

    while ( my ($input, $expected) = splice @data, 0, 2 ) {
        is( CGI::Header->normalize_property_name($input), $expected );
    }
};

subtest 'new()' => sub {
    my %header = ();
    my $header = CGI::Header->new( \%header );
    is $header->query, $CGI::Q;
    is $header->header, \%header;
    is_deeply $header->header, {};

    $header = CGI::Header->new;
    is_deeply $header->header, {};

    my $query = CGI->new;
    %header = ( -foo => 'bar' );
    $header = CGI::Header->new( \%header, $query );
    is $header->query, $query;
    is $header->header, \%header;
    is_deeply $header->header, { -foo => 'bar' };

    $header = CGI::Header->new( -foo => 'bar' );
    is_deeply $header->header, { foo => 'bar' };

    $header = CGI::Header->new(
        '-Charset'      => 'utf-8',
        '-content_type' => 'text/plain',
        'Set-Cookie'    => 'ID=123456; path=/',
        '-expires'      => '+3d',
        'foo'           => 'bar',
        'foo-bar'       => 'baz',
        'window_target' => 'ResultsWindow',
        'charset'       => 'EUC-JP',
    );
    is_deeply $header->header, {
        type    => 'text/plain',
        charset => 'EUC-JP',
        cookie  => 'ID=123456; path=/',
        expires => '+3d',
        foo     => 'bar',
        'foo-bar' => 'baz',
        target  => 'ResultsWindow',
    };

    $header = CGI::Header->new('text/plain');
    is_deeply $header->header, { -type => 'text/plain' };

    throws_ok { CGI::Header->new( -foo => 'bar', '-baz' ) }
        qr{^Odd number of elements in hash assignment};

    $header = CGI::Header->new( -query => 'a plain string' );
    is_deeply $header->header, { query => 'a plain string' };
};

subtest 'basic' => sub {
    my %header;
    my $header = CGI::Header->new( \%header );

    # exists()
    %header = ( foo => 'bar' );
    ok $header->exists('Foo'), 'should return true';
    ok !$header->exists('Bar'), 'should return false';

    # get()
    %header = ( foo => 'bar' );
    is $header->get('Foo'), 'bar';
    is $header->get('Bar'), undef;

    # clear()
    %header = ( foo => 'bar' );
    is $header->clear, $header, "should return current object itself";
    is_deeply \%header, { type => q{} }, 'should be empty';

    # set()
    %header = ();
    is $header->set( Foo => 'bar' ), 'bar';
    is_deeply \%header, { foo => 'bar' };

    # delete()
    %header = ();
    is $header->delete('Foo'), undef;
    %header = ( foo => 'bar' );
    is $header->delete('Foo'), 'bar';
    is_deeply \%header, {};
};

subtest 'rehash()' => sub {
    my $header = CGI::Header->new({
        '-content_type' => 'text/plain',
        'Set-Cookie'    => 'ID=123456; path=/',
        '-expires'      => '+3d',
        'foo'           => 'bar',
        'foo-bar'       => 'baz',
        'window_target' => 'ResultsWindow',
    });

    my $expected = $header->header;

    is $header->rehash, $header, 'should return the current object itself';
    is $header->header, $expected, 'should return the same reference';

    is_deeply $expected, {
        type    => 'text/plain',
        cookie  => 'ID=123456; path=/',
        expires => '+3d',
        foo     => 'bar',
        'foo-bar' => 'baz',
        target  => 'ResultsWindow',
    };

    $header = CGI::Header->new({
        -Type        => 'text/plain',
        Content_Type => 'text/html',
    });
    throws_ok { $header->rehash } qr{^Property 'type' already exists};
};

subtest 'clone()' => sub {
    my $header = CGI::Header->new( -foo => 'bar' );
    my $clone = $header->clone;
    isnt $clone->header, $header->header;
    is_deeply $clone->header, $header->header;

    my $query = CGI->new;
    $header = CGI::Header->new( {}, $query );
    is $header->clone->query, $query;
};

subtest 'nph()' => sub {
    my $header = CGI::Header->new;

    $header->nph( 1 );
    ok $header->nph;
    ok $header->header->{nph} == 1;

    $header->nph( 0 );
    ok !$header->nph;
    ok $header->header->{nph} == 0;
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

    my $header = CGI::Header->new(
        -status         => '304 Not Modified',
        -content_length => 12345,
        -cookie         => [ $cookie1, $cookie2 ],
    );

    my @got = $header->flatten;
    my @expected = (
        'Status',         '304 Not Modified',
        'Set-Cookie',     "$cookie1",
        'Set-Cookie',     "$cookie2",
        'Date',           CGI::Util::expires(),
        'Content-length', '12345',
        'Content-Type',   'text/html; charset=ISO-8859-1',
    );
    is_deeply \@got, \@expected, 'default';
};

subtest 'as_string()' => sub {
    my $header = CGI::Header->new;
    is $header->as_string, CGI::header();
};
