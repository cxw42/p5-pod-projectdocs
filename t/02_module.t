use strict;
use warnings;
use utf8;

use FindBin;
use Test::More 'no_plan';
use File::Path qw(  remove_tree );

use lib '../lib';
use Pod::ProjectDocs;

$Pod::ProjectDocs::Parser::METHOD_REGEXP = qr/^(?:[^=]*=)?\s*(\w+)(?:\(.+\))?/;

Pod::ProjectDocs->new(
    outroot => "$FindBin::Bin/02_module_output",
    libroot => "$FindBin::Bin/sample/lib2",
    forcegen => 1,
)->gen;

# using XML::XPath might be better
open my $fh, "$FindBin::Bin/02_module_output/Module.pm.html";
my $html = join '', <$fh>;
close $fh;

like $html, qr!# foo foo foo!;
like $html, qr!# bar bar bar!;
like $html, qr!>\$foo = foo\(\@_\)<!s;
like $html, qr!>bar<!;

remove_tree( "$FindBin::Bin/02_module_output" );
