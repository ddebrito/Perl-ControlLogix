#!/usr/bin/perl

package ControlLogixTag;
@ISA = ();
our $AUTOLOAD;

use strict;
use Carp qw(cluck);
use IO::Socket::INET;

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
   return $self;
}

sub get_service_request_array{
   my $self = shift;

   my @arr = ();
   # arr[0-1]
   push @arr, 0x6f; # SendRRData (2)
   push @arr, 0x00;
   
   # arr[2-3]
   push @arr, 0x00; # Place holder for length of data structure from arr[24] to arr[end]  (2 bytes)
   push @arr, 0x00;

   # arr[4]  session handle (4) (gets updated by event handler)
   push @arr, $self->{session_aref}->[0];
   push @arr, $self->{session_aref}->[1];
   push @arr, $self->{session_aref}->[2];
   push @arr, $self->{session_aref}->[3];
   
   # arr[8]  # status (4)
   $arr[8] = 0x00; # status (4)
   $arr[9] = 0x00;
   $arr[10] = 0x00;
   $arr[11] = 0x00;
   $arr[12] = 0x01; # arbitrary sender context (8)
   $arr[13] = 0x02;
   $arr[14] = 0x03;
   $arr[15] = 0x04;
   $arr[16] = 0x05;
   $arr[17] = 0x06;
   $arr[18] = 0x07;
   $arr[19] = 0x08;
   $arr[20] = 0x00; # options (4)
   $arr[21] = 0x00;
   $arr[22] = 0x00;
   $arr[23] = 0x00;

   $arr[24] = 0x00; # start of encapsulated data. Interface handle - CIP (2)
   $arr[25] = 0x00;
   $arr[26] = 0x00;
   $arr[27] = 0x00;
   $arr[28] = 0x05; # timeout in seconds (2)
   $arr[29] = 0x00;
   $arr[30] = 0x02; # item count (2)
   $arr[31] = 0x00;
   $arr[32] = 0x00; # null address item (2)
   $arr[33] = 0x00;
   $arr[34] = 0x00; # length (2)
   $arr[35] = 0x00;
   $arr[36] = 0xb2; # unconnected data item (2)
   $arr[37] = 0x00;
   $arr[38] = 0x00; # Placeholder for 'Unconnected Item' length (2) (total # of data bytes after this word) = (($getPLCarray[69] - $getPLCarray[40]) + 1)
   $arr[39] = 0x00;
   $arr[40] = 0x52; # 'unconnected send' service (1)
   $arr[41] = 0x02; # size in words (1)(4 bytes)
   $arr[42] = 0x20; # class id logical segment
   $arr[43] = 0x06; # connection manager
   $arr[44] = 0x24; # instance id logical segment
   $arr[45] = 0x01; # instance number
   $arr[46] = 0x05; # tick time
   $arr[47] = 0x99; # timeout tics
   $arr[48] = 0x00; # Placeholder for Message Request Size (2) (Size in bytes of the following 'Read Tag Service' request.[65]-[50]+1) ...
   $arr[49] = 0x00; # ...
   my $message_request_size = 0;
   $arr[50] = 0x4c; # Read Tag Service Request
   if ($self->{op_type} eq 'write') {
      $arr[50] = 0x4d; # Write Tag Service Request
   }
   
   $arr[51] = 0x00;  # Placeholder for Request Path (tag name) size in words (null padding required to make complete words)
   $message_request_size += 2;
   my $bytes_in_path = 0;
   my $bytes_in_name = 0;
   # Start of Request Path
   $arr[52] = 0x91; # ANSI Extended symbolic segment for 'Overview' array
   $bytes_in_path++;
   # $DB::single = 1;
   # number of bytes in 'Tag' (can be odd number)
   $arr[53] = 0x00; # Placeholder for byte length of alphaNumerics.
   $bytes_in_path++;
   my $index_of_name_byte_size = 53;
   my $waiting_for_array_index = 0;
   my @tag_array_pointer_chars;
   foreach my $c (split //, $self->{name}) {
	   if ($c eq ']') {
		   # Ignore ]
		   $waiting_for_array_index = 0;
		   # Needs more work here for two decimal indexes into arrays
         # Turn tag_array_pointer_chars into a decimal value
         my $dec_val;
         my $ten_exp = 0;
         foreach my $i (@tag_array_pointer_chars) {
            #print "i=$i\n";
            $dec_val += ($i * 10**$ten_exp);
            $ten_exp++;
         }
         push @arr, $dec_val;
         $bytes_in_path++;
	   }
      elsif ($waiting_for_array_index) {
		   unshift @tag_array_pointer_chars, $c; 
	   }
	   elsif ($c eq '.') {
         if ($bytes_in_name % 2) {
            # Odd number of chars in Tag name, so pad and extra byte
            push @arr, 0x00;    # Null byte pad
            $bytes_in_path++;
         }
         push @arr, 0x91;
         $bytes_in_path++;
         push @arr, 0x00; # Placeholder for next bytes_in_name
         $bytes_in_path++;
		   if ($bytes_in_name) {
            $arr[$index_of_name_byte_size] = $bytes_in_name;
            $bytes_in_name = 0;
	      }

         $index_of_name_byte_size = 51 + $bytes_in_path;      # ???    Fix for case of 'string[2].DATA'
      }
	   elsif ($c eq '[') {
		   # Start of array
         if ($bytes_in_name % 2) {
         # Odd number of chars in Tag name, so pad and extra byte
            push @arr, 0x00;    # Null byte pad
            $bytes_in_path++;
         }
         push @arr, 0x28;   #  '(' character
         $bytes_in_path++;
         $arr[$index_of_name_byte_size] = $bytes_in_name;
         $bytes_in_name = 0;
		   $waiting_for_array_index = 1;
	   }
      else {
         # Normal AlphaNumeric
         push @arr, ord($c);  # Load up the Tag name into the array
         $bytes_in_path++;
         $bytes_in_name++;
      }
   }
   if ($bytes_in_name) {
      $arr[$index_of_name_byte_size] = $bytes_in_name;
      if ($bytes_in_name % 2) {
         # Odd number of chars in Tag name, so pad and extra byte
         push @arr, 0x00;    # Null byte pad
         $bytes_in_path++;
      }
   }
   # Request Path size in words
   $arr[51] = int($bytes_in_path  / 2); # 1 word for ext syb and length_in_bytes
   $message_request_size += $bytes_in_path;

   if ($self->{op_type} eq 'write') {
      if ($self->{type} eq 'DINT') {
         push @arr, 0xc4; # DINT Data Type Reporting Value
         push @arr, 0x00;
      }
      elsif ($self->{type} eq 'BOOL') {
         push @arr, 0xc1; # BOOL Data Type Reporting Value
         push @arr, 0x00;
      }
      elsif ($self->{type} eq 'SINT') {
         push @arr, 0xc2; # SINT Data Type Reporting Value
         push @arr, 0x00;
      }
      $message_request_size += 2;
   }
   # number of PLC elements to read/write (9)
   my $num_of_elements = 1;
   #$DB::single = 1;
   if ($self->{num_of_elements}) {
      $num_of_elements = $self->{num_of_elements};
   }
   push @arr, $num_of_elements;
   push @arr, 0x00;
   $message_request_size += 2;

   if ($self->{op_type} eq 'write') {
      for (my $i=0; $i<(scalar @{$self->{write_data}}); $i++) {
         push @arr, $self->{write_data}->[$i];
         $message_request_size += 1;
      }
   }

   $arr[48] = $message_request_size;

   # Path size in words (2)
   push @arr, 0x01; # path size in words (2)
   push @arr, 0x00;  

   push @arr, 0x01; # route path (2) (0x01 = backplane)
   push @arr, 0x00; # (0x00 = processor slot)

   my $size_of_arr = scalar @arr;
   $arr[2] = $size_of_arr - 24 ;

   $arr[38] = $size_of_arr - 40 + 0;

   return \@arr;   
}

