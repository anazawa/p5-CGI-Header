use inc::Module::Install;

all_from 'lib/CGI/Header.pm';

repository 'https://github.com/anazawa/p5-CGI-Header';

requires 'Carp'         => '1.10';
requires 'CGI::Util'    => '1.5';
requires 'List::Util'   => '1.19';
requires 'Scalar::Util' => '1.19';

test_requires 'Test::Exception' => '0.31';
test_requires 'Test::More'      => '0.98';
test_requires 'Test::Pod'       => '1.45';
test_requires 'Test::Warn'      => '0.24';
test_requires 'Test::MockTime';
test_requires 'CGI::Cookie';
test_requires 'CGI' => '3.51';

tests 't/*.t xt/*.t';

WriteAll;
