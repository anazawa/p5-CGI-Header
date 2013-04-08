use strict;
use warnings;
use CGI::Header;
use Test::More tests => 4;

subtest 'default' => sub {
    my $header = tie my %header, 'CGI::Header';
    is $header{Content_Disposition}, undef;
    ok !exists $header{Content_Disposition};
    is $header->attachment, undef;
    is delete $header{Content_Disposition}, undef;
    is_deeply $header->header, {};
};

subtest '-attachment' => sub {
    my $header = tie my %header, 'CGI::Header';

    %{ $header->header } = ( attachment => undef );
    is $header{'Content-Disposition'}, undef;
    ok !exists $header{'Content-Disposition'};
    is $header->attachment, undef;
    #is delete $header{'Content-Disposition'}, undef;
    #is_deeply $header->header, {};

    %{ $header->header } = ( attachment => q{} );
    is $header{'Content-Disposition'}, undef;
    ok !exists $header{'Content-Disposition'};
    is $header->attachment, q{};
    #is delete $header{'Content-Disposition'}, undef;
    #is_deeply $header->header, {};

    %{ $header->header } = ( attachment => 'genome.jpg' );
    is $header->as_hashref->{'Content-Disposition'}, 'attachment; filename="genome.jpg"';
    ok exists $header->as_hashref->{'Content-Disposition'};
    is $header->attachment, 'genome.jpg';
    #is delete $header{Content_Disposition}, 'attachment; filename="genome.jpg"';
    #is_deeply $header->header, {};

    %{ $header->header } = ();
    $header->attachment( 'genome.jpg' );
    is_deeply $header->header, { attachment => 'genome.jpg' };
};

subtest '-content_disposition' => sub {
    my $header = tie my %header, 'CGI::Header';

    %{ $header->header } = ( 'content-disposition' => q{} );
    is $header{'Content-Disposition'}, q{};
    ok exists $header{'Content-Disposition'};
    is delete $header{'Content-Disposition'}, q{};
    is_deeply $header->header, {};

    %{ $header->header } = ( 'content-disposition' => 'inline' );
    is $header{'Content-Disposition'}, 'inline';
    ok exists $header{'Content-Disposition'};
    is delete $header{'Content-Disposition'}, 'inline';
    is_deeply $header->header, {};
};

subtest '-attachment and -content_disposition' => sub {
    plan skip_all => 'obsolete';

    my $header = tie my %header, 'CGI::Header';

    %{ $header->header } = ( attachment => 'genome.jpg' );
    is $header->set( 'Content-Disposition' => 'inline' ), 'inline';
    is_deeply $header->header, { 'content-disposition' => 'inline' };

    %{ $header->header } = ( attachment => 'genome.jpg' );
    is $header->set( 'Content-Disposition' => q{} ), q{};
    is_deeply $header->header, { 'content-disposition' => q{} };
};

