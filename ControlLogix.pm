#!/usr/bin/perl

package ControlLogix;
@ISA = ();
our $AUTOLOAD;

use strict;
use Carp qw(cluck);
use ControlLogixTag;

sub new{
   my ($class, %args) = @_;

   my %hash;

   # Populate the arguments into the hash.
   foreach my $arg (keys %args) {
      $hash{$arg} = $args{$arg};
   }

   # DO NOT DO WORK IN THE CONSTRUCTOR!
   #   Do work in methods/subroutines so they can be tested.

   # build class data structure
   my $self = \%hash;

   bless $self, $class;
   $self->load_session_array();
   return $self;
}


sub load_session_array {
   my $self = shift;
   
   my @session;
   $session[0] = 0x65;  # register session (2)
   $session[1] = 0x00;
   $session[2] = 0x04; # length in bytes of data portion (2)
   $session[3] = 0x00;
   $session[4] = 0x00; # session id (4)
   $session[5] = 0x00;
   $session[6] = 0x00;
   $session[7] = 0x00;
   $session[8] = 0x00; # status (4)
   $session[9] = 0x00;
   $session[10] = 0x00;
   $session[11] = 0x00;
   $session[12] = 0x00; # sender context (8 - array of octet)
   $session[13] = 0x00;
   $session[14] = 0x00;
   $session[15] = 0x00;
   $session[16] = 0x00;
   $session[17] = 0x00;
   $session[18] = 0x00;
   $session[19] = 0x00;
   $session[20] = 0x00; # options flags (4)
   $session[21] = 0x00;
   $session[22] = 0x00;
   $session[23] = 0x00;
   $session[24] = 0x01; # encapsulated data array
   $session[25] = 0x00;
   $session[26] = 0x00;
   $session[27] = 0x00;

   $self->{session} = \@session;
}

sub tag{
   my $self = shift;
   my $args = shift;

   if (exists $args->{name} && exists $args->{type}) {
      sleep 0;
   }

   my $obj = ControlLogixTag->new(
                parent => $self,
                name   => $args->{name}, 
                type   => $args->{type},
   );

   return $obj;
}


sub read_string_tag{
   # This method is a simple interface for reading of PLC String Tags
   my $self = shift;
   my $tag = shift;   # Name of tag

   # Note a String Tag is just a tag structure of:
   #    .LEN   --> a DINT indicating number of characters in the string
   #    .DATA  --> array of SINTs (up to 82) of characters
   #
   my $string_LEN_tag = $tag .'.LEN';
   my $string_length_obj = $self->tag(
                     {
                        name => $string_LEN_tag,
                        type => 'DINT',
                     }
   );
   my $string_length = $string_length_obj->read();
 
   my $string_DATA_tag = $tag .'.DATA';
   my $string_data_obj = $self->tag(
                     {
                        name => $string_DATA_tag,
                        type => 'SINT',
                     }
   );
   my @sints = $string_data_obj->read($string_length);
   my @chars = map(chr, @sints);
   my $string = join '',@chars;
   return $string;
}

sub write_string_tag{
   # This method is a simple interface for reading of PLC String Tags
   my $self = shift;
   my $tag = shift;   # Name of tag
   my $string = shift;

   # Note a String Tag is just a tag structure of:
   #    .LEN   --> a DINT indicating number of characters in the string
   #    .DATA  --> array of SINTs (up to 82) of characters
   #
   my $length = length $string;
   my $string_LEN_tag = $tag .'.LEN';
   my $string_length_obj = $self->tag(
                     {
                        name => $string_LEN_tag,
                        type => 'DINT',
                     }
   );
   $string_length_obj->write($length);
 
   my $string_DATA_tag = $tag .'.DATA';
   my $string_data_obj = $self->tag(
                     {
                        name => $string_DATA_tag,
                        type => 'SINT',
                     }
   );
   my @chars = split '', $string;
   my @sints = map(ord, @chars);
   $string_data_obj->write(\@sints);
}



sub Log{
   my $self = shift;
   my $msg = shift;

   my $program_name = $0;
   if (exists $self->{log_routine}) {
      my $log_routine = $self->{log_routine};
      no strict;
      &log_routine($msg);
   }
   elsif (open my $F, ">>$program_name.log") {
      print $F scalar localtime;
      print $F " $msg";
      if ($msg =! m/\n$/) {
         print $F "\n";
      }
      close $F;
   }
}

sub AUTOLOAD{
   my $self = shift;    
   my $value = shift;

   # This a autoload method catches any called method
   # that is not defined. 

   print "AUTOLOAD called for '$self' '$value'\n";   

}

