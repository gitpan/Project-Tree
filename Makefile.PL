# $Id: Makefile.PL,v 1.3 1999/02/21 11:31:41 joern Exp $

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Project::Tree',
    'PREREQ_PM' => {
			'Gtk' => 0.5,
			'Data::Dumper' => 0
		},
    'EXE_FILES' => [qw(ptree)],
    'VERSION_FROM' => 'Tree.pm', # finds $VERSION
);
