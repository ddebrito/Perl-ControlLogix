# Perl-ControlLogix
Perl Modules for reading and writing to Allen Bradley Rockwell Automation ControlLogix PLC via CIP (over eithernet)

``` 

 
USAGE:

use ControlLogix;

my $plc = ControlLogix->new( 
   plc_ip_addr => '192.168.0.150'; 
   my_ip_addr => '192.168.0.100', # optional 
); 

# Read/Write to a PLC DINT tag. 
my $counter_tag = $plc->tag(
   name => 'RejectCounter',
   type => 'DINT',
);
my $reject_count = $counter_tag->read();
$counter_tag->write(100);      # Set it to 100

# Read/Write a STRING from a PLC string array
# Note a String Tag is just a tag structure of:
#    .LEN   --> a DINT indicating number of characters in the string
#    .DATA  --> array of SINTs (up to 82) of characters
# We'll use methods that abstracts of reading/writing of the STRING 
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


``` 


