use strict;
use warnings;
use CGI::Header;
use Test::More tests => 13;

my $header = tie my %header, 'CGI::Header';

%{ $header->header } = ();
is $header{Window_Target}, undef;
ok !exists $header{Window_Target};
is delete $header{Window_Target}, undef;
is_deeply $header->header, {};

%{ $header->header } = ( -target => q{} );
is $header{Window_Target}, q{};
ok exists $header{Window_Target};
is delete $header{Window_Target}, q{};
is_deeply $header->header, {};

%{ $header->header } = ( -target => 'ResultsWindow' );
is $header{Window_Target}, 'ResultsWindow';
ok exists $header{Window_Target};
is delete $header{Window_Target}, 'ResultsWindow';
is_deeply $header->header, {};

%{ $header->header } = ();
$header{Window_Target} = 'ResultsWindow';
is_deeply $header->header, { -target => 'ResultsWindow' };
