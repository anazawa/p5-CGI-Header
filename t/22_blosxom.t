use strict;
use warnings;
use Test::More tests => 1;

sub run_blosxom {
    package blosxom;
    require CGI;

    our $static_entries = 0;
    our $header = { -type => 'text/html' };
    our $output = 'hello, world';

    my $plugin = 'my_plugin';
    $plugin->last if $plugin->start;

    CGI::header( $header ) . $output;
}

package Blosxom::Header;
use base 'CGI::Header';

our $INSTANCE;

sub instance {
    $INSTANCE ||= $_[0]->SUPER::new( header => $blosxom::header )->rehash;
}

package my_plugin;

sub start {
    !$blosxom::static_entries;
}

sub last {
    my $header = Blosxom::Header->instance;
    $header->set( 'Content-Length' => length $blosxom::output );
}

package main;

like run_blosxom(), qr{Content-length: 12};
