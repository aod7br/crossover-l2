use Net::Amazon::S3;
use IO::All;

# dont worry, will revoke this key vjust after crossover evaluation
my $aws_access_key_id     = 'AKIAJWMA5L2GGBNGYOPQ';
my $aws_secret_access_key = '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';


# dont worry, will revoke this key just after crossover evaluation
my $s3 = Net::Amazon::S3->new(
    aws_access_key_id     => $aws_access_key_id,
    aws_secret_access_key => $aws_secret_access_key,
	host				  => 's3-sa-east-1.amazonaws.com',
	secure				  => 1,
    retry                 => 1,
);


my $response = $s3->buckets; #get  all buckets that i own
my $n=0;
foreach my $bucket ( @{ $response->{buckets} } ) {
	$n++;
    print "bucket $n: " . $bucket->bucket . "\n";
}

$bucket = $s3->bucket('crossover-l2'); #crossover test bucket

$filename='2.log';
$bucket->add_key( $filename, io->file( $filename )->all )
    or die $s3->err . ": " . $s3->errstr;

# list files in the bucket
$response = $bucket->list_all or die $s3->err . ": " . $s3->errstr;
foreach my $key ( @{ $response->{keys} } ) {
      my $key_name = $key->{key};
      my $key_size = $key->{size};
      print "Bucket contains key '$key_name' of size $key_size\n";
}
