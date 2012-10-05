use strict;
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

my %adaptee;
my $adapter = tie my %adapter, 'CGI::Header', \%adaptee;

%adaptee = ();
is $adapter{Set_Cookie}, undef;
ok !exists $adapter{Set_Cookie};
is delete $adapter{Set_Cookie}, undef;
is_deeply \%adaptee, {};

%adaptee = ( -cookie => $cookie1 );
is $adapter{Set_Cookie}, 'foo=bar; path=/';
ok exists $adapter{Set_Cookie};
is delete $adapter{Set_Cookie}, 'foo=bar; path=/';
is_deeply \%adaptee, {};

%adaptee = ( -cookie => [$cookie1, $cookie2] );
is_deeply $adapter{Set_Cookie}, [ $cookie1, $cookie2 ];
ok exists $adapter{Set_Cookie};
is_deeply delete $adapter{Set_Cookie}, [ $cookie1, $cookie2 ];
is_deeply \%adaptee, {};

%adaptee = ( -date => 'Sat, 07 Jul 2012 05:05:09 GMT' );
$adapter{Set_Cookie} = $cookie1;
is_deeply \%adaptee, { -cookie => $cookie1 };
