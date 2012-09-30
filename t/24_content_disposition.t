use strict;
use warnings;
use CGI::Header;
use Test::More tests => 31;

my %adaptee;
my $adapter = tie my %adapter, 'CGI::Header', \%adaptee;

%adaptee = ();
is $adapter{Content_Disposition}, undef;
ok !exists $adapter{Content_Disposition};
is $adapter->attachment, undef;
is delete $adapter{Content_Disposition}, undef;
is_deeply \%adaptee, {};

%adaptee = ( -attachment => undef );
is $adapter{Content_Disposition}, undef;
ok !exists $adapter{Content_Disposition};
is $adapter->attachment, undef;
is delete $adapter{Content_Disposition}, undef;
is_deeply \%adaptee, {};

%adaptee = ( -attachment => q{} );
is $adapter{Content_Disposition}, undef;
ok !exists $adapter{Content_Disposition};
is $adapter->attachment, q{};
is delete $adapter{Content_Disposition}, undef;
is_deeply \%adaptee, {};

%adaptee = ( -attachment => 'genome.jpg' );
is $adapter{Content_Disposition}, 'attachment; filename="genome.jpg"';
ok exists $adapter{Content_Disposition};
is $adapter->attachment, 'genome.jpg';
is delete $adapter{Content_Disposition}, 'attachment; filename="genome.jpg"';
is_deeply \%adaptee, {};

%adaptee = ( -content_disposition => q{} );
is $adapter{Content_Disposition}, q{};
ok exists $adapter{Content_Disposition};
is delete $adapter{Content_Disposition}, q{};
is_deeply \%adaptee, {};

%adaptee = ( -content_disposition => 'inline' );
is $adapter{Content_Disposition}, 'inline';
ok exists $adapter{Content_Disposition};
is delete $adapter{Content_Disposition}, 'inline';
is_deeply \%adaptee, {};

%adaptee = ( -attachment => 'genome.jpg' );
$adapter{Content_Disposition} = 'inline';
is_deeply \%adaptee, { -content_disposition => 'inline' };

%adaptee = ( -attachment => 'genome.jpg' );
$adapter{Content_Disposition} = q{};
is_deeply \%adaptee, { -content_disposition => q{} };

%adaptee = ();
$adapter->attachment( 'genome.jpg' );
is_deeply \%adaptee, { -attachment => 'genome.jpg' };
