package CGI::Header;
use 5.008_009;
use strict;
use warnings;
use overload '%{}' => 'as_hashref', q{""} => 'as_string', fallback => 1;
use parent 'CGI::Header::Entity';
use Carp qw/carp croak/;
use Scalar::Util qw/refaddr/;

our $VERSION = '0.01';

my %header_of;

sub new {
    my $class = shift;
    my $header = ref $_[0] eq 'HASH' ? shift : { @_ };
    $class->SUPER::new( $header );
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

sub as_hashref {
    my $self = shift;
    my $this = refaddr $self;

    unless ( exists $header_of{$this} ) {
        tie my %header => 'CGI::Header::Entity' => $self->header;
        $header_of{ $this } = \%header;
    }

    $header_of{ $this };
}

sub content_type {
    my $self = shift;

    return $self->STORE( 'Content-Type' => shift ) if @_;

    my ( $media_type, $rest ) = do {
        my $content_type = $self->FETCH( 'Content-Type' );
        return q{} unless defined $content_type;
        split /;\s*/, $content_type, 2;
    };

    $media_type =~ s/\s+//g;
    $media_type = lc $media_type;

    wantarray ? ($media_type, $rest) : $media_type;
}

sub date {
    my ( $self, $time ) = @_;

    require HTTP::Date;

    if ( defined $time ) {
        $self->STORE( Date => HTTP::Date::time2str($time) );
    }
    elsif ( my $date = $self->FETCH('Date') ) {
        return HTTP::Date::str2time( $date );
    }

    return;
}

sub set_cookie {
    my ( $self, $name, $value ) = @_;

    require CGI::Cookie;

    my $new_cookie = CGI::Cookie->new(do {
        my %args = ref $value eq 'HASH' ? %{ $value } : ( value => $value );
        $args{name} = $name;
        \%args;
    });

    my $cookies = $self->FETCH( 'Set-Cookie' );

    if ( !$cookies ) {
        return $self->STORE( 'Set-Cookie' => [ $new_cookie ] );
    }
    elsif ( ref $cookies ne 'ARRAY' ) {
        $self->STORE( 'Set-Cookie' => $cookies = [ $cookies ] );
    }

    my $set;
    for my $cookie ( @{$cookies} ) {
        next unless ref $cookie   eq 'CGI::Cookie';
        next unless $cookie->name eq $name;
        $cookie = $new_cookie;
        $set++;
        last;
    }

    push @{ $cookies }, $new_cookie unless $set;

    return;
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
    else {
        return 200;
    }

    return;
}

sub as_string {
    my $self = shift;
    my $eol  = defined $_[0] ? shift : "\n";

    my @lines;

    if ( $self->nph ) {
        my $protocol = $ENV{SERVER_PROTOCOL}  || 'HTTP/1.0';
        my $software = $ENV{SERVER_SOFTWARE}  || 'cmdline';
        my $status   = $self->FETCH('Status') || '200 OK';
        push @lines, "$protocol $status";
        push @lines, "Server: $software";
    }

    $self->each(sub {
        my ( $field, $value ) = @_;
        my @values = ref $value eq 'ARRAY' ? @{ $value } : $value;
        push @lines, "$field: $_" for @values;
    });

    # CR escaping for values, per RFC 822
    for my $line ( @lines ) {
        $line =~ s/$eol(\s)/$1/g;
        next unless $line =~ m/$eol|\015|\012/;
        $line = substr $line, 0, 72 if length $line > 72;
        croak "Invalid header value contains a new line ",
              "not followed by whitespace: $line";
    }

    join $eol, @lines, q{};
}

sub dump {
    my $self    = shift;
    my $package = __PACKAGE__;

    $self->SUPER::dump(
        $package => {
            header => { $self->flatten },
        },
        @_,
    );
}

sub DESTROY {
    my $self = shift;
    delete $header_of{ refaddr $self };
    $self->SUPER::DESTROY;
}

1;

__END__

=head1 NAME

CGI::Header - Emulates CGI::header()

=head1 SYNOPSIS

  use CGI::Header;
  use CGI::Cookie;

  my $cookie = CGI::Cookie->new(
      -name  => 'ID',
      -value => 123456,
  );

  my $header = CGI::Header->new(
      -attachment => 'genome.jpg',
      -charset    => 'utf-8',
      -cookie     => $cookie,
      -expires    => '+3M',
      -nph        => 1,
      -p3p        => [qw/CAO DSP LAW CURa/],
      -target     => 'ResultsWindow',
      -type       => 'text/plain',
  );

  print $header->as_string;

=head1 DESCRIPTION

Accepts the same arguments as CGI::header() does.
Generates the same HTTP response headers as the subroutine does.

=head2 METHODS

=over 4

=item $header = CGI::Header->new( -type => 'text/plain', ... )

=item $value = $eader->get( $field )

=item $header->set( $field => $value )

=item $bool = $header->exists( $field )

=item $deleted = $header->delete( $field )

=item $header->clear

=item @fields = $header->field_names

=item $header->each( \&callback )

=item @headers = $header->flatten

=item $bool = $header->is_empty

=item $clone = $header->clone

=back

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistibute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
