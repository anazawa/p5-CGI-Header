package CGI::Header::Dispatcher;
use strict;
use warnings;
use Exporter 'import';
use CGI::Util qw//;
use Carp qw/carp croak/;
use List::Util qw/first/;

our @EXPORT = qw( dispatch attachment nph p3p_tags expires );

my %content_type = (
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
        $header->{-type} = q{};
        delete $header->{-charset};
    },
);

my %expires = (
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

my %p3p = (
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

my %content_disposition = (
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
        delete $header->{-attachment};
    },
);

my $is_fixed = sub {
    my ( $self, $header ) = @_;
    $header->{-nph} || $header->{-expires} || $header->{-cookie};
};

my %date = (
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
        carp 'The Date header is fixed' if $self->$is_fixed( $header );
    },
);

my %cookie = (
    set => sub {
        my ( $self, $header, $value ) = @_;
        delete $header->{-date} if $value;
        $header->{-cookie} = $value;
        return;
    },
);

my %Handler = (
    -cookie  => \%cookie,  -content_disposition => \%content_disposition,
    -date    => \%date,    -content_type        => \%content_type,
    -expires => \%expires, -p3p                 => \%p3p,
);

my %Dispatcher = (
    get => sub {
        my ( $self, $header, $field, $norm, $handle ) = @_;
        $handle ? $self->$handle( $header ) : $norm && $header->{ $norm };
    },
    set => sub {
        my ( $self, $header, $field, $norm, $handle, $value ) = @_;
        return $self->$handle( $header, $value ) if $handle;
        $header->{ $norm } = $value if $norm;
        return;
    },
    exists => sub {
        my ( $self, $header, $field, $norm, $handle ) = @_;
        $handle ? $self->$handle( $header ) : $norm && $header->{ $norm };
    },
    delete => sub {
        my ( $self, $header, $field, $norm, $handle ) = @_;
        my $value = defined wantarray && dispatch( $self, 'get', $field );
        $self->$handle( $header ) if $handle;
        delete $header->{ $norm } if $norm;
        $value;
    },
    scalar => sub {
        my ( $self, $header ) = @_;
        !defined $header->{-type} || first { $_ } values %{ $header };
    },
    clear => sub {
        my ( $self, $header ) = @_;
        %{ $header } = ( -type => q{} );
        return;
    },
    keys => sub {
        my $self   = shift;
        my $header = shift;
        my %header = %{ $header }; # copy

        my @fields;

        push @fields, 'Status'        if delete $header{-status};
        push @fields, 'Window-Target' if delete $header{-target};
        push @fields, 'P3P'           if delete $header{-p3p};

        push @fields, 'Set-Cookie' if my $cookie  = delete $header{-cookie};
        push @fields, 'Expires'    if my $expires = delete $header{-expires};
        push @fields, 'Date' if delete $header{-nph} or $cookie or $expires;

        push @fields, 'Content-Disposition' if delete $header{-attachment};

        my $type = delete @header{ '-charset', '-type' };

        # not ordered
        while ( my ($norm, $value) = each %header ) {
            push @fields, _denormalize( $norm ) if $value;
        }

        push @fields, 'Content-Type' if !defined $type or $type ne q{};

        @fields,
    },
);

sub dispatch {
    my $self     = shift;
    my $operator = shift;
    my $field    = shift;
    my $norm     = $field && _normalize( $field );
    my $header   = $self->header;

    return unless $operator;

    if ( my $dispatch = $Dispatcher{$operator} ) {
        my $handle = $norm && $Handler{ $norm }{ $operator };
        return $self->$dispatch( $header, $field, $norm, $handle, @_ );
    }

    croak "Unknown operator '$operator' passed to dispatch()";
}

sub attachment {
    my $self   = shift;
    my $header = $self->header;

    if ( @_ ) {
        my $filename = shift;
        delete $header->{-content_disposition} if $filename;
        $header->{-attachment} = $filename;
        return;
    }

    $header->{-attachment};
}

sub nph {
    my $self   = shift;
    my $header = $self->header;
    
    if ( @_ ) {
        my $nph = shift;
        delete $header->{-date} if $nph;
        $header->{-nph} = $nph;
        return;
    }

    $header->{-nph};
}

sub p3p_tags {
    my $self   = shift;
    my $header = $self->header;

    if ( @_ ) {
        $header->{-p3p} = @_ > 1 ? [ @_ ] : shift;
    }
    elsif ( my $tags = $header->{-p3p} ) {
        my @tags = ref $tags eq 'ARRAY' ? @{ $tags } : split ' ', $tags;
        return wantarray ? @tags : $tags[0];
    }

    return;
}

sub expires {
    my $self   = shift;
    my $header = $self->header;

    if ( @_ ) {
        my $expires = shift;
        delete $header->{-date} if $expires;
        $header->{-expires} = $expires;
        return;
    }

    $header->{-expires};
}

my %norm_of = (
    -attachment    => q{},        -charset => q{},
    -cookie        => q{},        -nph     => q{},
    -target        => q{},        -type    => q{},
    -window_target => q{-target}, -set_cookie => q{-cookie},
);

sub _normalize {
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
    my $norm = shift;

    unless ( exists $field_name_of{$norm} ) {
        ( my $field = $norm ) =~ s/^-//;
        $field =~ tr/_/-/;
        $field_name_of{ $norm } = ucfirst $field;
    }

    $field_name_of{ $norm };
}

1;
