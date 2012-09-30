use strict;
use warnings;
use CGI::Header;
use Test::More tests => 13;

my %adaptee;
tie my %adapter, 'CGI::Header', \%adaptee;

%adaptee = ();
is $adapter{Window_Target}, undef;
ok !exists $adapter{Window_Target};
is delete $adapter{Window_Target}, undef;
is_deeply \%adaptee, {};

%adaptee = ( -target => q{} );
is $adapter{Window_Target}, q{};
ok exists $adapter{Window_Target};
is delete $adapter{Window_Target}, q{};
is_deeply \%adaptee, {};

%adaptee = ( -target => 'ResultsWindow' );
is $adapter{Window_Target}, 'ResultsWindow';
ok exists $adapter{Window_Target};
is delete $adapter{Window_Target}, 'ResultsWindow';
is_deeply \%adaptee, {};

%adaptee = ();
$adapter{Window_Target} = 'ResultsWindow';
is_deeply \%adaptee, { -target => 'ResultsWindow' };
