use strict;
use warnings;
use Benchmark qw/cmpthese/;
use CGI;
use CGI::Cookie;
use CGI::Header;
use HTTP::Headers;

my $CRLF = $CGI::CRLF;

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

my $now = time;

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
        my $output = $header->as_string( $CRLF );
    },
});

cmpthese(-1, {
    'CGI::Header' => sub {
        my $header = CGI::Header->new(
            -attachment => 'genome.jpg',
            -p3p        => [qw/CAO DSP LAW CURa/],
            -type       => 'text/plain',
            -charset    => 'utf-8',
            -target     => 'ResultsWindow',
            -cookie     => [ $cookie1, $cookie2, $cookie3 ],
        );

        $header->expires( $now + 60 );

        $header->set( Foo => 'bar' );
        my $delete = $header->delete( 'Foo' );

        my $get = $header->get( 'P3P' );

        my @field_names = $header->field_names;

        my $exists = $header->exists( 'Content-Type' );

        my $as_string = $header->as_string( $CRLF ); 

        my @each;
        $header->each(sub {
            my ( $field, $value ) = @_;
            push @each, $field, $value;
        });

        my $clone = $header->clone;

        $header->clear;
    },
    'HTTP::Headers' => sub {
        my $header = HTTP::Headers->new(
            'Content-Type'        => 'text/plain; charset=utf-8',
            'Content-Disposition' => 'attachment; filename="genome.jpg"',
            'Window-Target' => 'ResultsWindow',
            'Set-Cookie'    => [ $cookie1, $cookie2, $cookie3 ],
            'P3P' => 'policyref="/w3c/p3p.xml", CP="CAP DSP LAW CURa"',
        );

        $header->expires( $now + 60 );
        $header->date( $now );

        $header->header( Foo => 'bar' );
        my $remove_header = $header->remove_header( 'Foo' );

        my $get = $header->header( 'P3P' );

        my $exists = $header->header( 'Content-Type' );

        my @header_field_names = $header->header_field_names;

        my $as_string = $header->as_string( $CRLF );

        my @scan;
        $header->scan(sub {
            my ( $field, $value ) = @_;
            push @scan, $field, $value;
        });

        my $clone = $header->clone;

        $header->clear;
    },
});
