use strict;
use warnings;
use CGI;
use CGI::Header;
use Test::Exception;
use Test::More tests => 4;

subtest 'default' => sub {
    tie my %header, 'CGI::Header';
    is $header{Pragma}, undef;
    ok !exists $header{Pragma};
    is delete $header{Pragma}, undef;
    is_deeply tied(%header)->header, {};
};

subtest 'an empty string' => sub {
    tie my %header, 'CGI::Header', ( -pragma => q{} );
    is $header{Pragma}, q{};
    ok exists $header{Pragma};
    is delete $header{Pragma}, q{};
    is_deeply tied(%header)->header, {};
};

subtest 'a plain string' => sub {
    my $header = tie my %header, 'CGI::Header';
    is $header->set( Pragma => 'no-cache' ), 'no-cache';
    is_deeply $header->header, { -pragma => 'no-cache' };
    is $header{Pragma}, 'no-cache';
    ok exists $header{Pragma};
    is delete $header{Pragma}, 'no-cache';
    is_deeply $header->header, {};
};

subtest 'cache()' => sub {
    my $header = tie my %header, 'CGI::Header', {}, CGI->new;;
    $header->query->cache(1);
    is $header->as_hashref->{Pragma}, 'no-cache';
    ok exists $header{Pragma};
    my $expected = qr{^Modification of a read-only value attempted};
    throws_ok { delete $header{Pragma} } $expected;
    throws_ok { $header{Pragma} = 'no-cache' } $expected;
};
