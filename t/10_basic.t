use strict;
use warnings;
use CGI::Header;
use CGI::Cookie;
use CGI::Util;
use Test::More tests => 12;
use Test::Exception;

can_ok 'CGI::Header', qw(
    new header env rehash clone clear delete exists get set is_empty
    p3p_tags expires nph attachment field_names each flatten
);

subtest 'new()' => sub {
    my %header = ();
    my $header = CGI::Header->new( \%header );
    is $header->env, \%ENV;
    is $header->header, \%header;
    is_deeply $header->header, {};

    $header = CGI::Header->new;
    is_deeply $header->header, {};

    my %env;
    %header = ( -foo => 'bar' );
    $header = CGI::Header->new( \%header, \%env );
    is $header->env, \%env;
    is $header->header, \%header;
    is_deeply $header->header, { -foo => 'bar' };

    $header = CGI::Header->new( -foo => 'bar' );
    is_deeply $header->header, { -foo => 'bar' };
};

subtest '_lc()' => sub {
    my @data = (
        'Foo'      => '-foo',
        'Foo-Bar'  => '-foo_bar',
        '-foo'     => '-foo',
        '-foo_bar' => '-foo_bar',
    );

    while ( my ($input, $expected) = splice @data, 0, 2 ) {
        is CGI::Header::_lc($input), $expected;
    }
};

subtest 'basic' => sub {
    my %header;
    my $header = CGI::Header->new( \%header );

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
    is $header->clear, $header, "should return current object itself";
    is_deeply \%header, { -type => q{} }, 'should be empty';

    # set()
    %header = ();
    is $header->set( Foo => 'bar' ), 'bar';
    is_deeply \%header, { -foo => 'bar' };

    # is_empty()
    %header = ();
    ok !$header->is_empty;
    %header = ( -type => q{} );
    ok $header->is_empty;

    # delete()
    %header = ();
    is $header->delete('Foo'), undef;
    %header = ( -foo => 'bar' );
    is $header->delete('Foo'), 'bar';
    is_deeply \%header, {};
};

subtest 'rehash()' => sub {
    my $header = CGI::Header->new(
        '-content_type' => 'text/plain',
        'Set-Cookie'    => 'ID=123456; path=/',
        '-expires'      => '+3d',
        'foo'           => 'bar',
        'foo-bar'       => 'baz',
        'window_target' => 'ResultsWindow',
    );

    my $expected = $header->header;

    is $header->rehash, $header, 'should return the current object itself';
    is $header->header, $expected, 'should return the same reference';

    is_deeply $expected, {
        -type    => 'text/plain',
        -cookie  => 'ID=123456; path=/',
        -expires => '+3d',
        -foo     => 'bar',
        -foo_bar => 'baz',
        -target  => 'ResultsWindow',
    };

    $header = CGI::Header->new(
        -Type        => 'text/plain',
        Content_Type => 'text/html',
    );
    throws_ok { $header->rehash } qr{^Property '-type' already exists};
};

subtest 'clone()' => sub {
    my $header = CGI::Header->new( -foo => 'bar' );
    my $clone = $header->clone;
    isnt $clone->header, $header->header;
    is_deeply $clone->header, $header->header;

    my %env;
    $header = CGI::Header->new( {}, \%env );
    is $header->clone->env, \%env;
};

subtest 'nph()' => sub {
    my $header = CGI::Header->new;

    $header->nph( 1 );
    ok $header->nph;
    ok $header->header->{-nph} == 1;

    $header->nph( 0 );
    ok !$header->nph;
    ok $header->header->{-nph} == 0;

    %{ $header->header } = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
    $header->nph( 1 );
    is_deeply $header->header, { -nph => 1 }, '-date should be deleted';
};

subtest '_ucfirst()' => sub {
    is CGI::Header::_ucfirst( '-foo'     ), 'Foo';
    is CGI::Header::_ucfirst( '-foo_bar' ), 'Foo-bar';
};

subtest 'field_names()' => sub {
    my $header = CGI::Header->new;

    %{ $header->header } = ( -type => q{} );
    is_deeply [ $header->field_names ], [], 'should return null array';

    %{ $header->header } = (
        -nph        => 1,
        -status     => 1,
        -target     => 1,
        -p3p        => 1,
        -cookie     => 1,
        -expires    => 1,
        -attachment => 1,
        -foo_bar    => 1,
    );

    my @got = $header->field_names;

    my @expected = qw(
        Server
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

    is_deeply [ sort @got ], [ sort @expected ];
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
        'Content-Type',   'text/html',
    );
    is_deeply \@got, \@expected, 'default';

    @got = $header->flatten(0);
    @expected = (
        'Status',         '304 Not Modified',
        'Set-Cookie',     [ $cookie1, $cookie2 ],
        'Date',           CGI::Util::expires(),
        'Content-length', '12345',
        'Content-Type',   'text/html',
    );
    is_deeply \@got, \@expected, 'not recursive';
};

subtest 'each()' => sub {
    my $header = CGI::Header->new(
        -status         => '304 Not Modified',
        -content_length => 12345,
    );

    throws_ok { $header->each }
        qr{^Must provide a code reference to each\(\)};

    my @got;
    $header->each(sub {
        my ( $field, $value ) = @_;
        push @got, $field, $value;
    });

    my @expected = (
        'Status',         '304 Not Modified',
        'Content-length', '12345',
        'Content-Type',   'text/html',
    );

    is_deeply \@got, \@expected;

    is $header->each(sub {}), $header, "should return current object itself";
};

subtest 'as_string()' => sub {
    my $CRLF = "\015\012";
    my $header = CGI::Header->new;
    is $header->as_string, "Content-Type: text/html$CRLF";
    is $header->as_string("\n"), "Content-Type: text/html\n";

    $header->nph(1);
    my $expected
        = "HTTP/1.0 200 OK$CRLF"
        . "Server: cmdline$CRLF"
        . "Date: " . CGI::Util::expires() . $CRLF
        . "Content-Type: text/html$CRLF";
    is $header->as_string, $expected;
};
