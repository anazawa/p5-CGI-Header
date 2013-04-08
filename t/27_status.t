use strict;
use warnings;
use CGI::Header;
use Test::More tests => 3;

subtest 'default' => sub {
    my $header = CGI::Header->new;
    is $header->as_hashref->{Status}, undef;
    ok !exists $header->as_hashref->{Status};
    #is delete $header{Status}, undef;
    #is_deeply $header->header, {};
};

subtest 'an empty string' => sub {
    my $header = CGI::Header->new( -status => q{} );
    is $header->as_hashref->{Status}, undef;
    ok !exists $header->as_hashref->{Status};
    #is delete $header{Status}, undef; 
    #is_deeply $header->header, {};
};

subtest 'a plain string' => sub {
    my $header = CGI::Header->new;
    is $header->status('304 Not Modified'), $header;
    is_deeply $header->header, { status => '304 Not Modified' };
    is $header->status, '304 Not Modified';
    ok $header->exists('Status');
    is $header->delete('Status'), '304 Not Modified';
    is_deeply $header->header, {};
};
