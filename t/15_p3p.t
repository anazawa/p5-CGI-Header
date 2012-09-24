use strict;
use warnings;
use CGI::Header;
use Test::More tests => 11;
use Test::Warn;

my %adaptee;
my $adapter = tie my %adapter, 'CGI::Header', \%adaptee;

%adaptee = ( -p3p => [qw/CAO DSP LAW CURa/] );
is $adapter{P3P}, 'policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"';
is $adapter->p3p_tags, 'CAO';
is_deeply [ $adapter->p3p_tags ], [qw/CAO DSP LAW CURa/];

%adaptee = ();
$adapter->p3p_tags( 'CAO' );
is $adapter->p3p_tags, 'CAO';
is_deeply \%adaptee, { -p3p => 'CAO' };
is delete $adapter{P3P}, 'policyref="/w3c/p3p.xml", CP="CAO"';

%adaptee = ();
$adapter->p3p_tags( 'CAO DSP LAW CURa' );
is_deeply \%adaptee, { -p3p => 'CAO DSP LAW CURa' };

%adaptee = ();
$adapter->p3p_tags( qw/CAO DSP LAW CURa/ );
is_deeply \%adaptee, { -p3p => [qw/CAO DSP LAW CURa/] };

%adaptee = ( -p3p => 'CAO DSP LAW CURa' );
is $adapter->p3p_tags, 'CAO';
is_deeply [ $adapter->p3p_tags ], [qw/CAO DSP LAW CURa/];

warning_is { $adapter{P3P} = 'CAO DSP LAW CURa' }
    "Can't assign to '-p3p' directly, use accessors instead";
