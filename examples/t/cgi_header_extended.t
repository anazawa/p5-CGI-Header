use strict;
use warnings;
use Test::More tests => 5;

BEGIN {
    use_ok 'CGI::Header::Extended';
}

subtest '#merge' => sub {
    my $header = CGI::Header::Extended->new(
        header => {
            foo => 'bar',
        },
    );
    is $header->merge( bar => 'baz' ), $header;
    is_deeply $header->header, { foo => 'bar', bar => 'baz' };
};

subtest '#replace' => sub {
    my $header = CGI::Header::Extended->new(
        header => {
            foo => 'bar',
            bar => 'baz',
        },
    );
    is $header->replace( baz => 'qux' ), $header;
    is_deeply $header->header, { baz => 'qux' };
};

subtest '#get' => sub {
    my $header = CGI::Header::Extended->new(
        header => {
            foo => 'bar',
            bar => 'baz',
        },
    );
    is_deeply [ $header->get(qw/foo bar/) ], [qw/bar baz/];
};

subtest '#delete' => sub {
    my $header = CGI::Header::Extended->new(
        header => {
            foo => 'bar',
            bar => 'baz',
            baz => 'qux',
        },
    );
    is_deeply [ $header->delete(qw/foo bar/) ], [qw/bar baz/];
    is_deeply $header->header, { baz => 'qux' };
};
