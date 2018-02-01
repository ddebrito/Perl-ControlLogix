#!/usr/bin/perl

package ControlLogix;
@ISA = ();
our $AUTOLOAD;

use strict;
use Carp qw(cluck);

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


package ControlLogixTag;
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
		 @tag_array_pointer_chars = ();  # empty temp array
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
      if ($self->{type} eq 'BOOL') {
         push @arr, 0xC1; # BOOL Data Type Reporting Value
         push @arr, 0x00;
      }
      elsif ($self->{type} eq 'SINT') {
         push @arr, 0xC2; # SINT Data Type Reporting Value
         push @arr, 0x00;
      }
      elsif ($self->{type} eq 'INT') {
         push @arr, 0xC3; # INT Data Type Reporting Value
         push @arr, 0x00;
      }
      elsif ($self->{type} eq 'DINT') {
         push @arr, 0xC4; # DINT Data Type Reporting Value
         push @arr, 0x00;
      }
      elsif ($self->{type} eq 'REAL') {
         push @arr, 0xCA; # REAL Data Type Reporting Value
         push @arr, 0x00;
      }
      elsif ($self->{type} eq 'DWORD') {
         push @arr, 0xD3; # DWORD Data Type Reporting Value
         push @arr, 0x00;
      }
      elsif ($self->{type} eq 'LINT') {
         push @arr, 0xc5; # LINT Data Type Reporting Value
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

sub int_to_num{
   # Convert a scalar representing Allen Bradley INT (two bytes) into a scalar number.
   my $self = shift;
   my $INT = shift;
   my $num = '';

   $num = unpack("s<", $INT);	  # Format of $INT is signed 16 bit little endian
   return $num;
}

sub dint_to_num{
   # Convert a scalar representing Allen Bradley DINT (four bytes) into a scalar number.
   my $self = shift;
   my $DINT = shift;
   my $num = '';

   $num = unpack("l<", $DINT);	  # Format of $DINT is signed 32 bit little endian
   return $num;
}

sub lint_to_num{
   # Convert a scalar representing Allen Bradley LINT (eight bytes) into a scalar number.
   my $self = shift;
   my $LINT = shift;
   my $num = '';

   $num = unpack("q<", $LINT);	  # Format of $LINT is signed 64 bit little endian
   return $num;
}
sub num_to_dint{
   my $self = shift;
   my $num = shift;
                                   # Note Control Logix DINTs are transmitted in little endian
   my $return = pack("l<", $num);  # Takes the string $num and puts it into format of signed 32 bit little endian.
   return $return;
}

sub num_to_real{
   # Convert a Perl scalar number to AB ControlLogix REAL format
   # 4 bytes long. LSB
   # eg decimal 16 should convert to 00 00 80 41
   # (where 41800000 is 16)

   my $self = shift;
   my $num = shift;
   my $single_precision_floating_point;
   $single_precision_floating_point = pack("f<", $num);     # Make sure little endian format
   my @chars = split '', $single_precision_floating_point;
   my @return;
   for (my $i=0; $i<=3; $i++) {
      my $ord = ord($chars[$i]);
      $return[$i] = $ord;
   }
   
   return \@return;
}


sub real_to_num{
   my $self = shift;
   my @REAL = @_;
   
   # eg ControlLogix REAL  00 00 80 41 should convert to decimal 16
   # (where single precision float 41800000 is 16 decimal)
   my $string = '';
   foreach my $b  (reverse @REAL) {
      $string = pack("H*",$b) . $string;
   }
   my $num = unpack("f<",$string);  # $string is in format of signed little endian
	  
   return $num;
}

sub sint_to_num{
   # Convert a scalar representing Allen Bradley SINT (one byte) into a scalar number.
   my $self = shift;
   my $SINT = shift;
   my $num = ord($SINT); 
   return $num;
}

sub dec2bin {
    my $str = unpack("B32", pack("N", shift));
    $str =~ s/^0+(?=\d)//;   # otherwise you'll get leading zeros
    return $str;
}


# Note AB ControlLogix store bit arrays in groups of 4-bytes.
# Each group can represent up to 32 bits/BOOLs




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
      elsif ($self->{type} eq 'INT') {
         for (my $i=0; $i<$num_of_elements; $i++){
            my $index = $data_start_index + ($i * 2);
            my $temp = $data[$index];
            $temp .=  $data[$index + 1];
            $return[$i] = $self->int_to_num($temp);
         }
      }  
      elsif ($self->{type} eq 'SINT') {
         for (my $i=0; $i<$num_of_elements; $i++){
            my $index = $data_start_index + ($i * 1);
            my $temp = $data[$index];
            $return[$i] = $self->sint_to_num($temp);
         }
      }
      elsif ($self->{type} eq 'LINT') {
         for (my $i=0; $i<$num_of_elements; $i++){
            my $index = $data_start_index + ($i * 48);
            my $temp = $data[$index];
            $temp .=  $data[$index + 1];
            $temp .=  $data[$index + 2];
            $temp .=  $data[$index + 3];
            $temp .=  $data[$index + 4];
            $temp .=  $data[$index + 5];
            $temp .=  $data[$index + 6];
            $temp .=  $data[$index + 7];
            $return[$i] = $self->lint_to_num($temp);
         }
      }  
      elsif ($self->{type} eq 'BOOL') {
         # BOOL data in represented in the PLC by one byte. 00 = false,   FF = true
         for (my $i=0; $i<$num_of_elements; $i++){
            my $index = $data_start_index + ($i * 1);
            my $temp = ord($data[$index]);
   			if ($temp == 0) {
	   		   $return[$i] = 0;
		   	} else {
               $return[$i] = 1;
			   }
         }
      }
      elsif ($self->{type} eq 'REAL') {
         for (my $i=0; $i<$num_of_elements; $i++){
            my $index = $data_start_index + ($i * 4);
            my @arr;
            $arr[0] = sprintf "%02x", ord($data[$index]); 
            $arr[1] = sprintf "%02x", ord($data[$index+1]);
            $arr[2] = sprintf "%02x", ord($data[$index+2]);
            $arr[3] = sprintf "%02x", ord($data[$index+3]);
            
            my $num = $self->real_to_num( @arr );
            $return[$i] = $num;
         }
      }
      else {
         my $type = $self->{type};
         print STDERR "Undefined data type '$type' specified\n";
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
         if ($self->{type} eq 'BOOL') {
            push @{$self->{write_data}}, $data->[$i];
         }
         if ($self->{type} eq 'SINT') {
            push @{$self->{write_data}}, $data->[$i];
         }
         elsif($self->{type} eq 'DINT') {
            my $val_str = $self->num_to_dint($data->[$i]);
            foreach my $c (split //, $val_str) {
               push @{$self->{write_data}}, ord($c)
            }
         }
         elsif($self->{type} eq 'REAL') {
            push @{$self->{write_data}}, @{$self->num_to_real($data->[$i])};
         }
      }
	  if ((scalar @{$self->{write_data}}) % 2) {
		# odd amount of data, so pad to make even
		push @{$self->{write_data}}, 0x00;
	  }
   }
   else {   # Not array
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
      elsif ($self->{type} eq 'REAL') {
         push @{$self->{write_data}}, @{$self->num_to_real($data)};
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

   
   my $real_arr_tag = $plc->tag(
                     {
                        name => 'test_REAL_arr[1]',
                        type => 'REAL',
                     }
   );
   $real_arr_tag->write(16);
   my $data = $real_arr_tag->read();  # data is 16
   print "REAL data=$data\n";
   $real_arr_tag->write(42.42);
   my $data = $real_arr_tag->read();  # data is 42.4199981689453
   $real_arr_tag->write(3.1412);
   my $data = $real_arr_tag->read();  # data is 3.14120006561279
   my @arr = (3.1412, 42.42, 3.3333);
   $real_arr_tag->write(\@arr);       # Write three numbers into a REAL array
   my @nums;
   @nums = $real_arr_tag->read(3);    # Read three numbers back out of REAL array.
