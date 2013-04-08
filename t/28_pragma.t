use strict;
use warnings;
use CGI;
use CGI::Header;
use Test::Exception;
use Test::More tests => 4;

subtest 'default' => sub {
    my $header = CGI::Header->new;
    is $header->as_hashref->{Pragma}, undef;
    ok !exists $header->as_hashref->{Pragma};
    #is delete $header{Pragma}, undef;
    #is_deeply tied(%header)->header, {};
};

subtest 'an empty string' => sub {
    my $header = CGI::Header->new( header => { pragma => q{} } );
    is $header->as_hashref->{Pragma}, q{};
    ok exists $header->as_hashref->{Pragma};
    #is delete $header{Pragma}, q{};
    #is_deeply tied(%header)->header, {};
};

subtest 'a plain string' => sub {
    my $header = CGI::Header->new;
    is $header->set( Pragma => 'no-cache' ), 'no-cache';
    is_deeply $header->header, { pragma => 'no-cache' };
    is $header->get('Pragma'), 'no-cache';
    ok $header->exists('Pragma');
    is $header->delete('Pragma'), 'no-cache';
    is_deeply $header->header, {};
};

subtest 'cache()' => sub {
    my $header = CGI::Header->new( query => CGI->new );
    $header->query->cache(1);
    is $header->as_hashref->{Pragma}, 'no-cache';
    ok exists $header->as_hashref->{Pragma};
    #my $expected = qr{^Modification of a read-only value attempted};
    #throws_ok { delete $header{Pragma} } $expected;
    #throws_ok { $header{Pragma} = 'no-cache' } $expected;
};
