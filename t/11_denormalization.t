use strict;
use CGI::Header::Dispatcher;
use Test::Base;

plan tests => 1 * blocks();

my $dispatcher = 'CGI::Header::Dispatcher';

run {
    my $block = shift;
    is $dispatcher->_denormalize( $block->input ), $block->expected;
};

__DATA__
===
--- input:    -foo
--- expected: Foo
===
--- input:    -foo_bar
--- expected: Foo-bar
===
--- input:    -cookie
--- expected: Set-Cookie
===
--- input:    -target
--- expected: Window-Target
===
--- input:    -p3p 
--- expected: P3P
===
--- input:    -attachment
--- expected: Content-Disposition
===
--- input:    -type
--- expected: Content-Type
