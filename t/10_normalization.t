use strict;
use warnings;
use CGI::Header;
use Test::Base;

plan tests => 1 * blocks();

my $header = 'CGI::Header';

run {
    my $block = shift;
    is $header->_normalize( $block->input ), $block->expected;
};

__DATA__
===
--- input:    foo
--- expected: -foo
===
--- input:    Foo
--- expected: -foo
===
--- input:    foo-bar
--- expected: -foo_bar
===
--- input:    Foo-bar
--- expected: -foo_bar
===
--- input:    Foo-Bar
--- expected: -foo_bar
===
--- input:    foo_bar
--- expected: -foo_bar
===
--- input:    Foo_bar
--- expected: -foo_bar
===
--- input:    Foo_Bar
--- expected: -foo_bar
===
--- input:    Set-Cookie
--- expected: -cookie
===
--- input:    Window-Target
--- expected: -target
===
--- input:    P3P
--- expected: -p3p
===
--- input:    cookie
--- expected:
===
--- input:    target
--- expected:
===
--- input:    attachment
--- expected: 
===
--- input:    charset
--- expected: 
===
--- input:    nph
--- expected: 
===
--- input:    type
--- expected: 