sub get_session_id {
   my $self = shift;

   my $socket = new IO::Socket::INET (
      PeerHost => $self->{parent}->{plc_ip_addr},  #  PLC IP Address
      PeerPort => '44818',
      Proto => 'tcp',
   ) or die "ERROR in Socket Creation : $!\n";
   binmode $socket, ":raw";
   $self->{socket} = $socket;

   my $data;
   my @return = ();
# print "Sending session data\n";
   my @session = @{$self->{parent}->{session}};
   my $session; 
   foreach (my $i=0; $i < scalar @session; $i++) {
      my $hex = pack("h", $session[$i]);
      $session .= chr($session[$i]);
   }
   #print "\nSent session is " . length($session) . " long.\n";
   $socket->send($session);
   
   # read the socket data sent by server.
   $socket->recv($data, 1024);
   my @data = split '', $data;
   my $rec_length = length($data);
#   print "Received $rec_length bytes back\n";
#   print "\n";
   #Copy returned session handle into getPLCarray0
   $return[0] = ord(substr $data, 4, 1);
   $return[1] = ord(substr $data, 5, 1);
   $return[2] = ord(substr $data, 6, 1);
   $return[3] = ord(substr $data, 7, 1);

   return \@return;
}

sub dint_to_num{
   # Convert a scalar representing Allen Bradley DINT (four bytes) into a scalar number.
   my $self = shift;
   my $DINT = shift;
   my $num = '';
   for (my $i=0; $i<4; $i++) {
      my $chr = substr($DINT, $i, 1);
      my $part_num = ord($chr);
      $num += (256 ** $i) * $part_num;
   }
   return $num;
}

