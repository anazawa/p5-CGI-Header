use CGI::Header;
use Test::Base skip_all => '_normalize() was replaced with _lc()';

plan tests => 1 * blocks();

run {
    my $block = shift;
    is CGI::Header::_normalize( $block->input ), $block->expected;
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
--- expected: -set_cookie
===
--- input:    Window-Target
--- expected: -window_target
===
--- input:    P3P
--- expected: -p3p
===
--- input: Cookie
===
--- input: Cookies
===
--- input: Target
===
--- input: Attachment
===
--- input: Charset
===
--- input: NPH
===
--- input: Type
