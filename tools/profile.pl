use strict;
use warnings;
use CGI::Simple::Cookie;

package CGI::Simple::PSGI;
use parent 'CGI::Simple';
use CGI::Header::PSGI qw( psgi_header psgi_redirect );

package main;

my $cgi = CGI::Simple::PSGI->new;

my $cookie1 = CGI::Simple::Cookie->new( -name => 'foo', -value => 'bar' );
my $cookie2 = CGI::Simple::Cookie->new( -name => 'bar', -value => 'baz' );
my $cookie3 = CGI::Simple::Cookie->new( -name => 'baz', -value => 'qux' );

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

for ( 0..100 ) {
    my ( $status, $headers ) = $cgi->psgi_header( @args );
}
