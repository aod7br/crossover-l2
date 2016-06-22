import boto3

s3 = boto3.resource('s3')
s3_client=s3.meta.client

for bucket in s3.buckets.all():
    print(bucket.name)

for obj in s3.Bucket('crossover-l2').objects.all():
    print obj.key

open('hello.txt','w').write('Hello, world!')

s3 = boto3.client('s3')

s3.upload_file('hello.txt', 'crossover-l2', 'hello-remote.txt')

s3.download_file('crossover-l2', 'hello-remote.txt', 'hello2.txt')

print(open('hello2.txt').read())
