use strict;
use warnings;
use Data::Dumper;
use CGI::Header::Standalone;
use Test::More tests => 2;

my $header = CGI::Header::Standalone->new;

isa_ok $header, 'CGI::Header';
like $header->as_string, qr{Content-Type: text/html; charset=ISO-8859-1};
