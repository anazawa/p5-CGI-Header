use strict;
use Data::Dumper;
use CGI::Header::Redirect;
use Test::More tests => 1;

my $header = CGI::Header::Redirect->new;

is $header->get('Status'), '302 Found';
is $header->get('Location'), $header->query->self_url;
ok !$header->exists('Content-Type');

is_deeply [ $header->flatten ], [
    'Status', '302 Found',
    'Location', $header->query->self_url,
];


