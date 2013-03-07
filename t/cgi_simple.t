use strict;
use Test::MockTime qw/set_fixed_time/;
use Test::More tests => 3;
use CGI::Header::Simple;

set_fixed_time( 1341637509 );
my $now = 'Sat, 07 Jul 2012 05:05:09 GMT';

my $header = CGI::Header::Simple->new;

ok $header->isa('CGI::Header');
ok $header->query->isa('CGI::Simple');

$header->query->no_cache(1);
is_deeply [ $header->flatten ], [
    'Expires',      $now,
    'Date',         $now,
    'Pragma',       'no-cache',
    'Content-Type', 'text/html; charset=ISO-8859-1',
];
