use strict;
use warnings;
use CGI::Cookie;
use CGI::Header;
use Test::More tests => 4;

my $cookie1 = CGI::Cookie->new(
    -name  => 'foo',
    -value => 'bar',
);

my $cookie2 = CGI::Cookie->new(
    -name  => 'bar',
    -value => 'baz',
);

subtest 'default' => sub {
    my $header = tie my %header, 'CGI::Header';
    is $header{Set_Cookie}, undef;
    ok !exists $header{Set_Cookie};
    is delete $header{Set_Cookie}, undef;
    is_deeply $header->header, {};
};

subtest 'a CGI::Cookie object' => sub {
    my $header = tie my %header, 'CGI::Header';
    $header{Set_Cookie} = $cookie1;
    is $header->header->{-cookie}, $cookie1;
    is $header{Set_Cookie}, $cookie1; 
    ok exists $header{Set_Cookie};
    is delete $header{Set_Cookie}, 'foo=bar; path=/';
    is_deeply $header->header, {};
};

subtest 'CGI::Cookie objects' => sub {
    my $header = tie my %header, 'CGI::Header';
    $header{Set_Cookie} = [ $cookie1, $cookie2 ];
    is_deeply $header->header, { -cookie => [ $cookie1, $cookie2 ] };
    is $header{Set_Cookie}, $header->header->{-cookie};
    ok exists $header{Set_Cookie};
    is_deeply delete $header{Set_Cookie}, [ $cookie1, $cookie2 ];
    is_deeply $header->header, {};
};

subtest '-cookie and -date' => sub {
    my $header = tie my %header, 'CGI::Header';
    $header{Date} = 'Sat, 07 Jul 2012 05:05:09 GMT';
    $header{Set_Cookie} = $cookie1;
    is_deeply $header->header, { -cookie => $cookie1 };
};
