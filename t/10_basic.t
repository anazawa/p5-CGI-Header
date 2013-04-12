use strict;
use warnings;
use CGI::Header;
use Test::More tests => 34;

my $header = CGI::Header->new(
    header => {
        '-Content_Type'  => 'text/plain',
        '-Set_Cookie'    => 'ID=123456; path=/',
        '-Window_Target' => 'ResultsWindow',
    },
);

isa_ok $header, 'CGI::Header';
isa_ok $header->header, 'HASH';
isa_ok $header->query, 'CGI';

is $header->rehash, $header;
is_deeply $header->header, {
    'type'   => 'text/plain',
    'cookie' => 'ID=123456; path=/',
    'target' => 'ResultsWindow',
};

is $header->set('Foo' => 'bar'), 'bar';
is $header->get('Foo'), 'bar';
ok $header->exists('Foo');
is $header->delete('Foo'), 'bar';

is $header->type('text/plain'), $header;
is $header->type, 'text/plain';

is $header->p3p('CAO DSP LAW CURa'), $header;
is $header->p3p, 'CAO DSP LAW CURa';

is $header->status('304 Not Modified'), $header;
is $header->status, '304 Not Modified';

is $header->cookie([qw/cookie1 cookie2/]), $header;
is_deeply $header->cookie, [qw/cookie1 cookie2/];

is $header->push_cookie( riddle_name => "The Sphynx's Question" ), $header;
is $header->cookie->[-1]->name, 'riddle_name';
is $header->cookie->[-1]->value, "The Sphynx's Question";

is $header->target('ResultsWindow'), $header;
is $header->target, 'ResultsWindow';

is $header->expires('+3d'), $header;
is $header->expires, '+3d';

is $header->charset('utf-8'), $header;
is $header->charset, 'utf-8';

is $header->attachment('genome.jpg'), $header;
is $header->attachment, 'genome.jpg';

is $header->redirect('http://somewhere.else/in/movie/land'), $header;
is $header->location, 'http://somewhere.else/in/movie/land';
is $header->status, '302 Found';

is $header->clear, $header;
is_deeply $header->header, {};

like $header->as_string, qr{^Content-Type: text/html; charset=ISO-8859-1};
