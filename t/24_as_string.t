use strict;
use warnings;
use CGI;
use Test::More tests => 1;
use CGI::Header;

my $CRLF   = $CGI::CRLF;
my $header = CGI::Header->new( -nph => 1 );

$header->set(
    'Content-Type'  => 'text/plain; charset=utf-8',
    #'Window-Target' => 'ResultsWindow',
);

$header->attachment( 'genome.jpg' );
$header->status( 304 );
$header->expires( '+3M' );
$header->p3p_tags( qw/CAO DSP LAW CURa/ );

$header->set_cookie( foo => 'bar' );
$header->set_cookie( bar => 'baz' );

$header->set( Ingredients => join "$CRLF ", qw(ham eggs bacon) );

my $got      = $header->as_string( $CRLF ) . $CRLF;
my $expected = CGI::header( $header->header );

is $got, $expected;

#warn $header->dump;
