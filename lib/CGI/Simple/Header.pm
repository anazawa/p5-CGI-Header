package CGI::Header::Simple;
use strict;
use warnings;
use base 'CGI::Header';

sub _build_query {
    require CGI::Simple::Standard;
    CGI::Simple::Standard->load( '_cgi_object' );
}

1;
