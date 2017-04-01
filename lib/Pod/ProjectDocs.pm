package Pod::ProjectDocs;

use strict;
use warnings;

use base qw/Class::Accessor::Fast/;

use File::Spec;
use JSON;
use Pod::ProjectDocs::DocManager;
use Pod::ProjectDocs::Config;
use Pod::ProjectDocs::Parser;
use Pod::ProjectDocs::CSS;
use Pod::ProjectDocs::ArrowImage;
use Pod::ProjectDocs::IndexPage;

__PACKAGE__->mk_accessors(qw/managers components config/);

sub new {
    my ($class, @args) = @_;
    my $self  = bless { }, $class;
    $self->_init(@args);
    return $self;
}

sub _init {
    my($self, %args) = @_;

    # set absolute path to 'outroot'
    $args{outroot} ||= File::Spec->curdir;
    $args{outroot} = File::Spec->rel2abs($args{outroot}, File::Spec->curdir)
        unless File::Spec->file_name_is_absolute( $args{outroot} );

    # set absolute path to 'libroot'
    $args{libroot} ||= File::Spec->curdir;
    $args{libroot} = [ $args{libroot} ] unless ref $args{libroot};
    $args{libroot} = [ map {
        File::Spec->file_name_is_absolute($_) ? $_
        : File::Spec->rel2abs($_, File::Spec->curdir)
    } @{ $args{libroot} } ];

    # check mtime by default, but can be overridden
    $args{forcegen} ||= 0;

    $args{except} ||= [];
    $args{except} = [ $args{except} ] unless ref $args{except};

    $self->config( Pod::ProjectDocs::Config->new(%args) );

    $self->_setup_components();
    $self->_setup_managers();
    return;
}

sub _setup_components {
    my $self = shift;
    $self->components( {} );
    $self->components->{css}
        = Pod::ProjectDocs::CSS->new( config => $self->config );
    $self->components->{arrow}
        = Pod::ProjectDocs::ArrowImage->new( config => $self->config );
    return;
}

sub _setup_managers {
    my $self = shift;
    $self->reset_managers();
    $self->add_manager('Perl Manuals', 'pod', Pod::ProjectDocs::Parser->new);
    $self->add_manager('Perl Modules', 'pm',  Pod::ProjectDocs::Parser->new);
    $self->add_manager('Trigger Scripts', ['cgi', 'pl'], Pod::ProjectDocs::Parser->new);
    return;
}

sub reset_managers {
    my $self = shift;
    $self->managers( [] );
    return;
}

sub add_manager {
    my($self, $desc, $suffix, $parser) = @_;
    push @{ $self->managers },
        Pod::ProjectDocs::DocManager->new(
            config => $self->config,
            desc   => $desc,
            suffix => $suffix,
            parser => $parser,
        );
    return;
}

sub gen {
    my $self = shift;

    foreach my $comp_key ( keys %{ $self->components } ) {
        my $comp = $self->components->{$comp_key};
        $comp->publish();
    }

    my %local_modules;

    foreach my $manager ( @{ $self->managers } ) {
        next if $manager->desc !~ /Perl Modules/;
        my $ite = $manager->doc_iterator();
        while ( my $doc = $ite->next_document() ) {
            my $name = $doc->name;
            my $path = $doc->get_output_path;
            if ($manager->desc eq 'Perl Modules') {
                $local_modules{$name} = $path;
            }
        }
    }

    foreach my $manager ( @{ $self->managers } ) {

        $manager->parser->local_modules( \%local_modules );

        my $ite = $manager->doc_iterator();
        while ( my $doc = $ite->next_document() ) {
            my $html = $manager->parser->gen_html(
                doc        => $doc,
                desc       => $manager->desc,
                components => $self->components,
            );

            if ( $self->config->forcegen || $doc->is_modified ) {
                $doc->copy_src();
                $doc->publish($html);
            }
        }
    }

    my $index_page = Pod::ProjectDocs::IndexPage->new(
        config     => $self->config,
        components => $self->components,
        json       => $self->get_managers_json,
    );
    $index_page->publish();
    return;
}

sub get_managers_json {
    my $self    = shift;
    my $js      = JSON->new;
    my $records = [];
    foreach my $manager ( @{ $self->managers } ) {
        my $record = {
            desc    => $manager->desc,
            records => [],
        };
        foreach my $doc ( @{ $manager->docs } ) {
            push @{ $record->{records} }, {
                path  => $doc->relpath,
                name  => $doc->name,
                title => $doc->title,
            };
        }
        if ( scalar( @{ $record->{records} } ) > 0 ) {
            push @$records, $record;
        }
    }
    # Use "canonical" to generate stable structures that can be added
    #   to version control systems without changing all the time.
    return $js->canonical()->encode($records);
}

sub _croak {
    my($self, $msg) = @_;
    require Carp;
    Carp::croak($msg);
    return;
}

1;
__END__

=head1 NAME

Pod::ProjectDocs - generates CPAN like project documents from pod.

=head1 SYNOPSIS

    #!/usr/bin/perl -w
    use strict;
    use Pod::ProjectDocs;
    my $pd = Pod::ProjectDocs->new(
        libroot => '/your/project/lib/root',
        outroot => '/output/directory',
        title   => 'ProjectName',
    );
    $pd->gen();

    #or use pod2projdocs on your shell
    pod2projdocs -out /output/directory -lib /your/project/lib/root

=head1 DESCRIPTION

This module allows you to generates CPAN like pod pages from your modules
for your projects. It also creates an optional index page.

=head1 OPTIONS

=over 4

=item outroot

output directory for the generated documentation.

=item libroot

your library's (source code) root directory.

You can set single path by string, or multiple by arrayref.

    my $pd = Pod::ProjectDocs->new(
        outroot => '/path/to/output/directory',
        libroot => '/path/to/lib'
    );

or

    my $pd = Pod::ProjectDocs->new(
        outroot => '/path/to/output/directory',
        libroot => ['/path/to/lib1', '/path/to/lib2'],
    );

=item title

your project's name.

=item desc

description for your project.

=item index

whether you want to create an index for all generated pages (0 or 1).

=item lang

set this language as xml:lang (default 'en')

=item forcegen

whether you want to generate HTML document even if source files are not updated (default is 0).

=item except

the files matches this regex won't be parsed.

  Pod::ProjectDocs->new(
    except => qr/^specific_dir\//,
    ...other parameters
  );

  Pod::ProjectDocs->new(
    except => [qr/^specific_dir1\//, qr/^specific_dir2\//],
    ...other parameters
  );

=back

=head1 pod2projdocs

You can use the command line script L<pod2projdocs> to generate your documentation
without creating a custom perl script.

    pod2projdocs -help

=head1 SEE ALSO

L<Pod::Parser>

=head1 AUTHOR

Lyo Kato E<lt>lyo.kato@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright(C) 2005 by Lyo Kato

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
