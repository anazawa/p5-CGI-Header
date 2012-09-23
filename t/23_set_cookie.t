use strict;
use CGI::Header;
use CGI::Cookie;
use Test::More tests => 2;

my %header;
my $header = CGI::Header->new( \%header );

subtest 'get_cookie()' => sub {
    my $cookie1 = CGI::Cookie->new(
        -name  => 'foo',
        -value => 'bar',
    );

    my $cookie2 = CGI::Cookie->new(
        -name  => 'bar',
        -value => 'baz',
    );

    %header = ( -cookie => $cookie1 );
    is $header->get_cookie('foo'), $cookie1;
    is $header->get_cookie('bar'), undef;

    %header = ( -cookie => [$cookie1, $cookie2] );
    is $header->get_cookie('foo'), $cookie1;
    is $header->get_cookie('bar'), $cookie2;
    is $header->get_cookie('baz'), undef;
};

subtest 'set_cookie()' => sub {
    %header = ();
    $header->set_cookie( foo => 'bar' );
    my $got = $header{-cookie}[0];
    isa_ok $got, 'CGI::Cookie';
    is $got->value, 'bar';

    %header = ();
    $header->set_cookie( foo => { value => 'bar' } );
    #$got = $header{-cookie};
    $got = $header{-cookie}[0];
    isa_ok $got, 'CGI::Cookie';
    is $got->value, 'bar';

    my $cookie = CGI::Cookie->new(
        -name  => 'foo',
        -value => 'bar',
    );

    %header = ( -cookie => $cookie );
    $header->set_cookie( foo => 'baz' );
    $got = $header{-cookie}[0];
    isa_ok $got, 'CGI::Cookie';
    is $got->value, 'baz';

    $cookie = CGI::Cookie->new(
        -name  => 'foo',
        -value => 'bar',
    );

    %header = ( -cookie => $cookie );
    $header->set_cookie( foo => { value => 'baz' } );
    $got = $header{-cookie}[0];
    isa_ok $got, 'CGI::Cookie';
    is $got->value, 'baz';
};

