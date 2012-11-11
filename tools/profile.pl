use strict;
use warnings;
use CGI::Cookie;
use CGI::Header;

my $cookie1 = CGI::Cookie->new(
    -name  => 'foo',
    -value => 'bar',
);

my $cookie2 = CGI::Cookie->new(
    -name  => 'bar',
    -value => 'baz',
);

my $cookie3 = CGI::Cookie->new(
    -name  => 'baz',
    -value => 'qux',
);

my $header = CGI::Header->new(
    -nph        => 1,
    -expires    => '+3M',
    -attachment => 'genome.jpg',
    -target     => 'ResultsWindow',
    -cookie     => [ $cookie1, $cookie2, $cookie3 ],
    -type       => 'text/plain',
    -charset    => 'utf-8',
    -p3p        => [qw/CAO DSP LAW CURa/],
);

for (0..100) {
    my @headers = $header->flatten;
}
