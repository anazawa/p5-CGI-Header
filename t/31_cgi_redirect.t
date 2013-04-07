use strict;
use CGI;
use CGI::Header::Redirect;
use Test::Exception;
#use Test::More tests => 4;
use Test::More skip_all => 'CGI::Header::Redirect is obsolete';

subtest 'default' => sub {
    my $url = 'http://somewhere.else/in/movie/land';
    my $header = CGI::Header::Redirect->new( $url );

    isa_ok $header, 'CGI::Header';

    my @data = (
        '-url' => '-location',
        '-uri' => '-location',
    );

    while ( my ($input, $expected) = splice @data, 0, 2 ) {
        is $header->normalize_property_name($input), $expected;
    }

    is_deeply $header->header, { -location => $url };
    is $header->as_string, CGI::redirect($url);

    is_deeply [ $header->flatten ], [
        'Status',  '302 Found',
        'Location', $url,
    ];
};

subtest 'the Content-Type header' => sub {
    my $header = CGI::Header::Redirect->new;

    %{ $header->header } = ();
    is $header->get('Content-Type'), undef;
    ok !$header->exists('Content-Type');
    is $header->delete('Content-Type'), undef;
    is_deeply $header->header, {};

    %{ $header->header } = ( -type => undef );
    is $header->as_hashref->{'Content-Type'}, 'text/html; charset=ISO-8859-1';
    ok $header->exists('Content-Type');
    #is $header->delete('Content-Type'), 'text/html; charset=ISO-8859-1';
    #is_deeply $header->header, {};

    %{ $header->header } = ( -type => q{} );
    is $header->get('Content-Type'), undef;
    ok !$header->exists('Content-Type');
    is $header->delete('Content-Type'), undef;
    is_deeply $header->header, {};

    %{ $header->header } = ( -type => 'text/plain' );
    is $header->as_hashref->{'Content-Type'}, 'text/plain; charset=ISO-8859-1';
    ok $header->exists('Content-Type');
    #is $header->delete('Content-Type'), 'text/plain; charset=ISO-8859-1';
    #is_deeply $header->header, {};
};

subtest 'the Location header' => sub {
    my $header = CGI::Header::Redirect->new;
    my $expected = qr{^Can't delete the Location header};
    my $url = 'http://somewhere.else/in/movie/land';

    %{ $header->header } = ();
    is $header->get('Location'), $header->query->self_url;
    ok $header->exists('Location');
    throws_ok { $header->delete('Location') } $expected;

    %{ $header->header } = ( -location => undef );
    is $header->get('Location'), $header->query->self_url;
    ok $header->exists('Location');
    throws_ok { $header->delete('Location') } $expected;

    %{ $header->header } = ( -location => q{} );
    is $header->get('Location'), $header->query->self_url;
    ok $header->exists('Location');
    throws_ok { $header->delete('Location') } $expected;

    %{ $header->header } = ( -location => $url );
    is $header->get('Location'), $url;
    ok $header->exists('Location');
    throws_ok { $header->delete('Location') } $expected;
};

subtest 'the Status header' => sub {
    my $header = CGI::Header::Redirect->new;

    %{ $header->header } = ();
    is $header->get('Status'), '302 Found';
    ok $header->exists('Status');
    is $header->delete('Status'), '302 Found';
    is_deeply $header->header, { -status => q{} };

    %{ $header->header } = ( -status => undef );
    is $header->get('Status'), '302 Found';
    ok $header->exists('Status');
    is $header->delete('Status'), '302 Found';
    is_deeply $header->header, { -status => q{} };
    
    %{ $header->header } = ( -status => q{} );
    is $header->get('Status'), undef;
    ok !$header->exists('Status');
    is $header->delete('Status'), undef;
    is_deeply $header->header, { -status => q{} };
    
    %{ $header->header } = ( -status => '301 Moved Permanently' );
    is $header->get('Status'), '301 Moved Permanently';
    ok $header->exists('Status');
    is $header->delete('Status'), '301 Moved Permanently';
    is_deeply $header->header, { -status => q{} };
};
