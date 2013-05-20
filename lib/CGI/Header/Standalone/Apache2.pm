package CGI::Header::Standalone::Apache2;
use strict;
use warnings;
use parent 'CGI::Header::Standalone';

sub finalize {
    my $self = shift;
    $self->query->r->send_cgi_header( $self->SUPER::finalize );
    q{};
}

1;
