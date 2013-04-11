use strict;
use warnings;
use CGI::Header;
use Test::Exception;
use Test::More tests => 25;

my $header = CGI::Header->new;

isa_ok $header, 'CGI::Header';
isa_ok $header->header, 'HASH';

is $header->set('Foo' => 'bar'), 'bar';
is $header->get('Foo'), 'bar';
ok $header->exists('Foo');
is $header->delete('Foo'), 'bar';

is $header->type('text/plain'), $header;
is $header->type, 'text/plain';

#is $header->p3p(qw/CAO DSP LAW CURa/), $header;
#is_deeply [ $header->p3p ], [qw/CAO DSP LAW CURa/];

is $header->p3p('CAO DSP LAW CURa'), $header;
is $header->p3p, 'CAO DSP LAW CURa';

is $header->status('304 Not Modified'), $header;
is $header->status, '304 Not Modified';

#is $header->cookie([qw/cookie1 cookie2/]), $header;
#is_deeply $header->cookie, [qw/cookie1 cookie2/];

is $header->push_cookie( riddle_name => "The Sphynx's Question" ), $header;
is $header->cookie->name, 'riddle_name';

throws_ok { $header->push_cookie }
    qr{^Failed to create CGI::Cookie object};

is $header->target('ResultsWindow'), $header;
is $header->target, 'ResultsWindow';

is $header->expires('+3d'), $header;
is $header->expires, '+3d';

is $header->charset('utf-8'), $header;
is $header->charset, 'utf-8';

is $header->attachment('genome.jpg'), $header;
is $header->attachment, 'genome.jpg';

is $header->clear, $header;
is_deeply $header->header, {};
