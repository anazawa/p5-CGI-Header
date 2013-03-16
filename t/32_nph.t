use strict;
use CGI '-nph';
use CGI::Header;
use Test::Exception;
use Test::More tests => 3;

my $header = CGI::Header->new;

ok $header->nph, '-nph pragma is enabled';

throws_ok { $header->nph(0) }
    qr{pragma is enabled},
    'CGI::Header#nph should be read-only';

lives_ok { $header->nph(1) };