sub num_to_dint{
   my $self = shift;
   my $num = shift;

   if (wantarray) {
      my @return;
      my $temp = $num;
      for (my $i=0; $i<4; $i++) {
         my $remainder = $temp % 256;
         $return[$i] = chr($remainder);   
         $temp = int($temp/256);
      }
   }
   else {
      my $return = '';
      my $temp = $num;
      for (my $i=0; $i<4; $i++) {
         my $remainder = $temp % 256;
         $return .= chr($remainder);   
         $temp = int($temp/256);
      }
      return $return;
   }
}

sub num_to_sint{
   my $self = shift;
   my $num = shift;
   
   my $return = '';
   my $temp = $num;
   $return = chr($temp % 256);
   for (my $i=1; $i<4; $i++) {
      # Fill in 0s for unused bytes.
      $return .= chr(0);
   }
   return $return;
}

sub sint_to_num{
   # Convert a scalar representing Allen Bradley SINT (two bytes) into a scalar number.
   my $self = shift;
   my $SINT = shift;
   my $num = '';
   for (my $i=0; $i<2; $i++) {
      my $chr = substr($SINT, $i, 1);
      my $part_num = ord($chr);
      $num += (256 ** $i) * $part_num;
   }
   return $num;
}


sub read{
   my $self = shift;
   my $num_of_elements = shift;

   if (!defined $num_of_elements) {
      $num_of_elements = 1;
   }
   $self->{num_of_elements} = $num_of_elements;

   my @return;
   $self->{op_type} = 'read';
   $self->{session_aref} = $self->get_session_id();
   my $socket = $self->{socket};
   my $service_req_aref = $self->get_service_request_array();
   my $request; 
   foreach (my $i=0; $i < scalar @$service_req_aref; $i++) {
      $request .= chr($service_req_aref->[$i]);
   }
   $socket->send($request);
   my $data;
   $socket->recv($data, 1024);
   my @data = split(//, $data);

   # Check the if request returned an error.
   my $return_request_code = $data[45];   # Need to Change
   if (ord($return_request_code) != 0) {
      # Report the Error
      print STDERR "Read request error $return_request_code\n";
      if ($return_request_code eq 0x04 ) {
         print STDERR "Syntax error detected decoding the Request Path.\n";
      }
      elsif ($return_request_code eq 0x05 ) {
         print STDERR "Request Path destination unkown.\n";
      }
      elsif ($return_request_code eq 0x06 ) {
         print STDERR "Insufficient packet space.\n";
      }
      elsif ($return_request_code eq 0x13 ) {
         print STDERR "Insufficient Request Data: Data too short for expected parameters.\n";
      }
      elsif ($return_request_code eq 0x26 ) {
         print STDERR "Request Path received was shorter or longer than expected.\n";
      }
      elsif ($return_request_code eq 0xff ) {
         print STDERR "General Error.\n";
      }
   }
   else {
      # Successful read from PLC
      # PLC values starts at $data[46];
      my $data_start_index = 46;
      if ($self->{type} eq 'DINT') {
         for (my $i=0; $i<$num_of_elements; $i++){
            my $index = $data_start_index + ($i * 4);
            my $temp = $data[$index];
            $temp .=  $data[$index + 1];
            $temp .=  $data[$index + 2];
            $temp .=  $data[$index + 3];
            $return[$i] = $self->dint_to_num($temp);
         }
      }  
      elsif ($self->{type} eq 'SINT') {
         for (my $i=0; $i<$num_of_elements; $i++){
            my $index = $data_start_index + ($i * 1);
            my $temp = $data[$index];
            $return[$i] = $self->sint_to_num($temp);
         }
      }
      elsif ($self->{type} eq 'BOOL') {
         # BOOL data in represented in the PLC by one byte. 00 = false,   FF = true
         for (my $i=0; $i<$num_of_elements; $i++){
            my $index = $data_start_index + ($i * 1);
            my $temp = ord($data[$index]);
			if ($temp == 0) {
			   $return[$1] = 0;
			} else {
               $return[$i] = 1;
			}
         }
      }
      else {
         my $type = $self->{type};
         print STDERR "Undefine data type '$type' specified\n";
      }
   }
   # $DB::single = 1;
   if (wantarray()) {
      return @return;
   }
   else {
      return $return[0];
   }
}

sub write{
   my $self = shift;
   my $data = shift;

   $self->{op_type} = 'write';
   $self->{data} = '';
   $self->{write_data} = [];
   my $num_of_elements = 1; # default
   if (ref($data) eq 'ARRAY') {
      $self->{num_of_elements} = scalar @$data; 
      for (my $i=0; $i< scalar @$data; $i++) {
         if ($self->{type} eq 'SINT') {
            push @{$self->{write_data}}, $data->[$i];
         }
      }
	  if ((scalar @$data) % 2) {
		# odd amount of data, so pad to make even
		push @{$self->{write_data}}, 0x00;
	  }
   }
   else {
      if ($self->{type} eq 'BOOL') {
         if ($data) {
            push @{$self->{write_data}}, 0xff;
            push @{$self->{write_data}}, 0xff;    # Pad w/ an extra character to make buffer even
         }
         else {
            push @{$self->{write_data}}, 0x00;
            push @{$self->{write_data}}, 0x00;    # Pad w/ an extra character to make buffer even
         }
      }
      elsif ($self->{type} eq 'SINT') {
         my $val = $data % 256;
         push @{$self->{write_data}}, $val;
         push @{$self->{write_data}}, 0x00;    # Pad w/ an extra character to make buffer even
      }
      elsif ($self->{type} eq 'DINT') {
         my $val_str = $self->num_to_dint($data);
         foreach my $c (split //, $val_str) {
            push @{$self->{write_data}}, ord($c)
         }
      }
   }
  

   my @return;
   $self->{session_aref} = $self->get_session_id();
   my $socket = $self->{socket};
   my $service_req_aref = $self->get_service_request_array();
   my $request; 
   foreach (my $i=0; $i < scalar @$service_req_aref; $i++) {
      $request .= chr($service_req_aref->[$i]);
   }
   $socket->send($request);
   my $data;
   $socket->recv($data, 1024);
   my @data = split(//, $data);

   # Check the if request returned an error.
   my $return_request_code = $data[45];   # Need to Change
   if (ord($return_request_code) != 0) {
      # Report the Error
      print STDERR "Write request error $return_request_code\n";
      if ($return_request_code eq 0x04 ) {
         print STDERR "Syntax error detected decoding the Request Path.\n";
      }
      elsif ($return_request_code eq 0x05 ) {
         print STDERR "Request Path destination unkown.\n";
      }
      elsif ($return_request_code eq 0x06 ) {
         print STDERR "Insufficient packet space.\n";
      }
      elsif ($return_request_code eq 0x13 ) {
         print STDERR "Insufficient Request Data: Data too short for expected parameters.\n";
      }
      elsif ($return_request_code eq 0x26 ) {
         print STDERR "Request Path received was shorter or longer than expected.\n";
      }
      elsif ($return_request_code eq 0xff ) {
         print STDERR "General Error.\n";
      }
   }
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
   # that is not defined. By default the set values

   

   my $method = $AUTOLOAD;
   $self->Error("AUTOLOAD called for unspecified method: " . $method);
   my $return;

   return $return; 
}

sub Error{
   my $self = shift;
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

ControlLogixTab - this module is used by ControlLogix object
to set up and handle CIP read/write operations 
to/from Allen Bradley ControlLogix PLCs via TCP / ethernet.

=head1 VERSION

This documentation refers to ControlLogix and ControlLogixTag version 0.0.2.
This worked is based on many sources. Including:
Logix5000 Data Access ( http://literature.rockwellautomation.com/idc/groups/literature/documents/pm/1756-pm020_-en-p.pdf ) CIP Addressing Examples

=head1 SYNOPSIS

   use ControlLogic;
   
   my $obj = ControlLogix->new(
      plc_ip_addr => '192.168.0.150';
      my_ip_addr => '192.168.0.100', # optional
   );

   # Register a Tag. 
   my $counter_tag = obj->tag(   # tag method returns an object of type ControlLogixTag
      name => 'Counter',
      type => 'DINT',
   );

   my $count = $counter_tag->read();
   $counter_tag->write(100);


=head1 DESCRIPTION 
   This module, ControlLogixTag, is typically just used
   by a parent object of type ControlLogix.

=head1 SUBROUTINES/METHODS
   new - creates a tag object for reading and writing.

   read - method that reads data from PLC tag.

   write - method that writes data to PLC tag.
      
=head1 DEPENDENCIES
   Carp
   IO::Socket::INET

=head1 AUTHOR

<Dan DeBrito> (<ddebrito@gmail.com>)
   
   
=head1 USAGE

   use ControlLogic;
   
   my $obj = ControlLogix->new(
      plc_ip_addr => '192.168.0.150';
      my_ip_addr => '192.168.0.100', # optional
   );

   # Register a Tag. 
   my $counter_tag = obj->tag(   # tag method returns an object of type ControlLogixTag
      name => 'RejectCounter',
      type => 'DINT',
   );

   my $count = $counter_tag->read();
   $counter_tag->write(100);



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


