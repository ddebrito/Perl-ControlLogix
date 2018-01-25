# Perl-ControlLogix
Perl Module for reading and writing to Allen Bradley Rockwell Automation ControlLogix PLC
via CIP (over ethernet, aka EtherNetIP). Module is pure Perl, so
no compiling necessary.

``` 
USAGE:

use ControlLogix;

my $plc = ControlLogix->new( 
   plc_ip_addr => '192.168.0.150', 
); 

# Read/Write to/from a PLC DINT tag. 
my $counter_tag = $plc->tag(
   {
      name => 'RejectCounter',
      type => 'DINT',
   }
);
my $reject_count = $counter_tag->read();
$counter_tag->write(100);      # Set it to 100


# Write/Read to a DINT tag local to Port_07 (note not a controller tag)
my $dint_tag = $obj->tag(
   name = 'program:port_07.a_dint_test',
   type => 'DINT',
}
$dint_tag->write(-3.456);
my $data = $dint_tag->read();


# Read/Write a STRING tag
# Note a String Tag is just a PLC tag structure of:
#    .LEN   --> a DINT indicating number of characters in the string
#    .DATA  --> array of SINTs (up to 82) of characters
# The read/write methods normalize writing to STRING tags
# by taking care of the details of reading/writing to .LEN and
# .DATA structure.
my $string_tag = $obj->tag(
   name = 'program:port_03.a_string_test',
   type => 'STRING',
}
my $string = $string_tag->read();
print "String tag was: '$string'\n";
$string_tag->write(scalar localtime);
$string = $string_tag->read();
print "String tag is now: '$string'\n";


# Read ten SINT values from a PLC SINT array
$tag_name = 'TempSTRING.DATA';  # Note DATA element of a string is a SINT array
my $sint_arr = $plc->tag(
                  {
                     name => $tag_name,
                     type => 'SINT',
                  }
);
my @data = $sint_arr->read(10);
print $tag_name . " = '@data'\n";


# Read/write a BOOL value
$bit_tag = $plc->tag(
                  {
                     name => $tag_name,
                     type => 'SINT',
                  }
);
$bit_tag->write(1);      # set BOOL
print $bit_tag->read();  # Displays '1'
$bit_tag->write(0);      # clear BOOL
print $bit_tag->read();  # Displays '0'


``` 


