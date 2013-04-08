use strict;
use warnings;
use CGI::Header;
use Test::More tests => 3;

subtest 'default' => sub {
    my $header = CGI::Header->new;
    is $header->as_hashref->{'Window-Target'}, undef;
    ok !$header->exists('Window-Target');
    #is delete $header{Window_Target}, undef;
    #is_deeply $header->header, {};
};

subtest 'an empty string' => sub {
    my $header = CGI::Header->new( -target => q{} );
    is $header->as_hashref->{'Window-Target'}, undef;
    ok !exists $header->as_hashref->{'Window-Target'};
    #is delete $header{target}, q{}; 
    #is_deeply $header->header, {};
};

subtest 'a plain string' => sub {
    my $header = CGI::Header->new;
    is $header->target( 'ResultsWindow' ), $header;
    is_deeply $header->header, { target => 'ResultsWindow' };
    is $header->as_hashref->{'Window-Target'}, 'ResultsWindow';
    ok exists $header->as_hashref->{'Window-Target'};
    #is delete $header{Window_Target}, 'ResultsWindow';
    #is_deeply $header->header, {};
};
