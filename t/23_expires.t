use strict;
use warnings;
use Test::MockTime qw/set_fixed_time/;
use CGI::Header;
use Test::More tests => 18;
use Test::Warn;

set_fixed_time '1341637509';

my $today    = 'Sat, 07 Jul 2012 05:05:09 GMT';
my $tomorrow = 'Sun, 08 Jul 2012 05:05:09 GMT';

my $header = tie my %header, 'CGI::Header';

%{ $header->header } = ();
ok !exists $header{Expires};
is $header{Expires}, undef;
is $header->expires, undef;
is delete $header{Expires}, undef;
is_deeply $header->header, {};

%{ $header->header } = ( expires => '+1d' );
ok exists $header{Expires};
ok exists $header->as_hashref->{Date};
is $header->as_hashref->{Expires}, $tomorrow;
is $header->as_hashref->{Date}, $today;
is $header->expires, '+1d';
#is delete $header{Expires}, $tomorrow;
#is_deeply $header->header, {};

#warning_is { delete $header{Date} } 'The Date header is fixed';
#warning_is { $header{Date} = 'foo' } 'The Date header is fixed';

%{ $header->header } = ( expires => q{} );
ok !exists $header->as_hashref->{Expires};
ok !exists $header{Date};
is $header->as_hashref->{Expires}, undef;
is $header{Date}, undef;
is $header->expires, q{};
#is delete $header{Expires}, undef;
#is_deeply $header->header, {};

#%adaptee = ( -expires => 0 );

# Follows the rule of least surprize.
# The following behavior will surprize us ;)
#
#   $header{Expires} = '+3d';
#   my $value = $header{Expires}; # => "Tue, 10 Jul 2012 05:05:09 GMT"
#

warning_is { $header{Expires} = '+3d' }
    "Can't assign to '-expires' directly, use expires() instead";

%{ $header->header } = ();
$header->expires( '+3d' );
is_deeply $header->header, { expires => '+3d' };

%{ $header->header } = ( date => $today );
$header->expires( '+3d' );
is_deeply $header->header, { expires => '+3d' };

