package CGI::Header::Dispatcher;
use strict;
use warnings;
use Exporter 'import';
use CGI::Util qw/expires/;
use Carp qw/carp croak/;

our @EXPORT = qw( dispatch );

my %content_type = (
    get => sub {
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
        my $header = shift;
        $header->{-type} = shift;
        $header->{-charset} = q{};
        return;
    },
    exists => sub {
        my $header = shift;
        !defined $header->{-type} || $header->{-type} ne q{};
    },
    delete => sub {
        my $header = shift;
        $header->{-type} = q{};
        delete $header->{-charset};
    },
);

my %expires = (
    get => sub {
        my $header = shift;
        my $expires = $header->{-expires};
        $expires && expires( $expires );
    },
    set => sub {
        carp "Can't assign to '-expires' directly, use expires() instead";
    },
);

my %p3p = (
    get => sub {
        my $header = shift;
        my $tags = $header->{-p3p};
        $tags = join ' ', @{ $tags } if ref $tags eq 'ARRAY';
        $tags && qq{policyref="/w3c/p3p.xml", CP="$tags"};
    },
    set => sub {
        carp "Can't assign to '-p3p' directly, use p3p_tags() instead";
    },
);

my %content_disposition = (
    get => sub {
        my $header = shift;
        my $filename = $header->{-attachment};
        return qq{attachment; filename="$filename"} if $filename;
        $header->{-content_disposition};
    },
    set => sub {
        my ( $header, $value ) = @_;
        $header->{-content_disposition} = $value;
        delete $header->{-attachment} if $value;
        return;
    },
    exists => sub {
        my $header = shift;
        $header->{-attachment} || $header->{-content_disposition};
    },
    delete => sub {
        my $header = shift;
        delete $header->{-attachment};
    },
);

my $is_fixed = sub {
    my $header = shift;
    $header->{-nph} || $header->{-expires} || $header->{-cookie};
};

my %date = (
    get => sub {
        my $header = shift;
        return expires() if $is_fixed->( $header );
        $header->{-date};
    },
    set => sub {
        my ( $header, $value ) = @_;
        return carp 'The Date header is fixed' if $is_fixed->( $header );
        $header->{-date} = $value;
        return;
    },
    exists => sub {
        my $header = shift;
        $header->{-date} || $is_fixed->( $header );
    },
    delete => sub {
        my $header = shift;
        carp 'The Date header is fixed' if $is_fixed->( $header );
    },
);

my %cookie = (
    set => sub {
        my ( $header, $value ) = @_;
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
        my ( $self, $field, $norm, $handler ) = @_;
        $handler ? $handler->( $self->header ) : $self->header->{ $norm };
    },
    set => sub {
        my ( $self, $field, $norm, $handler, $value ) = @_;
        return $handler->( $self->header, $value ) if $handler;
        $self->header->{ $norm } = $value;
        return;
    },
    exists => sub {
        my ( $self, $field, $norm, $handler ) = @_;
        $handler ? $handler->( $self->header ) : $self->header->{ $norm };
    },
    delete => sub {
        my ( $self, $field, $norm, $handler ) = @_;
        my $value = defined wantarray && $self->get( $field );
        $handler->( $self->header ) if $handler;
        delete $self->header->{ $norm };
        $value;
    },
);

sub dispatch {
    my $self     = shift;
    my $operator = shift;
    my $field    = shift;
    my $norm     = _normalize( $field );

    return if !$operator or !$norm;

    if ( my $dispatch = $Dispatcher{$operator} ) {
        my $handler = exists $Handler{$norm} && $Handler{$norm}{$operator};
        return $self->$dispatch( $field, $norm, $handler, @_ );
    }

    croak "Unknown operator '$operator' passed to dispatch()";
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

1;
