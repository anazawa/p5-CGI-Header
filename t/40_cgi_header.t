use strict;
use warnings;
use CGI;
use Test::More tests => 1;
use CGI::Header;

package CGI::Header;
use overload q{""} => 'as_string', fallback => 1;
use Carp qw/croak/;

my $CRLF = $CGI::CRLF;

sub as_string {
    my $self = shift;

    my @lines;

    if ( $self->nph ) {
        my $protocol = $ENV{SERVER_PROTOCOL} || 'HTTP/1.0';
        my $software = $ENV{SERVER_SOFTWARE} || 'cmdline';
        my $status   = $self->{Status}       || '200 OK';
        push @lines, "$protocol $status";
        push @lines, "Server: $software";
    }

    $self->each(sub {
        my ( $field, $value ) = @_;
        my @values = ref $value eq 'ARRAY' ? @{ $value } : $value;
        push @lines, "$field: $_" for @values;
    });

    # CR escaping for values, per RFC 822
    for my $line ( @lines ) {
        $line =~ s/$CRLF(\s)/$1/g;
        next unless $line =~ m/$CRLF|\015|\012/;
        $line = substr $line, 0, 72 if length $line > 72;
        croak "Invalid header value contains a new line ",
              "not followed by whitespace: $line";
    }

    join $CRLF, @lines, $CRLF;
}

package main;

my $header = CGI::Header->new( -nph => 1 );

$header->set(
    'Content-Type'  => 'text/plain; charset=utf-8',
    'Window-Target' => 'ResultsWindow',
);

$header->attachment( 'genome.jpg' );
$header->status( 304 );
$header->expires( '+3M' );
$header->p3p_tags( qw/CAO DSP LAW CURa/ );

$header->set_cookie( foo => 'bar' );
$header->set_cookie( bar => 'baz' );

$header->{Ingredients} = join "$CRLF ", qw(ham eggs bacon);

is $header, CGI::header( $header->header );
