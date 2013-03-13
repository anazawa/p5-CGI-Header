use strict;
use warnings;
use CGI::Header;
use HTTP::Headers;
use Benchmark 'cmpthese';

my $cgi_header = CGI::Header->new;

my $http_headers = HTTP::Headers->new(
    'Content-Type' => 'text/html; charset=ISO-8859-1',
);

warn $cgi_header->get('Content-Type');
warn $http_headers->get('Content-Type');

cmpthese(-1, {
    'CGI::Header' => sub {
        my $value = $cgi_header->get('Content-Type');
    },
    'HTTP::Headers' => sub {
        my $value = $http_headers->header('Content-Type');
    },
});
