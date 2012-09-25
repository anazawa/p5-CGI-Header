package CGI::Header::Dispatcher;
use strict;
use warnings;
use Exporter 'import';
use List::Util qw/first/;
use CGI::Util qw/expires/;
use HTTP::Date qw/time2str str2time/;
use Carp qw/carp croak/;

our @EXPORT = qw( dispatch );

my %Content_Type = (
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
        my ( $header, $value ) = @_;
        $header->{-type} = $value;
        $header->{-charset} = q{};
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

my %Expires = (
    get => sub {
        my $header = shift;
        my $expires = $header->{-expires};
        $expires && expires( $expires );
    },
    set => sub {
        carp "Can't assign to '-expires' directly, use accessors instead";
    },
);

my %P3P = (
    get => sub {
        my $header = shift;
        my $tags = $header->{-p3p};
        $tags = join ' ', @{ $tags } if ref $tags eq 'ARRAY';
        $tags && qq{policyref="/w3c/p3p.xml", CP="$tags"};
    },
    set => sub {
        carp "Can't assign to '-p3p' directly, use accessors instead";
    },
);

my %Content_Disposition = (
    get => sub {
        my $header = shift;
        my $filename = $header->{-attachment};
        return qq{attachment; filename="$filename"} if $filename;
        $header->{-content_disposition};
    },
    set => sub {
        my ( $header, $value ) = @_;
        delete $header->{-attachment};
        $header->{-content_disposition} = $value;
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

my %Date = (
    get => sub {
        my $header = shift;
        return time2str( time ) if $is_fixed->( $header );
        $header->{-date};
    },
    set => sub {
        my ( $header, $value ) = @_;
        return carp 'The Date header is fixed' if $is_fixed->( $header );
        $header->{-date} = $value;
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

my %Set_Cookie = (
    set => sub {
        my ( $header, $value ) = @_;
        delete $header->{-date};
        $header->{-cookie} = $value;
    },
);

my %Handler = (
    -content_disposition => \%Content_Disposition,
    -content_type        => \%Content_Type,
    -cookie              => \%Set_Cookie,
    -date                => \%Date,
    -expires             => \%Expires,
    -p3p                 => \%P3P,
);

sub dispatch {
    my $self     = shift;
    my $operator = shift;
    my $field    = shift;
    my $norm     = _normalize( $field );
    my $header   = $self->header;

    return if !$operator or !$norm;

    my $handler = exists $Handler{ $norm } && $Handler{ $norm }{ $operator };

    if ( $operator eq 'get' ) {
        return $handler ? $handler->( $header ) : $header->{ $norm };
    }
    elsif ( $operator eq 'set' ) {
        my $value = shift;
        $handler->( $header, $value ) if $handler;
        $header->{ $norm } = $value unless $handler;
    }
    elsif ( $operator eq 'exists' ) {
        return $handler ? $handler->( $header ) : $header->{ $norm };
    }
    elsif ( $operator eq 'delete' ) {
        my $value = defined wantarray && $self->get( $field );
        $handler->( $header ) if $handler;
        delete $header->{ $norm };
        return $value;
    }
    else {
        croak "Unknown operator '$operator' passed to dispatch()";
    }

    return;
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
