# $Id: Tree.pm,v 1.4 1999/02/21 11:42:22 joern Exp $

package Project::Tree;

use strict;
use vars qw($VERSION $REVISION @ISA @EXPORT);

$VERSION = '0.01';
$REVISION = '$Revision: 1.4 $';

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(
	gui
);

use Gtk;
use File::Basename;
use Data::Dumper;

my $DEBUG = 0;

sub gui {
	Gtk->init;
	
	my $pt = new Project::Tree;
	
	$pt->read_user_data ("$ENV{HOME}/.ptree");
	$pt->build_gui;

	Gtk->main;

	exit;
}

sub new {
	my $type = shift;
	
	my $self = {
		open_projects => undef,		# lref of open projects
		projects => undef,		# href of project definitions
		quick_access => undef,		# href of quick access files
	};
	
	return bless $self, $type;
}

sub read_file {
	my $self = shift;
	my ($file) = @_;
	
	open (FILE, $file) or return "";
	my $content = join ('', <FILE>);
	close FILE;
	
	return $content;
}

sub read_user_data {
	my $self = shift;
	my ($user_data_dir) = @_;
	
	my $project_dir = "$user_data_dir/projects";
	my $open_projects_file = "$user_data_dir/open_projects";
	my $qa_file = "$user_data_dir/quickaccess";
	
	$self->{fs}->{project_dir} = $project_dir;
	$self->{fs}->{open_projects_file} = $open_projects_file;
	$self->{fs}->{qa_file} = $qa_file;
	
	mkdir ($user_data_dir, 0755) if not -d $user_data_dir;
	mkdir ($project_dir, 0755) if not -d $project_dir;

	# read list of open projects

	my $PTREE_OPEN_PROJECTS_LREF = [];
	
	eval $self->read_file($open_projects_file) if -f $open_projects_file;
		
	# now read project definitions of the open projects
	# (also check if project definition is OK)
	
	my %projects;
	my @open_projects;
	
	foreach my $project (@{$PTREE_OPEN_PROJECTS_LREF}) {
		my $project_file = "$project_dir/$project";

		my $PTREE_PROJECT_DEFINITION_HREF;
		my $read_success = 1;
		if ( -f $open_projects_file ) {
			if ( not eval $self->read_file($project_file) ) {
				print "error reading $project_file: $@\n";
				$read_success = 0;
			}
		} else {
			print "project file $project_file not found\n";
			$read_success = 0;
		}

		if ( $read_success ) {
			$projects{$project} = $PTREE_PROJECT_DEFINITION_HREF;
#			print "$project_file successful read\n";
			push @open_projects, $project;
		}
	}


	# now read the quick access list
	# (with check, if file exists)
	
	my $PTREE_QUICK_ACCESS_LREF = [];
	
	eval $self->read_file($qa_file) if -f $qa_file;
	
	my @quick_access;
	foreach my $qa_href (@{$PTREE_QUICK_ACCESS_LREF}) {
		push @quick_access, $qa_href if -f $qa_href->{name};
	}
	
	$self->{open_projects} = \@open_projects;
	$self->{projects} = \%projects;
	$self->{quick_access} = \@quick_access;

	1;
}

sub save_qa_list {
	my $self = shift;
	
	my $content = Dumper($self->{quick_access});
	$content =~ s/VAR1/PTREE_QUICK_ACCESS_LREF/;

	if ( not open (FILE, "> $self->{fs}->{qa_file}") ) {
		print "can't write $self->{fs}->{qa_file}\n";
		return;
	}
	
	print FILE $content;
	close FILE;
	
	1;
}

