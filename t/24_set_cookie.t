use strict;
use warnings;
use CGI::Cookie;
use CGI::Header;
use Test::More tests => 13;

my $cookie1 = CGI::Cookie->new(
    -name  => 'foo',
    -value => 'bar',
);

my $cookie2 = CGI::Cookie->new(
    -name  => 'bar',
    -value => 'baz',
);

my $header = tie my %header, 'CGI::Header';

%{ $header->header } = ();
is $header{Set_Cookie}, undef;
ok !exists $header{Set_Cookie};
is delete $header{Set_Cookie}, undef;
is_deeply $header->header, {};

%{ $header->header } = ( -cookie => $cookie1 );
is $header{Set_Cookie}, 'foo=bar; path=/';
ok exists $header{Set_Cookie};
is delete $header{Set_Cookie}, 'foo=bar; path=/';
is_deeply $header->header, {};

%{ $header->header } = ( -cookie => [$cookie1, $cookie2] );
is_deeply $header{Set_Cookie}, [ $cookie1, $cookie2 ];
ok exists $header{Set_Cookie};
is_deeply delete $header{Set_Cookie}, [ $cookie1, $cookie2 ];
is_deeply $header->header, {};

%{ $header->header } = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
$header{Set_Cookie} = $cookie1;
is_deeply $header->header, { -cookie => $cookie1 };
