# Perl-ControlLogix
Perl Modules for reading and writing to Allen Bradley Rockwell Automation ControlLogix PLC via CIP (over eithernet)

``` 
USAGE:

use ControlLogix;

my $plc = ControlLogix->new( 
   plc_ip_addr => '192.168.0.150', 
   my_ip_addr => '192.168.0.100', # optional 
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

# Read/Write a STRING to/from a PLC string array
# Note a String Tag is just a PLC tag structure of:
#    .LEN   --> a DINT indicating number of characters in the string
#    .DATA  --> array of SINTs (up to 82) of characters
# We'll use methods that abstract the reading/writing of STRING tags 
my $tag = 'TestString[2]';
my $string = $plc->read_string_tag($tag);
print "String read test for $tag result is: '$string'\n";
$plc->write_string_tag($tag,'Another two');
$string = $plc->read_string_tag($tag);
print "String read test for $tag result is: '$string'\n";

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


