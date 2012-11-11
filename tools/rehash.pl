use strict;
use warnings;
use CGI::Header;
use Benchmark qw/cmpthese/;

my @args = (
    '-content_type' => 'text/plain',
    'Set-Cookie'    => 'ID=123456; path=/',
    '-expires'      => '+3d',
    'foo'           => 'bar',
    'foo-bar'       => 'baz',
    'window_target' => 'ResultsWindow',
);

cmpthese(-1, {
    rehash  => sub {
        my $header = CGI::Header->new( @args );
        $header->rehash;
    },
    rehash2 => sub {
        my $header = CGI::Header->new( @args );
        $header->rehash2;
    },
});

