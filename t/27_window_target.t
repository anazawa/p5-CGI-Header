use strict;
use warnings;
use CGI::Header;
use Test::More tests => 3;

subtest 'default' => sub {
    my $header = tie my %header, 'CGI::Header';
    is $header{Window_Target}, undef;
    ok !exists $header{Window_Target};
    is delete $header{Window_Target}, undef;
    is_deeply $header->header, {};
};

subtest 'an empty string' => sub {
    my $header = tie my %header, 'CGI::Header', ( -target => q{} );
    is $header{Window_Target}, q{};
    ok exists $header{Window_Target};
    is delete $header{Window_Target}, q{};
    is_deeply $header->header, {};
};

subtest 'a plain string' => sub {
    my $header = tie my %header, 'CGI::Header';
    is $header->set( Window_Target => 'ResultsWindow' ), 'ResultsWindow';
    is_deeply $header->header, { -target => 'ResultsWindow' };
    is $header{Window_Target}, 'ResultsWindow';
    ok exists $header{Window_Target};
    is delete $header{Window_Target}, 'ResultsWindow';
    is_deeply $header->header, {};
};
