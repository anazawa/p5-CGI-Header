use strict;
use warnings;
use CGI::PSGI;
use CGI::Header::PSGI;
use Test::More tests => 2;

my $header = CGI::Header::PSGI->new( query => CGI::PSGI->new({}) );

is $header->status_code, 200;
is_deeply $header->as_arrayref,
    [ 'Content-Type', 'text/html; charset=ISO-8859-1' ];

