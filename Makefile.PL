use inc::Module::Install;

all_from 'lib/CGI/Header.pm';

repository 'https://github.com/anazawa/p5-CGI-Header';

requires 'overload'     => '1.06';
requires 'parent'       => '0.225';
requires 'Carp'         => '1.10';
requires 'CGI::Cookie'  => '1.29';
requires 'CGI::Util'    => '1.5';
requires 'List::Util'   => '1.19';
requires 'Scalar::Util' => '1.19';
requires 'Storable'     => '2.18';

requires 'HTTP::Date'   => '6.02';
requires 'HTTP::Status' => '6.03';

test_requires 'Test::Base'      => '0.60';
test_requires 'Test::Exception' => '0.31';
test_requires 'Test::More'      => '0.98';
test_requires 'Test::Pod'       => '1.45';
test_requires 'Test::Warn'      => '0.24';
test_requires 'CGI'             => '3.49';

tests 't/*.t xt/*.t';

WriteAll;
