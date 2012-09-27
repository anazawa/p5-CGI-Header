use strict;
use warnings;
use Benchmark qw/cmpthese/;
use CGI;
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

my @args = (
    -nph        => 1,
    -expires    => '+3M',
    -attachment => 'genome.jpg',
    -target     => 'ResultsWindow',
    -cookie     => [ $cookie1, $cookie2, $cookie3 ],
    -type       => 'text/plain',
    -charset    => 'utf-8',
    -p3p        => [qw/CAO DSP LAW CURa/],
);

cmpthese(-1, {
    'CGI::header()' => sub {
        my $output = CGI::header( @args );
    },
    'CGI::Header' => sub {
        my $header = CGI::Header->new( @args );
        my $output = $header->as_string( $CGI::CRLF );
    },
});
