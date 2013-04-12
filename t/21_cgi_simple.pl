use strict;
use warnings;
use Test::More tests => 1;

package CGI::Simple::Header;
use base 'CGI::Header';

sub _build_cookie{
    require CGI::Simple::Standard;
    CGI::Simple::Standard->loader('_cgi_object');
}

package main;

my $header = CGI::Simple::Header->new;

isa_ok $header->query, 'CGI::Simple';
