use strict;
use warnings;
use CGI::Header;
use Test::More tests => 3;

subtest 'default' => sub {
    my $header = tie my %header, 'CGI::Header';
    is $header{Status}, undef;
    ok !exists $header{Status};
    is delete $header{Status}, undef;
    is_deeply $header->header, {};
};

subtest 'an empty string' => sub {
    my $header = tie my %header, 'CGI::Header', ( -status => q{} );
    is $header{Status}, undef;
    ok !exists $header{Status};
    is delete $header{Status}, undef; 
    is_deeply $header->header, {};
};

subtest 'a plain string' => sub {
    my $header = tie my %header, 'CGI::Header';
    is $header->set( Status => '304 Not Modified' ), '304 Not Modified';
    is_deeply $header->header, { -status => '304 Not Modified' };
    is $header{Status}, '304 Not Modified';
    ok exists $header{Status};
    is delete $header{Status}, '304 Not Modified';
    is_deeply $header->header, {};
};
