use strict;
use warnings;
use CGI::Cookie;
use CGI::Header;
use Test::More tests => 5;

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

subtest 'an empty string' => sub {
    my $header = tie my %header, 'CGI::Header', ( -cookie => q{} );
    is $header{Set_Cookie}, undef;
    ok !exists $header{Set_Cookie};
    is delete $header{Set_Cookie}, undef;
    is_deeply $header->header, {};
};

subtest 'a CGI::Cookie object' => sub {
    my $header = tie my %header, 'CGI::Header';
    $header{Set_Cookie} = $cookie1;
    is $header->header->{-cookie}, $cookie1;
    is $header->as_hashref->{'Set-Cookie'}, $cookie1; 
    ok exists $header->as_hashref->{'Set-Cookie'};
    #is_deeply [ each %header ], [ 'Set-Cookie', $cookie1 ];
    #is delete $header{Set_Cookie}, $cookie1;
    #is_deeply $header->header, {};
};

subtest 'CGI::Cookie objects' => sub {
    my @cookies = ( $cookie1, $cookie2 );
    my $header  = tie my %header, 'CGI::Header';

    $header{Set_Cookie} = \@cookies;
    is_deeply $header->header, { -cookie => \@cookies };
    #is $header->as_hashref->{'Set-Cookie'}, \@cookies;
    ok exists $header->as_hashref->{'Set-Cookie'};

    #is_deeply [ each %header ], [ 'Set-Cookie', \@cookies ];

    #my @headers;
    #$header->each(sub { push @headers, @_ });
    #is_deeply [ @headers[0..3] ], [
    #    'Set-Cookie', $cookie1,
    #    'Set-Cookie', $cookie2,
    #];

    #is_deeply delete $header{Set_Cookie}, \@cookies;
    #is_deeply $header->header, {};
};

subtest '-cookie and -date' => sub {
    my $header = tie my %header, 'CGI::Header';
    $header{Date} = 'Sat, 07 Jul 2012 05:05:09 GMT';
    is $header->set( Set_Cookie => $cookie1 ), $cookie1;
    is_deeply $header->header, { -cookie => $cookie1 };
};
