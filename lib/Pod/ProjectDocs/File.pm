package Pod::ProjectDocs::File;

use strict;
use warnings;

# VERSION

use base qw/Class::Accessor::Fast Class::Data::Inheritable/;

use IO::File;

__PACKAGE__->mk_classdata($_) for qw/data default_name is_bin/;
__PACKAGE__->mk_accessors(qw/config name relpath/);
__PACKAGE__->is_bin(0);

sub new {
    my ($class, @args) = @_;
    my $self  = bless { }, $class;
    $self->_init(@args);
    return $self;
}

sub _init {
    my($self, %args) = @_;
    $self->config( $args{config} );
    return;
}

sub _get_data {
    my $self = shift;
    return $self->data;
}

sub publish {
    my($self, $data) = @_;
    $data ||= $self->_get_data();
    my $path = $self->get_output_path;
    my $mode = ">>";
    if ( $path =~ m/html$/ ) {
        $mode .= ':encoding(UTF-8)' ;
    }
    my $fh = IO::File->new($path, $mode) or $self->_croak(qq/Can't open $path./);
    $fh->seek(0, 0);
    $fh->truncate(0);
    $fh->print($data);
    $fh->close;
    return;
}

sub get_output_path {
    my $self = shift;
    my $outroot = $self->config->outroot;
    my $relpath = $self->relpath || $self->default_name;
    my $path = File::Spec->catfile($outroot, $relpath);
    return $path;
}

sub _croak {
    my($self, $msg) = @_;
    require Carp;
    Carp::croak($msg);
    return;
}

1;
__END__