sub build_gui {
	my $self = shift;

	# feines Fensterchen
	
	my $win = new Gtk::Window -toplevel;
	$win->set_title("ptree");
	$win->signal_connect("destroy" => \&Gtk::main_quit);
	$win->border_width(0);
	$win->set_uposition (10,10);
	$win->set_usize (250, 800);
	my $box = new Gtk::VBox (0, 0);
	$win->add($box);
	$box->show;
	
	# Menu
	
	my $box1 = new Gtk::VBox (0, 0);
	$box->pack_start ($box1, 0, 0, 0);
	$box1->show;
	
	my $factory = new Gtk::MenuFactory ('menu_bar');
	my $subfactory = new Gtk::MenuFactory ('menu_bar');
	$factory->add_subfactory($subfactory,'<Main>');
	
	my $entry = { path  =>  '<Main>/File/Exit',
#           accelerator     =>  '<alt>Q',
           widget          =>  undef,
           callback        =>  sub {Gtk->exit(0)}
        };
	 
	$factory->add_entries($entry);
	my $menubar = $subfactory->widget;
	$menubar->show;
	$box1->pack_start($menubar, 0, 1 ,0);

	# Pane
	
	my $pane = new Gtk::VPaned;
	$pane->border_width(5);
	$box->pack_start($pane, 1, 1, 0);
	$pane->show;

	# Quick Access List
	
	my $frame = new Gtk::Frame "Quick Access";
	$pane->add1 ($frame);
	$frame->show;
	
	my $qa_box = new Gtk::VBox (0, 0);
	$qa_box->border_width(5);
	$frame->add ($qa_box);
	$qa_box->show;

	my $scrolled_list = new Gtk::ScrolledWindow (undef, undef);
	$scrolled_list->set_policy ('always', 'automatic');
	$scrolled_list->set_usize(150, 100);
	$scrolled_list->show;

	my $list = new Gtk::List;
	$self->{widget}->{qa_list} = $list;
	$list->show;
	$scrolled_list->add_with_viewport($list);

	$self->create_qa_list;

	$qa_box->pack_start ($scrolled_list, 1, 1, 0);

#	$GLOBAL::qa_list = $list;
	
	# Der Tree
	
	$frame = new Gtk::Frame "Projects";
	$pane->add2 ($frame);
	$frame->show;
		
	my $box2 = new Gtk::VBox (0, 0);
	$box2->border_width(5);
	$frame->add($box2);
	$box2->show;

	my $tree = $self->create_tree;
	$box2->pack_start($tree, 1, 1, 0);
	
	$win->show;
	
	1;
}

# ----------------

sub hello {
	print "hello\n";
}


sub create_qa_list {
	my $self = shift;
	my $list = $self->{widget}->{qa_list};
	
	# first, delete all items
	
	$list->clear_items (0, 65535);
	
	# now insert all items sorted by name
	
	foreach my $qa_href (sort { $a->{name} cmp $b->{name} } @{$self->{quick_access}}) {
		my $list_item = new Gtk::ListItem(basename($qa_href->{name}));
		$list->add($list_item);
		$list_item->show;
		$list_item->set_user_data({
			name => $qa_href->{name},
			exec => $qa_href->{exec}
		});
		$list_item->signal_connect('button_press_event', \&cb_list_press);
	}

	1;
}

sub cb_list_press {
	my ($list_item, $event) = @_;
	$DEBUG and print STDERR "cb_list_press\n", Dumper (\@_), "\n";
	$DEBUG and print STDERR "user_data: ", Dumper($list_item->get_user_data), "\n\n";
	my $href = $list_item->get_user_data;
	file_action ($href);
}

sub create_tree {
	my $self = shift;
	
	my $scrolled_win = new Gtk::ScrolledWindow (undef, undef);
	$scrolled_win->set_policy ('always', 'automatic');
	$scrolled_win->set_usize(150, 200);
#	$scrolled_win->signal_connect ('button_press_event', \&cb_close_object_window);
	$scrolled_win->show;
	my $root_tree = new Gtk::Tree;
#	$root_tree->signal_connect ('button_press_event', \&cb_close_object_window);
	$root_tree->set_view_mode('item');
	$scrolled_win->add_with_viewport($root_tree);
	$root_tree->show;

	foreach my $project ( @{$self->{open_projects}} )  {
		print "reading project $project...\n";
		my $dir = $self->{projects}->{$project}->{root_dir};
		my $root_item = new_with_label Gtk::TreeItem $project;
		$root_tree->append($root_item);
		$root_item->show();
		$root_item->set_user_data({
			name => $dir,
			is_dir => 1
		});
	
		$self->mount_subtree ($project, $dir, $root_item);
	}
	
	return $scrolled_win;
}

