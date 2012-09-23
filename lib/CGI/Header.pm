package CGI::Header;
use strict;
use warnings;
use overload '%{}' => 'as_hashref', 'fallback' => 1;
use parent 'CGI::Header::Entity';
use Carp qw/carp croak/;
use Scalar::Util qw/refaddr/;

my %header_of;

sub new {
    my $class = shift;
    my $header = ref $_[0] eq 'HASH' ? shift : { @_ };
    my $self = $class->SUPER::new( $header );
    tie my %header => 'CGI::Header::Entity' => $header;
    $header_of{ refaddr $self } = \%header;
    $self;
}

sub get {
    my ( $self, @fields ) = @_;
    my @values = map { $self->FETCH($_) } @fields;
    wantarray ? @values : $values[-1];
}

sub set {
    my ( $self, @headers ) = @_;

    if ( @headers % 2 == 0 ) {
        while ( my ($field, $value) = splice @headers, 0, 2 ) {
            $self->STORE( $field => $value );
        }
    }
    else {
        croak 'Odd number of elements passed to set()';
    }

    return;
}

sub delete {
    my ( $self, @fields ) = @_;

    if ( wantarray ) {
        return map { $self->DELETE($_) } @fields;
    }
    elsif ( defined wantarray ) {
        my $deleted = @fields && $self->DELETE( pop @fields );
        $self->DELETE( $_ ) for @fields;
        return $deleted;
    }
    else {
        $self->DELETE( $_ ) for @fields;
    }

    return;
}

sub clear    { shift->CLEAR        }
sub exists   { shift->EXISTS( @_ ) }
sub is_empty { not shift->SCALAR   }

sub flatten {
    my $self = shift;
    map { $_, $self->FETCH($_) } $self->field_names;
}

sub each {
    my ( $self, $callback ) = @_;

    if ( ref $callback eq 'CODE' ) {
        for my $field ( $self->field_names ) {
            $callback->( $field, $self->FETCH($field) );
        }
    }
    else {
        croak 'Must provide a code reference to each()';
    }

    return;
}

sub as_hashref { $header_of{ refaddr shift } }

sub charset {
    my $self = shift;

    require HTTP::Headers::Util;

    my %param = do {
        my $type = $self->FETCH( 'Content-Type' );
        my ( $params ) = HTTP::Headers::Util::split_header_words( $type );
        return unless $params;
        splice @{ $params }, 0, 2;
        @{ $params };
    };

    if ( my $charset = $param{charset} ) {
        $charset =~ s/^\s+//;
        $charset =~ s/\s+$//;
        return uc $charset;
    }

    return;
}

sub content_type {
    my $self = shift;

    if ( @_ ) {
        my $content_type = shift;
        $self->STORE( 'Content-Type' => $content_type );
        return;
    }

    my ( $media_type, $rest ) = do {
        my $content_type = $self->FETCH( 'Content-Type' );
        return q{} unless defined $content_type;
        split /;\s*/, $content_type, 2;
    };

    $media_type =~ s/\s+//g;
    $media_type = lc $media_type;

    wantarray ? ($media_type, $rest) : $media_type;
}

BEGIN { *type = \&content_type }

sub date { shift->_date_header( 'Date', @_ ) }

sub _date_header {
    my ( $self, $field, $time ) = @_;

    require HTTP::Date;

    if ( defined $time ) {
        $self->STORE( $field => HTTP::Date::time2str($time) );
    }
    elsif ( my $date = $self->FETCH($field) ) {
        return HTTP::Date::str2time( $date );
    }

    return;
}

sub set_cookie {
    my ( $self, $name, $value ) = @_;

    require CGI::Cookie;

    my $cookies = $self->FETCH( 'Set-Cookie' );

    unless ( ref $cookies eq 'ARRAY' ) {
        $cookies = $cookies ? [ $cookies ] : [];
        $self->STORE( 'Set-Cookie' => $cookies );
    }

    my $new_cookie = CGI::Cookie->new(do {
        my %args = ref $value eq 'HASH' ? %{ $value } : ( value => $value );
        $args{name} = $name;
        \%args;
    });

    for my $cookie ( @{$cookies} ) {
        next unless ref $cookie eq 'CGI::Cookie';
        next unless $cookie->name eq $name;
        $cookie = $new_cookie;
        undef $new_cookie;
        last;
    }

    push @{ $cookies }, $new_cookie if $new_cookie;

    return;
}

sub get_cookie {
    my ( $self, $name ) = @_;

    my @cookies = do {
        my $cookies = $self->FETCH( 'Set-Cookie' );
        return unless $cookies;
        ref $cookies eq 'ARRAY' ? @{ $cookies } : $cookies;
    };

    my @values;
    for my $cookie ( @cookies ) {
        next unless ref $cookie eq 'CGI::Cookie';
        next unless $cookie->name eq $name;
        push @values, $cookie;
    }

    wantarray ? @values : $values[0];
}

sub status {
    my $self = shift;

    require HTTP::Status;

    if ( @_ ) {
        my $code = shift;
        my $message = HTTP::Status::status_message( $code );
        return $self->STORE( Status => "$code $message" ) if $message;
        carp "Unknown status code '$code' passed to status()";
    }
    elsif ( my $status = $self->FETCH('Status') ) {
        return substr( $status, 0, 3 );
    }
    #else {
    #    return 200;
    #}

    return;
}

sub target {
    my $self = shift;
    return $self->STORE( 'Window-Target' => shift ) if @_;
    $self->FETCH( 'Window-Target' );
}

sub STORABLE_thaw {
    my $self = shift->SUPER::STORABLE_thaw( @_ );
    tie my %header => 'CGI::Header::Entity' => $self->header;
    $header_of{ refaddr $self } = \%header;
    $self;
}

sub DESTROY {
    my $self = shift;
    delete $header_of{ refaddr $self };
    $self->SUPER::DESTROY;
}

1;
