use strict;
use warnings;
use CGI::Header;
use Test::More tests => 2;

my %adaptee;
my $adapter = CGI::Header->new( \%adaptee );

#subtest 'charset()' => sub {
#    %adaptee = ();
#    is $adapter->charset, 'ISO-8859-1';

#    %adaptee = ( -charset => q{} );
#    is $adapter->charset, undef;

#    %adaptee = ( -type => q{} );
#    is $adapter->charset, undef;

#    %adaptee = ( -type => 'text/html; charset=euc-jp' );
#    is $adapter->charset, 'EUC-JP';

#    %adaptee = ( -type => 'text/html; charset=iso-8859-1; Foo=1' );
#    is $adapter->charset, 'ISO-8859-1';

#    %adaptee = ( -type => 'text/html; charset="iso-8859-1"; Foo=1' );
#    is $adapter->charset, 'ISO-8859-1';

#    %adaptee = ( -type => 'text/html; charset = "iso-8859-1"; Foo=1' );
#    is $adapter->charset, 'ISO-8859-1';

#    %adaptee = ( -type => 'text/html;\r\n charset = "iso-8859-1"; Foo=1' );
#    is $adapter->charset, 'ISO-8859-1';

#    %adaptee = ( -type => 'text/html;\r\n charset = iso-8859-1 ; Foo=1' );
#    is $adapter->charset, 'ISO-8859-1';

#    %adaptee = ( -type => 'text/html;\r\n charset = iso-8859-1 ' );
#    is $adapter->charset, 'ISO-8859-1';
#};

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
