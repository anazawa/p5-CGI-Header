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
use HTTP::Response;
use Storable qw/dclone/;

my $CRLF = $CGI::CRLF;

my $cookie1 = CGI::Cookie->new( -name => 'foo', -value => 'bar' );
my $cookie2 = CGI::Cookie->new( -name => 'bar', -value => 'baz' );
my $cookie3 = CGI::Cookie->new( -name => 'baz', -value => 'qux' );

my $now = time;

my @args = (
    -NPH           => 1,
    expires        => '+3M',
    -attachment    => 'genome.jpg',
    -window_target => 'ResultsWindow',
    Cookies        => [ $cookie1, $cookie2, $cookie3 ],
    -type          => 'text/plain',
    -Charset       => 'utf-8',
    -p3p           => [qw/CAO DSP LAW CURa/],
);

warn CGI::header(@args);

cmpthese(-1, {
    'CGI::header()' => sub {
        my $header = CGI::header( @args );
    },
    'CGI::Header' => sub {
        my $header = CGI::Header->new( @args )->as_string( $CRLF );
        $header.= $CRLF;
    },
});

cmpthese(-1, {
    'CGI::Header' => sub {
        my $header = CGI::Header->new(
            -Attachment   => 'genome.jpg',
            P3P           => [qw/CAO DSP LAW CURa/],
            -content_type => 'text/plain',
            -charset      => 'utf-8',
            -target       => 'ResultsWindow',
            'Set-Cookie'  => [ $cookie1, $cookie2, $cookie3 ],
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

my $cgi_psgi = CGI::PSGI->new;

cmpthese(-1, {
    'HTTP::Parser::XS' => sub {
        my $header = CGI::header( @args );
        my ( $ret, $minor_version, $status, $msg, $headers )
            = parse_http_response( $header, HEADERS_AS_ARRAYREF );
    },
    'HTTP::Response' => sub {
        my $response = HTTP::Response->parse( CGI::header(@args) );
        my $status_code = $response->header('Status') || '200 OK';
        $status_code =~ s/\D*$//;
        $response->remove_header('Status');
        my @headers; $response->scan(sub { push @headers, @_ });
    },
    'CGI::PSGI' => sub {
        my ( $status_code, $headers_aref ) = $cgi_psgi->psgi_header( @args );
    },
    'CGI::Header' => sub {
        my $header = CGI::Header->new( @args );
        my $status_code = $header->delete('Status') || '200 OK';
        $status_code =~ s/\D*$//;
        my @headers = $header->flatten;
    },
});

cmpthese(-1, {
    'CGI::Util::expires'   => sub { my $date = CGI::Util::expires()   },
    'HTTP::Date::time2str' => sub { my $date = HTTP::Date::time2str() },
});
