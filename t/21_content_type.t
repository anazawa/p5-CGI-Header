use strict;
use warnings;
use CGI::Header;
use Test::More tests => 1;

my %adaptee;
my $adapter = CGI::Header->new( \%adaptee );

subtest 'content_type()' => sub {
    %adaptee = ();
    is $adapter->content_type, 'text/html';
    my @got = $adapter->content_type;
    my @expected = ( 'text/html', 'charset=ISO-8859-1' );
    is_deeply \@got, \@expected;

    %adaptee = ( -type => 'text/plain; charset=EUC-JP; Foo=1' );
    is $adapter->content_type, 'text/plain';
    @got = $adapter->content_type;
    @expected = ( 'text/plain', 'charset=EUC-JP; Foo=1' );
    is_deeply \@got, \@expected;

    %adaptee = ();
    $adapter->content_type( 'text/plain; charset=EUC-JP' );
    is_deeply \%adaptee, {
        -type    => 'text/plain; charset=EUC-JP',
        -charset => q{},
    };

    %adaptee = ( -type => q{} );
    is $adapter->content_type, q{};

    %adaptee = ( -type => '   TEXT  / HTML   ' );
    is $adapter->content_type, 'text/html';
};
