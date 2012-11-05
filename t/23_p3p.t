use strict;
use warnings;
use CGI::Header;
use Test::More tests => 22;
use Test::Warn;

my $header = tie my %header, 'CGI::Header';

%{ $header->header } = ();
is $header{P3P}, undef;
ok !exists $header{P3P};
is delete $header{P3P}, undef;
is_deeply $header->header, {};

%{ $header->header } = ( -p3p => q{} );
is $header{P3P}, q{};
ok exists $header{P3P};
is delete $header{P3P}, q{};
is_deeply $header->header, {};

%{ $header->header } = ( -p3p => [qw/CAO DSP LAW CURa/] );
is $header{P3P}, 'policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"';
ok exists $header{P3P};
is $header->p3p_tags, 'CAO';
is_deeply [ $header->p3p_tags ], [qw/CAO DSP LAW CURa/];
is delete $header{P3P}, 'policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"';
is_deeply $header->header, {};

%{ $header->header } = ();
$header->p3p_tags( 'CAO DSP LAW CURa' );
is_deeply $header->header, { -p3p => 'CAO DSP LAW CURa' };
ok exists $header{P3P};
is $header->p3p_tags, 'CAO';
is_deeply [ $header->p3p_tags ], [qw/CAO DSP LAW CURa/];
is delete $header{P3P}, 'policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"';
is_deeply $header->header, {};

%{ $header->header } = ();
$header->p3p_tags( qw/CAO DSP LAW CURa/ );
is_deeply $header->header, { -p3p => [qw/CAO DSP LAW CURa/] };

warning_is { $header{P3P} = '/path/to/p3p.xml' }
    "Can't assign to '-p3p' directly, use p3p_tags() instead";
