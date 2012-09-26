package CGI::Header::Dispatcher;
use strict;
use warnings;
use CGI::Util qw//;
use Carp qw/carp croak/;

my %Content_Type = (
    get => sub {
        my $self    = shift;
        my $header  = shift;
        my $type    = $header->{-type};
        my $charset = $header->{-charset};

        if ( defined $type and $type eq q{} ) {
            undef $charset;
            undef $type;
        }
        else {
            $type ||= 'text/html';

            if ( $type =~ /\bcharset\b/ ) {
                undef $charset;
            }
            elsif ( !defined $charset ) {
                $charset = 'ISO-8859-1';
            }
        }

        $charset ? "$type; charset=$charset" : $type;
    },
    set => sub {
        my ( $self, $header, $value ) = @_;
        @{ $header }{qw/-type -charset/} = ( $value, q{} );
        return;
    },
    exists => sub {
        my ( $self, $header ) = @_;
        !defined $header->{-type} || $header->{-type} ne q{};
    },
    delete => sub {
        my ( $self, $header ) = @_;
        my $value = defined wantarray && $self->get( 'Content-Type' );
        delete @{ $header }{qw/-charset -content_type/};
        $header->{-type} = q{};
        $value;
    },
);

my %Expires = (
    get => sub {
        my ( $self, $header ) = @_;
        my $expires = $header->{-expires};
        $expires && CGI::Util::expires( $expires );
    },
    set => sub {
        my $self = shift;
        carp "Can't assign to '-expires' directly, use expires() instead";
    },
);

my %P3P = (
    get => sub {
        my ( $self, $header ) = @_;
        my $tags = $header->{-p3p};
        $tags = join ' ', @{ $tags } if ref $tags eq 'ARRAY';
        $tags && qq{policyref="/w3c/p3p.xml", CP="$tags"};
    },
    set => sub {
        my $self = shift;
        carp "Can't assign to '-p3p' directly, use p3p_tags() instead";
    },
);

my %Content_Disposition = (
    get => sub {
        my ( $self, $header ) = @_;
        my $filename = $header->{-attachment};
        return qq{attachment; filename="$filename"} if $filename;
        $header->{-content_disposition};
    },
    set => sub {
        my ( $self, $header, $value ) = @_; 
        $header->{-content_disposition} = $value;
        delete $header->{-attachment} if $value;
        return;
    },
    exists => sub {
        my ( $self, $header ) = @_;
        $header->{-attachment} || $header->{-content_disposition};
    },
    delete => sub {
        my ( $self, $header ) = @_;
        my $value = defined wantarray && $self->get( 'Content-Disposition' );
        delete @{ $header }{qw/-attachment -content_disposition/};
        $value;
    },
);

my $is_fixed = sub {
    my ( $self, $header ) = @_;
    $header->{-nph} || $header->{-expires} || $header->{-cookie};
};

my %Date = (
    get => sub {
        my ( $self, $header ) = @_;
        return CGI::Util::expires() if $self->$is_fixed( $header );
        $header->{-date};
    },
    set => sub {
        my ( $self, $header, $value ) = @_;
        return carp 'The Date header is fixed' if $self->$is_fixed( $header );
        $header->{-date} = $value;
        return;
    },
    exists => sub {
        my ( $self, $header ) = @_;
        $header->{-date} || $self->$is_fixed( $header );
    },
    delete => sub {
        my ( $self, $header ) = @_;
        return carp 'The Date header is fixed' if $self->$is_fixed( $header );
        my $value = defined wantarray && $self->get( 'Date' );
        delete $header->{-date};
        $value;
    },
);

my %Set_Cookie = (
    set => sub {
        my ( $self, $header, $value ) = @_;
        delete $header->{-date} if $value;
        $header->{-cookie} = $value;
        return;
    },
);

my %Dispatcher = (
    -cookie  => \%Set_Cookie,  -content_disposition => \%Content_Disposition,
    -date    => \%Date,        -content_type        => \%Content_Type,
    -expires => \%Expires,     -p3p                 => \%P3P,
);

sub get {
    my ( $self, $field ) = @_;
    my $norm = $self->_normalize( $field );
    my $dispatch = exists $Dispatcher{$norm} && $Dispatcher{$norm}{get};
    $dispatch ? $self->$dispatch( $self->header ) : $self->header->{ $norm };
}

sub set {
    my ( $self, $field, $value ) = @_;
    my $norm = $self->_normalize( $field );
    my $dispatch = exists $Dispatcher{$norm} && $Dispatcher{$norm}{set};
    return $self->$dispatch( $self->header, $value ) if $dispatch;
    $self->header->{ $norm } = $value;
    return;
}

sub exists {
    my ( $self, $field ) = @_;
    my $norm = $self->_normalize( $field );
    my $dispatch = exists $Dispatcher{$norm} && $Dispatcher{$norm}{exists};
    $dispatch ? $self->$dispatch( $self->header ) : $self->header->{ $norm };
}

sub delete {
    my ( $self, $field ) = @_;
    my $norm = $self->_normalize( $field );
    my $dispatch = exists $Dispatcher{$norm} && $Dispatcher{$norm}{delete};
    return $self->$dispatch( $self->header ) if $dispatch;
    my $value = defined wantarray && $self->get( $field );
    delete $self->header->{ $norm };
    $value;
}

BEGIN {
    *FETCH  = \&get;    *STORE  = \&set;
    *EXISTS = \&exists; *DELETE = \&delete;
}

my %norm_of = (
    -attachment    => q{},        -charset => q{},
    -cookie        => q{},        -nph     => q{},
    -target        => q{},        -type    => q{},
    -window_target => q{-target}, -set_cookie => q{-cookie},
);

sub _normalize {
    my $class = shift;
    my $field = lc shift;

    # transliterate dashes into underscores
    $field =~ tr{-}{_};

    # add an initial dash
    $field = "-$field";

    exists $norm_of{$field} ? $norm_of{ $field } : $field;
}

my %field_name_of = (
    -attachment => 'Content-Disposition', -cookie => 'Set-Cookie',
    -p3p        => 'P3P',                 -target => 'Window-Target',
    -type       => 'Content-Type',
);

sub _denormalize {
    my ( $class, $norm ) = @_;

    unless ( exists $field_name_of{$norm} ) {
        ( my $field = $norm ) =~ s/^-//;
        $field =~ tr/_/-/;
        $field_name_of{ $norm } = ucfirst $field;
    }

    $field_name_of{ $norm };
}

1;
