use strict;
use warnings;
use CGI::Header;
use Test::More tests => 4;

subtest 'default' => sub {
    my $header = CGI::Header->new;
    is $header->as_hashref->{'Content-disposition'}, undef;
    ok !exists $header->as_hashref->{'Content-disposition'};
    is $header->attachment, undef;
    #is delete $header{Content_Disposition}, undef;
    #is_deeply $header->header, {};
};

subtest '-attachment' => sub {
    my $header = CGI::Header->new;

    %{ $header->header } = ( attachment => undef );
    is $header->as_hashref->{'Content-disposition'}, undef;
    ok !exists $header->as_hashref->{'Content-disposition'};
    is $header->attachment, undef;
    #is delete $header{'Content-Disposition'}, undef;
    #is_deeply $header->header, {};

    %{ $header->header } = ( attachment => q{} );
    is $header->as_hashref->{'Content-Disposition'}, undef;
    ok !exists $header->as_hashref->{'Content-disposition'};
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
    my $header = CGI::Header->new;

    %{ $header->header } = ( 'content-disposition' => q{} );
    is $header->as_hashref->{'Content-disposition'}, q{};
    ok exists $header->as_hashref->{'Content-disposition'};
    #is delete $header{'Content-Disposition'}, q{};
    #is_deeply $header->header, {};

    %{ $header->header } = ( 'content-disposition' => 'inline' );
    is $header->as_hashref->{'Content-disposition'}, 'inline';
    ok exists $header->as_hashref->{'Content-disposition'};
    #is delete $header{'Content-Disposition'}, 'inline';
    #is_deeply $header->header, {};
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

