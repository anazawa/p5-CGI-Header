use strict;
use warnings;
use CGI::Header;
use Test::More tests => 5;
use Test::Warn;

subtest 'default' => sub {
    my $header = tie my %header, 'CGI::Header';
    is $header->as_hashref->{'Content-Type'}, 'text/html; charset=ISO-8859-1';
    ok exists $header->as_hashref->{'Content-Type'};
    #is delete $header{Content_Type}, 'text/html; charset=ISO-8859-1';
    #is_deeply $header->header, { -type => q{} };
};

subtest '-type' => sub {
    my $header = tie my %header, 'CGI::Header';

    %{ $header->header } = ( -type => q{} );
    is $header{Content_Type}, undef;
    ok !exists $header{Content_Type};
    is delete $header{Content_Type}, undef;
    is_deeply $header->header, { -type => q{} };

    %{ $header->header } = ( -type => 'text/plain' );
    is $header->as_hashref->{'Content-Type'}, 'text/plain; charset=ISO-8859-1';
    ok exists $header->as_hashref->{'Content-Type'};

    %{ $header->header } = ( -type => undef );
    is $header->as_hashref->{'Content-Type'}, 'text/html; charset=ISO-8859-1';
    ok exists $header->as_hashref->{'Content-Type'};
    ok %header;

    %{ $header->header } = ( -type => 'text/plain; charset=EUC-JP' );
    is $header->as_hashref->{'Content-Type'}, 'text/plain; charset=EUC-JP';

    # feature
    %{ $header->header } = (
        -type => 'text/plain; charSet=utf-8',
        -charset => 'ISO-8859-1',
    );
    is $header->as_hashref->{'Content-Type'}, 'text/plain; charSet=utf-8; charset=ISO-8859-1';
};

subtest '-charset' => sub {
    my $header = tie my %header, 'CGI::Header';

    %{ $header->header } = ( -charset => 'utf-8' );
    is $header->as_hashref->{'Content-Type'}, 'text/html; charset=utf-8';

    %{ $header->header } = ( -charset => q{} );
    is $header->as_hashref->{'Content-Type'}, 'text/html';
};

subtest '-type and -charset' => sub {
    my $header = tie my %header, 'CGI::Header';

    %{ $header->header } = ( -type => undef, -charset => 'utf-8' );
    is $header->as_hashref->{'Content-Type'}, 'text/html; charset=utf-8';

    #%{ $header->header } = ( -type => 'text/plain', -charset => 'utf-8' );
    #is delete $header{Content_Type}, 'text/plain; charset=utf-8';
    #is_deeply $header->header, { -type => q{} };

    %{ $header->header } = ( -type => q{}, -charset => 'utf-8' );
    is $header{Content_Type}, undef;

    %{ $header->header } = (
        -type    => 'text/plain; charset=euc-jp',
        -charset => 'utf-8',
    );
    is $header->as_hashref->{'Content-Type'}, 'text/plain; charset=euc-jp';

    %{ $header->header } = (
        -type    => 'text/plain; Foo=1',
        -charset => 'utf-8',
    );
    is $header->as_hashref->{'Content-Type'}, 'text/plain; Foo=1; charset=utf-8';
};

subtest 'STORE()' => sub {
    my $header = tie my %header, 'CGI::Header';

    %{ $header->header } = ();
    my $value = 'text/plain; charset=utf-8';
    is $header->set( Content_Type => $value ), $value;
    is_deeply $header->header, {
        -type    => 'text/plain; charset=utf-8',
        -charset => q{}
    };

    %{ $header->header } = ();
    is $header->set( Content_Type => 'text/plain' ), 'text/plain';
    is_deeply $header->header, { -type => 'text/plain', -charset => q{} };

    %{ $header->header } = ( -charset => 'euc-jp' );
    $value = 'text/plain; charset=utf-8';
    is $header->set( Content_Type => $value ), $value;
    is_deeply $header->header, {
        -type    => 'text/plain; charset=utf-8',
        -charset => q{},
    };

    %{ $header->header } = ();
    warning_is { $header{Content_Type} = q{} }
        "Can set '-content_type' to neither undef nor an empty string";
    is_deeply $header->header, {};
};
