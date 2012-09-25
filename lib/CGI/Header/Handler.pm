package CGI::Header::Handler;
use strict;
use warnings;
use Exporter 'import';
use List::Util qw/first/;
use CGI::Util qw/expires/;
use HTTP::Date qw/time2str str2time/;
use Carp qw/carp/;

our @EXPORT_OK = qw( get_handler );

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
        delete $header->{-charset};
        $header->{-type} = q{};
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
        my $p3p = $header->{-p3p};
        my $tags = ref $p3p eq 'ARRAY' ? join ' ', @{ $p3p } : $p3p;
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

my %Date = (
    get => sub {
        my $header = shift;
        my $is_fixed = first { $header->{$_} } qw(-nph -expires -cookie);
        return time2str( time ) if $is_fixed;
        $header->{-date};
    },
    set => sub {
        my ( $header, $value ) = @_;
        my $is_fixed = first { $header->{$_} } qw(-nph -expires -cookie);
        return carp 'The Date header is fixed' if $is_fixed;
        $header->{-date} = $value;
    },
    exists => sub {
        my $header = shift;
        $header->{-date} || first { $header->{$_} } qw(-nph -expires -cookie);
    },
    delete => sub {
        my $header = shift;
        my $is_fixed = first { $header->{$_} } qw(-nph -expires -cookie);
        return carp 'The Date header is fixed' if $is_fixed;
    },
);

my %Set_Cookie = (
    get => sub { shift->{-cookie} },
    set => sub {
        my ( $header, $value ) = @_;
        delete $header->{-date};
        $header->{-cookie} = $value;
    },
    exists => sub { shift->{-cookie} },
    delete => sub { delete shift->{-cookie} },
);

my %Handler = (
    -content_disposition => \%Content_Disposition,
    -content_type        => \%Content_Type,
    -set_cookie          => \%Set_Cookie,
    -date                => \%Date,
    -expires             => \%Expires,
    -p3p                 => \%P3P,
);

sub get_handler {
    my ( $norm, $operator ) = @_;
    exists $Handler{ $norm } && $Handler{ $norm }{ $operator };
}

1;
