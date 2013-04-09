use strict;
use warnings;
use Test::More tests => 2;
use CGI::Header::PSGI;
use CGI::PSGI;

my $header = CGI::Header::PSGI->new(
    query => CGI::PSGI->new({}),
);

my ( $status, $headers ) = $header->finalize;

is $status, 200;
is_deeply $headers, ['Content-Type', 'text/html; charset=ISO-8859-1'];

