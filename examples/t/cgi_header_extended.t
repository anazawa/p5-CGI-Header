use strict;
use warnings;
use Test::More tests => 6;

BEGIN {
    use_ok 'CGI::Header::Extended';
}

my $header = CGI::Header::Extended->new(
    header => {
        foo => 'bar',
    },
);

can_ok $header, qw( merge replace );

is $header->merge( bar => 'baz' ), $header;
is_deeply $header->header, { foo => 'bar', bar => 'baz' };

is $header->replace( baz => 'qux' ), $header;
is_deeply $header->header, { baz => 'qux' };