sub Error{
   my $msg = shift;

   if ($msg !~ m/\n$/) {
      $msg .= "\n";
   }
   # print STDERR $msg;
   cluck $msg;
}


sub DESTROY{

   my $self = shift;

   # Do some clean just before this object is destroyed


}

return 1;

__END__

=head1 NAME

ControlLogix - Read/Write from/to Allen Bradley PLCs via TCP / ethernet.

=head1 VERSION

This documentation refers to ControlLogix version 0.0.1.

=head1 SYNOPSIS

   use ControlLogix;
   
   my $obj = ControlLogix->new(
      plc_ip_addr => '192.168.0.150';
      my_ip_addr => '192.168.0.100', # optional
   );

   # Read/Writ to a PLC DINT tag. 
   my $counter_tag = obj->tag(
      name => 'Counter',
      type => 'DINT',
   );
   my $count = $counter_tag->read();
   $counter_tag->write(100);      # Set it to 100

   # Read/Write a STRING from a PLC string array
	my $tag = 'TestString[2]';
   my $string = $plc->read_string_tag($tag);
   print "String read test for $tag result is: '$string'\n";
   $plc->write_string_tag($tag,'Another two');
   $string = $plc->read_string_tag($tag);
   print "String read test for $tag result is: '$string'\n";

   # Read a ten SINT values from a PLC SINT array
   $tag_name = 'TempSTRING.DATA';
   my $sint_arr = $plc->tag(
                     {
                        name => $tag_name,
                        type => 'SINT',
                     }
   );
   my @data = $sint_arr->read(10);
   print $tag_name . " = '@data'\n";


=head1 DESCRIPTION 
	This module allows reading and writing to Allen Bradley ControlLogix PLCs via
	the Common Industry Protocol (CIP -- previously Control and Information Protocol).
	Note only works on controller tags.
	
	
=head1 SUBROUTINES/METHODS

   new  --create object for communicating with a specific PLC
		my $plc = ControlLogix->new(
			plc_ip_addr => '192.0.0.200',
		);
  

   read_string_tag - easier way to read a string tag 
      rather than using low level queries to tag members.
		my $string = $plc->read_string_tag('TempSTRING');
		  
   tag - creates a tag object for reading and writing
		my $dint = $plc->tag(
            {
                name => 'test_DINT',
                type => 'DINT',
            }
        );
      my $data = $dint->read();     # Read one DINT from a DINT or DINT array tag.
		my @data = $dint->read(4);    # Read four DINTs from a DINT array tag.
      $dint->write(42);             # Write 42 to DINT tag called 'test_DINT'. 
   
   write_string_tag - easier way to write a string tag 
      rather than using low level queries to tag members.
		my $string = $plc->write_string_tag('TempSTRING','Killroy was here');
   
   
=head1 DEPENDENCIES

   Carp
   ContolLogixTag.pm

=head1 AUTHOR

<Dan DeBrito> (<ddebrito@gmail.com>)
=head1 COPYRIGHT

Copyright (c) 2015-2016 by Dan DeBrito. All rights reserved.

=head1 LICENSE

This package is free software; you can redistribute it and/or
modify it under the same terms as Perl itself, i.e., under the
terms of the "Artistic License" or the "GNU General Public License".

Please refer to the files "Artistic.txt", "GNU_GPL.txt" and
"GNU_LGPL.txt" in this distribution for details!

=head1 DISCLAIMER

This package is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the "GNU General Public License" for more details.


=head1 LICENCE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See <perlartistic>.  This program is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
   
=head1 USAGE

   use ControlLogix;
   
   my $obj = ControlLogix->new(
      plc_ip_addr => '192.168.0.150';
      my_ip_addr => '192.168.0.100', # optional
   );

   # Read/Writ to a PLC DINT tag. 
   my $counter_tag = obj->tag(
      name => 'Counter',
      type => 'DINT',
   );
   my $count = $counter_tag->read();
   $counter_tag->write(100);      # Set it to 100

   # Read/Write a STRING from a PLC string array
	my $tag = 'TestString[2]';
   my $string = $plc->read_string_tag($tag);
   print "String read test for $tag result is: '$string'\n";
   $plc->write_string_tag($tag,'Another two');
   $string = $plc->read_string_tag($tag);
   print "String read test for $tag result is: '$string'\n";

   # Read a ten SINT values from a PLC SINT array
   $tag_name = 'TempSTRING.DATA';
   my $sint_arr = $plc->tag(
                     {
                        name => $tag_name,
                        type => 'SINT',
                     }
   );
   my @data = $sint_arr->read(10);
   print $tag_name . " = '@data'\n";


