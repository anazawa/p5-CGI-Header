use strict;
use warnings;
use CGI::Header;
use Test::More tests => 26;

my %adaptee;
my $adapter = tie my %adapter, 'CGI::Header', \%adaptee;

%adaptee = ( -type => q{} );
is $adapter{Content_Type}, undef;
ok !exists $adapter{Content_Type};
is delete $adapter{Content_Type}, undef;

%adaptee = ();
is $adapter{Content_Type}, 'text/html; charset=ISO-8859-1';
ok exists $adapter{Content_Type};
is delete $adapter{Content_Type}, 'text/html; charset=ISO-8859-1';
is_deeply \%adaptee, { -type => q{} };

%adaptee = ( -type => 'text/plain' );
is $adapter{Content_Type}, 'text/plain; charset=ISO-8859-1';
ok exists $adapter{Content_Type};

%adaptee = ( -type => undef );
is $adapter{Content_Type}, 'text/html; charset=ISO-8859-1';
ok exists $adapter{Content_Type};
ok %adapter;

%adaptee = ( -type => undef, -charset => 'utf-8' );
is $adapter{Content_Type}, 'text/html; charset=utf-8';

%adaptee = ( -type => 'text/plain', -charset => 'utf-8' );
is delete $adapter{Content_Type}, 'text/plain; charset=utf-8';
is_deeply \%adaptee, { -type => q{} };

# feature
%adaptee = ( -type => 'text/plain; charSet=utf-8' );
is $adapter{Content_Type}, 'text/plain; charSet=utf-8; charset=ISO-8859-1';

# FETCH

%adaptee = ( -charset => 'utf-8' );
is $adapter{Content_Type}, 'text/html; charset=utf-8';

%adaptee = ( -type => q{}, -charset => 'utf-8' );
is $adapter{Content_Type}, undef;

%adaptee = ( -type => 'text/plain; charset=EUC-JP' );
is $adapter{Content_Type}, 'text/plain; charset=EUC-JP';

%adaptee = (
    -type    => 'text/plain; charset=euc-jp',
    -charset => 'utf-8',
);
is $adapter{Content_Type}, 'text/plain; charset=euc-jp';

%adaptee = ( -charset => q{} );
is $adapter{Content_Type}, 'text/html';

%adaptee = ( -type => 'text/plain; Foo=1', -charset => 'utf-8' );
is $adapter{Content_Type}, 'text/plain; Foo=1; charset=utf-8';


# STORE

%adaptee = ();
$adapter{Content_Type} = 'text/plain; charset=utf-8';
is_deeply \%adaptee, {
    -type    => 'text/plain; charset=utf-8',
    -charset => q{}
};

%adaptee = ();
$adapter{Content_Type} = 'text/plain';
is_deeply \%adaptee, { -type => 'text/plain', -charset => q{} };

%adaptee = ( -charset => 'euc-jp' );
$adapter{Content_Type} = 'text/plain; charset=utf-8';
is_deeply \%adaptee, {
    -type    => 'text/plain; charset=utf-8',
    -charset => q{},
};

%adaptee = ();
$adapter{Content_Type} = q{};
is_deeply \%adaptee, { -type => q{}, -charset => q{} };
