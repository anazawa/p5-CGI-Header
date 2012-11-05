use strict;
use warnings;
use Benchmark qw/cmpthese/;
use CGI;
use CGI::Cookie;
use CGI::Header;
use CGI::PSGI;
use CGI::Util;
use HTTP::Date;
use HTTP::Headers;
use HTTP::Parser::XS qw/parse_http_response HEADERS_AS_ARRAYREF/;
use Storable qw/dclone/;

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

#                 Rate   CGI::Header CGI::header()
# CGI::Header   2509/s            --          -22% 
# CGI::header() 3214/s           28%            -- 

cmpthese(-1, {
    'CGI::header()' => sub {
        my $header = CGI::header( @args );
    },
    'CGI::Header' => sub {
        my $header = CGI::Header->new( @args )->as_string( $CRLF );
        $header.= $CRLF;
    },
});

#                 Rate   CGI::Header HTTP::Headers
# CGI::Header   1147/s            --          -34%
# HTTP::Headers 1747/s           52%            --

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

        my $clone = dclone( $header );

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

#                    Rate      CGI::Header HTTP::Parser::XS        CGI::PSGI
# CGI::Header      2965/s               --              -2%             -10%
# HTTP::Parser::XS 3039/s               2%               --              -8%
# CGI::PSGI        3286/s              11%               8%               --

my $cgi_psgi = CGI::PSGI->new;

cmpthese(-1, {
    'HTTP::Parser::XS' => sub {
        my $header = CGI::header( @args );
        my ( $ret, $minor_version, $status, $msg, $headers )
            = parse_http_response( $header, HEADERS_AS_ARRAYREF );
    },
    'CGI::PSGI' => sub {
        my ( $status_code, $headers_aref ) = $cgi_psgi->psgi_header( @args );
    },
    'CGI::Header' => sub {
        my $header = CGI::Header->new( @args );
        my $status = $header->delete('Status') || '200 OK';
        my ( $code, $message ) = split ' ', $status, 2;
        my @headers = $header->flatten;
    },
});

#                          Rate   CGI::Util::expires HTTP::Date::time2str
# CGI::Util::expires    35951/s                   --                 -70%
# HTTP::Date::time2str 121020/s                 237%                   --

cmpthese(-1, {
    'CGI::Util::expires'   => sub { my $date = CGI::Util::expires()   },
    'HTTP::Date::time2str' => sub { my $date = HTTP::Date::time2str() },
});
