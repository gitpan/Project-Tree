# $Id: Makefile.PL,v 1.3 1999/02/21 11:31:41 joern Exp $

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'Project::Tree',
    'PREREQ_PM' => {
			'Gtk' => 0.5,
			'Data::Dumper' => 0
		},
    'EXE_FILES' => [qw(ptree)],
    'VERSION_FROM' => 'Tree.pm',
    'dist' => {
    	COMPRESS => 'gzip',
	SUFFIX => 'gz'
    }
);
