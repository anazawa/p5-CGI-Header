use strict;
use warnings;
use CGI::Header;
use Test::More tests => 3;

my %adaptee;
tie my %adapter, 'CGI::Header', \%adaptee;

%adaptee = ();
is $adapter{Server}, undef;

%adaptee = ( -nph => 1 );
local $ENV{SERVER_SOFTWARE};
is $adapter{Server}, 'cmdline';
$ENV{SERVER_SOFTWARE} = 'Apache/1.3.27 (Unix)';
is $adapter{Server}, 'Apache/1.3.27 (Unix)';
