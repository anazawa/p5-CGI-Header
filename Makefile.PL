use inc::Module::Install;

all_from 'lib/CGI/Header.pm';
readme_from 'lib/CGI/Header.pm';

repository 'https://github.com/anazawa/p5-CGI-Header';

requires 'Carp' => '1.10';
requires 'CGI' => '3.51';

test_requires 'Test::More' => '0.98';
test_requires 'Test::Pod'  => '1.45';

tests 't/*.t xt/*.t';

WriteAll;
