use strict;
use CGI::Header::Redirect;
use Test::Exception;
use Test::More tests => 1;

subtest 'default' => sub {
    my $header = CGI::Header::Redirect->new;

    is_deeply [ $header->flatten ], [
        'Status',  '302 Found',
        'Location', $header->query->self_url,
    ];

    is $header->get('Status'), '302 Found';
    ok $header->exists('Status');
    is $header->delete('Status'), '302 Found';
    is_deeply $header->header, { -status => q{} };

    my $expected = qr{^Can't delete the Location header};

    is $header->get('Location'), $header->query->self_url;
    ok $header->exists('Location');
    throws_ok { $header->delete('Location') } $expected;

    is $header->get('Content-Type'), undef;
    ok !$header->exists('Content-Type');

};