sub mount_subtree {
	my $self = shift;
	my ($project, $dir, $parent_item) = @_;
	
	my $ldir = length($dir)+1;	# to cut prefix later
	
	# read directory entries
	
	my @entries = <$dir/*>;
	my (@dir, @file);
	
	foreach my $e (@entries) {
		my $name = substr($e, $ldir);
		push @dir, $name if -d $e and not -l $e;
		push @file, $name if -f $e;
	}
	
	# if we found files or directories, $parent_item
	# must become a subtree

	my $subtree = new Gtk::Tree;
#	if ( @dir or @file ) {
#		$parent_item->set_subtree($subtree);
#	}

	# recursive call for all subdirectories

	my $dir_added;
	foreach my $name (sort @dir) {
		my $dir_attr;
		next if not $dir_attr = $self->file_attr_for_project ("dir", $project, $name);

		my $item = new_with_label Gtk::TreeItem $name;
#		my $item = new Gtk::TreeItem;
#		my $label = new Gtk::Label ($name);
#		$item->add($label);
		
		$item->set_user_data ({
			name => "$dir/$name",
			is_dir => 1,
			self => $self
		});
		$item->show;
		$subtree->append($item);
		$self->mount_subtree($project, "$dir/$name", $item);
		$dir_added = 1;
	}
	
	# simple addition of found files

	my $file_added;
	foreach my $name (sort @file) {
		my $file_attr;
		next if not $file_attr = $self->file_attr_for_project ("file", $project, $name);

#		my $item = new Gtk::TreeItem;
#		my $label = new Gtk::Label ($name);
#		$label->set_alignment (0, 0);
#		$label->set_style ('red');
#		$label->show;
#		$item->add($label);
		my $item = new_with_label Gtk::TreeItem $name;
		$item->set_user_data ({
			name => "$dir/$name",
			exec => $self->{projects}->{$project}->{exec}->{$file_attr->{exec}},
			color => $file_attr->{color},
			self => $self
		});
		$item->signal_connect('button_press_event', \&cb_tree_click);
		$item->show;
		$subtree->append($item);
		$file_added = 1;
	}

	if ( $dir_added or $file_added ) {
		$parent_item->set_subtree($subtree);
	}
}

sub file_attr_for_project {
	my $self = shift;
	my ($type, $project, $file) = @_;
	
	# check file-inclusion
	
	my $fi_lref = $self->{projects}->{$project}->{$type."_include"};

	my $attr;
	foreach my $fi (@{$fi_lref}) {
		my $re = $fi->{re};
		$attr=$fi, last if not $re or $file =~ /$re/;
	}
	
	return if not $attr;
	
	# check file-exclusion
	
	my $fe_lref = $self->{projects}->{$project}->{$type."_exclude"};

	my $excluded;
	foreach my $re (@{$fe_lref}) {
		$excluded=1, last if $file =~ /$re/;
	}
	
	return if $excluded;
	return $attr;
}


sub cb_tree_click {
	my ($item, $event) = @_;

	$DEBUG and print STDERR Dumper($event), "\n\n";

	my $href = $item->get_user_data;
	my $name = $href->{name};

	$DEBUG and print STDERR Dumper ($href);
	
	$G::last_click_name ||= 0;
	$G::last_click_time ||= '';

	if ( $event->{button} == 1 and $G::last_click_name eq $name and
	     $event->{time} - $G::last_click_time <= 400 ) {
		$DEBUG and print STDERR "DOUBLE CLICK\n\n";
		if ( -f $name ) {
			file_action ($href);
#			system ("nc -noask $name");
		}
		$G::last_click_time = 0;
		$G::last_click_name = "";
	} else {
		$G::last_click_time = $event->{time};
		$G::last_click_name = $name;
	}
	
	
	# Rechte Maustaste Menü
	
	if ( $event->{button} == 3 ) {
		if ( $GLOBAL::object_window ) {
			$GLOBAL::object_window->destroy;
			$GLOBAL::object_window = undef;
		}
		my $win = new Gtk::Widget "Gtk::Window",
			type => -popup,
			border_width => 0;
		$win->position ( -mouse );
		$win->signal_connect ('leave_notify_event', \&cb_close_object_window);

#		$GLOBAL::object_name = $href->{name};
#		$GLOBAL::object_exec = $href->{exec};
#		$GLOBAL::object_color = $href->{color};
		
		my $box = new Gtk::VBox (0, 0);
		$win->add($box);
		$box->show;
	
		# Menu
		$GLOBAL::object_window = $win;

		my $button;
		$button = new Gtk::Button ("Quick Access");
		$button->signal_connect ('clicked', \&cb_add_to_quick_access);
		$box->pack_start($button, 1, 1, 0);
		$button->set_user_data ({
			self => $href->{self},
			object_href => {
				name => $href->{name},
				color => $href->{color},
				exec => $href->{exec}
			}
		});
		$button->show;
		
#		$button = new Gtk::Button ("Bla Foo");
#		$box->pack_start($button, 1, 1, 0);
#		$button->show;

		$win->show;
	}
	
#	print STDERR "ende cb_tree_click\n";

	1;
}


sub cb_add_to_quick_access {
	my ($item, $event) = @_;

	my $user_data = $item->get_user_data;

	$DEBUG and print STDERR "adding $user_data->{object_href}->{name} to qa_list\n";

	my $self = $user_data->{self};
	my $list = $self->{widget}->{qa_list};

	push @{$self->{quick_access}}, $user_data->{object_href};
	
	$self->create_qa_list;
	
#	my $name = basename ($user_data->{object_href}->{name});
#
#	my $list_item = new Gtk::ListItem($name);
#	$list->add($list_item);
#	$list_item->show;
#	$list_item->set_user_data({
#		object_href => $user_data->{object_href},
#		self => $self
#	});
#
#	$list_item->signal_connect('button_press_event', \&cb_list_press);


	$GLOBAL::object_window->destroy;
	$GLOBAL::object_window = undef;


	$self->save_qa_list;

	1;
}

sub cb_close_object_window {
	$DEBUG and print STDERR "cb_close_window\n";
	return if not defined $GLOBAL::object_window;
	$GLOBAL::object_window->destroy;
	$GLOBAL::object_window = undef;
	
	1;
}

sub file_action {
	my ($href) = @_;
	
	my $name = $href->{name};
	my $exec = $href->{exec};
	
	$exec = sprintf ($exec, $name);
	
	system ($exec);
}





1;

__END__

=head1 NAME

Project::Tree - graphical filesystem / project tree for software developers and webmasters

=head1 SYNOPSIS

  use Project::Tree;
  gui;

  or
  
  shell# perl -MProject::Tree -e gui

  or
  
  shell# ptree

=head1 INSTALLATION

First you have to install Kenneth Albanowski's Gtk module
(Version 0.500 or newer) and Gurusamy Sarathy's Data::Dumper.
The rest is business as usual...

 perl Makefile.PL
 make
 make test
 make install

=head1 DESCRIPTION

This module is for software developers who have to maintain a lot
of files in a software project, e.g. a website with many HTML and/or
perl embedded dynamic pages and CGI scripts.

Project::Tree is Gtk (Gimp/GNU Toolkit) based and creates a tree view
of your software projects, scanning recursevely their top level
directories using user configurable regex filters to include/exclude
files and subdirectories. The actions for the file items
(e.g. start an editor by double click) are configurable in the
same way.

The module additionally mantains a list of files for quick access.
Those files are shown in an extra alphabetically ordered list. A
single click on the list item triggers the file action.

Each project is represented by a simple identifier which will be
the top node of the tree view for this project.

=head1 CONFIGURATION

This version of Project::Tree requires a configuration directory
in the home directory of the user. This is the structure of the
directory:

	$HOME/.ptree/open_projects	list of currently open projects
	$HOME/.ptree/quickaccess	list of files for quick access
	$HOME/.ptree/projects/$PROJECT	configuration for each project

Part of this distribution is a directory called 'example-configuration'.
You will find all these files there as a starting point for your
private configuration.

All configuration files are in Data::Dumper format, so they are even
machine and human readable (Data::Dumper is a great tool for this purpose).

This release of Project::Tree has no GUI for editing its configuration
files. So you have to set them up by hand (this will change in future
releases). Only the quickaccess file is actually generated by the program,
but this version has no GUI function to remove items from the quickaccess list,
so you have to do this by hand (or add this functionality and send me
the patch ;)

=head2 open_projects

This file contains the following definition of currently open projects.

	$PTREE_OPEN_PROJECTS_LREF = [
		'project1', .., 'projectN'
	];

This is a simple list of the project identifiers.

=head2 quickaccess

This file lists the items of the quick access list.

	$PTREE_QUICK_ACCESS_LREF = [
	  {
	    'name'  => '/full/filename',	# path to file
	    'exec'  => 'nc -noask %s',		# file action
	    'color' => 'black'			# item color
	  },
	  ...
	];

=head2 projects/$PROJECT

This is for project specific configuration. The file has the same
name as the project and must be present for each open project.

	$PTREE_PROJECT_DEFINITION_HREF = {

	    desc => 'CGI Perl Preprocessor',		# description
	    root_dir => '/home/joern/projects/CIPP',	# root path

            dir_include => [	# list of regexs for dir inclusion
	        undef		# undef means "include all"
	    ],

	    dir_exclude => [	# list of regexs for dir exclusion
	        'CVS$',		# undef means "exclude nothing"
		...
	    ],

	    file_include => [
	        {
	            re => '\\.(cipp|pl|pm)$',	# regex for file incl.
	            color => 'red',		# color of this files
	            exec => 'nc'		# action of this files
		    				# (defined below)
	        },
	        {
	            re => undef,		# undef = all files
	            color => 'black',		# color
	            exec => 'nc'		# action (defined below)
	        },
		...

	    ],

	    file_exclude => [
	        '.bck$',		# regex for file exclusion
	        '.pdf$',
		...
	    ],

	    exec => {			# definition of file actions
	        nc => 'nc -noask %s'	# system call for actions 'nc'
	    }
	};

The include regexes are computed before the exclude regexes. So the
set of included objects will be reduced by the exclude filters.

=head1 BUGS / TODO

This version of the module is based on my first Gtk hack. So the
design is slightly messed up (e.g. use of  global variables at
some points). I want to clean up this in future
releases. My main concern is to realize a pure object oriented
interface which lets you inherit from this class to add extra
funtionality easily.

I release this software at this time to evaluate if such a thing
is of interest for the public. For me this tool is very interesting,
because I want to pick up my files in a second instead of crawling
by hand through my filesystems for hours.

So I'm very happy about every response of everyone who either
downloaded or even use this module. Don't hesitate to send me an email!

=head1 THANKS TO

Kenneth Albanowski for his great job: the Gtk module!

=head1 AUTHOR

Joern Reder, joern@dimedis.de

=head1 COPYRIGHT

Copyright 1999 Joern Reder, All Rights Reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1), Gtk (3pm).

=cut
