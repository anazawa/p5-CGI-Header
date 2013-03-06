use strict;
use Data::Dumper;
use Test::More tests => 1;
use CGI::Header::Simple;

my $header = CGI::Header::Simple->new;

ok $header->isa('CGI::Header');
ok $header->query->isa('CGI::Simple');



#$header->query->no_cache(1);

#warn Dumper([$h->flatten]);

#warn "$h";

ok 1;
