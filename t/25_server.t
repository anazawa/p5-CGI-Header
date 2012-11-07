use strict;
use warnings;
use CGI::Header;
use Test::More tests => 10;

my $header = tie my %header, 'CGI::Header';

%{ $header->header } = ();
is $header{Server}, undef;
ok !exists $header{Server};
$header{Server} = 'Apache/1.3.27 (Unix)';
is_deeply $header->header, { -server => 'Apache/1.3.27 (Unix)' };

%{ $header->header } = ( -server => 'Apache/1.3.27 (Unix)' );
is $header{Server}, 'Apache/1.3.27 (Unix)';
ok exists $header{Server};
$header->nph( 1 );
is_deeply $header->header, { -nph => 1 }, '-server should be deleted';

%{ $header->header } = ( -nph => 1 );

local $ENV{SERVER_SOFTWARE};
is $header{Server}, 'cmdline';
ok exists $header{Server};

$ENV{SERVER_SOFTWARE} = 'Apache/1.3.27 (Unix)';
is $header{Server}, 'Apache/1.3.27 (Unix)';
ok exists $header{Server};

