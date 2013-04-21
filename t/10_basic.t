use strict;
use warnings;
use CGI::Header;
use Test::Exception;
use Test::More tests => 30;

subtest 'CGI::Header#new' => sub {
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

    is_deeply $header->header, {
        'type'    => 'text/plain',
        'cookies' => 'ID=123456; path=/',
        'target'  => 'ResultsWindow',
    };
};

subtest 'CGI::Header#rehash' => sub {
    my $header = {};
    my $h = CGI::Header->new( header => $header );
    $h->type('text/html');
    $h->set( 'Content-Type' => 'text/plain' );
    throws_ok { $h->rehash } qr{^Property 'type' already exists};
};

subtest 'CGI::Header#replace' => sub {
    my $header = { type => 'text/html' };
    my $h = CGI::Header->new( header => $header );
    is $h->replace( -Content_Type => 'text/plain', -Charset => 'utf-8' ), $h;
    ok $h->header == $header;
    is_deeply $h->header, { type => 'text/plain', charset => 'utf-8' };
};

subtest 'header fields' => sub {
    my $header = CGI::Header->new;
    is $header->set( 'Foo' => 'bar' ), 'bar';
    is $header->get('Foo'), 'bar';
    ok $header->exists('Foo');
    is $header->delete('Foo'), 'bar';
};

subtest 'header props.' => sub {
    my $header = CGI::Header->new;

    can_ok $header, qw(
        attachment
        charset
        cookies
        expires
        location
        nph
        p3p
        status
        target
        type
    );

    is $header->attachment('genome.jpg'), $header;
    is $header->attachment, 'genome.jpg';

    is $header->charset('utf-8'), $header;
    is $header->charset, 'utf-8';

    is $header->cookies('ID=123456; path=/'), $header;
    is $header->cookies, 'ID=123456; path=/';

    is $header->expires('+3d'), $header;
    is $header->expires, '+3d';

    is $header->location('http://somewhere.else/in/movie/land'), $header;
    is $header->location, 'http://somewhere.else/in/movie/land';

    is $header->nph(1), $header;
    ok $header->nph;

    is $header->p3p('CAO DSP LAW CURa'), $header;
    is $header->p3p, 'CAO DSP LAW CURa';

    is $header->status('304 Not Modified'), $header;
    is $header->status, '304 Not Modified';

    is $header->target('ResultsWindow'), $header;
    is $header->target, 'ResultsWindow';

    is $header->type('text/plain'), $header;
    is $header->type, 'text/plain';

    is_deeply $header->header, {
        attachment => 'genome.jpg',
        charset    => 'utf-8',
        cookies    => 'ID=123456; path=/',
        expires    => '+3d',
        location   => 'http://somewhere.else/in/movie/land',
        nph        => '1',
        p3p        => 'CAO DSP LAW CURa',
        status     => '304 Not Modified',
        target     => 'ResultsWindow',
        type       => 'text/plain',
    };
};

subtest 'CGI::Header#redirect' => sub {
    my $header = CGI::Header->new;
    is $header->redirect('http://somewhere.else/in/movie/land'), $header;
    is $header->location, 'http://somewhere.else/in/movie/land';
    is $header->status, '302 Found';
};

subtest 'CGI::Header#clear' => sub {
    my $header = { foo => 'bar' };
    my $h = CGI::Header->new( header => $header );
    is $h->clear, $h;
    ok $h->header == $header;
    is_deeply $h->header, {};
};

subtest 'CGI::Header#as_string' => sub {
    my $header = CGI::Header->new;
    like $header->as_string, qr{^Content-Type: text/html; charset=ISO-8859-1};
};
