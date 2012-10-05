use strict;
use warnings;
use CGI::Header;
use Test::More tests => 22;
use Test::Warn;

my %adaptee;
my $adapter = tie my %adapter, 'CGI::Header', \%adaptee;

%adaptee = ();
is $adapter{P3P}, undef;
ok !exists $adapter{P3P};
is delete $adapter{P3P}, undef;
is_deeply \%adaptee, {};

%adaptee = ( -p3p => q{} );
is $adapter{P3P}, q{};
ok exists $adapter{P3P};
is delete $adapter{P3P}, q{};
is_deeply \%adaptee, {};

%adaptee = ( -p3p => [qw/CAO DSP LAW CURa/] );
is $adapter{P3P}, 'policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"';
ok exists $adapter{P3P};
is $adapter->p3p_tags, 'CAO';
is_deeply [ $adapter->p3p_tags ], [qw/CAO DSP LAW CURa/];
is delete $adapter{P3P}, 'policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"';
is_deeply \%adaptee, {};

%adaptee = ();
$adapter->p3p_tags( 'CAO DSP LAW CURa' );
is_deeply \%adaptee, { -p3p => 'CAO DSP LAW CURa' };
ok exists $adapter{P3P};
is $adapter->p3p_tags, 'CAO';
is_deeply [ $adapter->p3p_tags ], [qw/CAO DSP LAW CURa/];
is delete $adapter{P3P}, 'policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"';
is_deeply \%adaptee, {};

%adaptee = ();
$adapter->p3p_tags( qw/CAO DSP LAW CURa/ );
is_deeply \%adaptee, { -p3p => [qw/CAO DSP LAW CURa/] };

warning_is { $adapter{P3P} = '/path/to/p3p.xml' }
    "Can't assign to '-p3p' directly, use p3p_tags() instead";
