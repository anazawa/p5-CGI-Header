use strict;
use warnings;
use CGI::Header;
use Test::More tests => 12;
use Test::Exception;

my %env;
my $header = tie my %header, 'CGI::Header', {}, \%env;

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

%{ $header->env } = ();
is $header{Server}, 'cmdline';
ok exists $header{Server};

%{ $header->env } = ( SERVER_SOFTWARE => 'Apache/1.3.27 (Unix)' );
is $header{Server}, 'Apache/1.3.27 (Unix)';
ok exists $header{Server};

my $expected = qr{^Modification of a read-only value attempted};
throws_ok { $header{Server} = 'Apache/1.3.27 (Unix)' } $expected;
throws_ok { delete $header{Server} } $expected;
