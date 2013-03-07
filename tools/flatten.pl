use strict;
use warnings;
use Benchmark 'cmpthese';
use CGI::Header::Simple;

my $header = CGI::Header::Simple->new;
$header->query->no_cache( 1 );

warn $header->flatten;

cmpthese(-1, {
    localize => sub {
        my @headers = $header->flatten;
    },
    clone => sub {
        my @headers = $header->_flatten;
    },
});
