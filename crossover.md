# Crossover Application challenge
Andre Oliveira Dias aod7br@gmail.com

I divided the challenge work in the seven steps below:

### 1) SETUP AWS

First a AWS user   (I created aod7brpsn since my personal one was blocked)

- create user on IAM and access keys

	user: crossover
	
	Access Key ID: 	AKIAJ7VDYHMNDNLC46QA
	
	Secret Access Key: 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

>I spent a lot of time trying to understand IAM and amazon polices, keys (knew ssh key but had to learn IAM users access keys)

Attach AmazonS3FullAccess policy to new user crossover. This will be the user/key combination to upload to S3 bucket.

* create bucket named crossoverl2
* create a security group and liberate ports 22(default), 80, 81 and 3306

> Now we will create an EC2 Instance. I chose ubuntu, but given more configuration time, I would choose debian.

* create an ubuntu 14.04 instance from an AMI Image
* get external IP and export in the local shell (example below)
    ```
			export IP=52.67.74.17
    ```

### 2) ssh into AWS Instance
    ```
	ssh -i ~/.ssh/id_rsa ubuntu@$IP
	sudo bash
	aptitude update
    ```

* fix locale warnings 
    ```
	    locale-gen en_US en_US.UTF-8 pt_BR.UTF-8 && dpkg-reconfigure locales
    ```
    ```
	aptitude upgrade
    ```
* Lets install docker following https://docs.docker.com/engine/installation/linux/ubuntulinux/ our version is ubuntu 14

* find ubuntu version and install packages
    ```
    apt-get install python-pip
	aptitude install apt-transport-https ca-certificates
	apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

	echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" >> /etc/apt/sources.list.d/docker.list
	aptitude update
	apt-get install linux-image-extra-$(uname -r)

    apt-get install docker-engine
	usermod -aG docker ubuntu
	```
* Now lets install mysql server and icinga
    ```
	aptitude install mysql-server
	aptitude install icinga-web
    ```
> I was installing mysql and apache2 before icinga-web... no need to do it separately, like I was, icinga-web install them as dependencies.
>But later I had to backtrack and install mysqld first, icinga install asks for mysql root but does not setup mysqld correctly first, so the above must done in this order.

* install aws cli tools and containers
    ```
	# aws cli tools
	apt-get install awscli
	su - ubuntu
	docker network create mynetwork
    ```

* get internal IP and export in this instance shell (example below)
    ```
		export IP=172.31.0.92 
    ```
* create containers
    ```
	docker run --detach  -p $IP:3306:3306 --name mysql --net mynetwork --env MYSQL_ROOT_PASSWORD=myroot mysql:5.6
	docker run --detach  -p $IP:81:80 --name apache --net mynetwork --env APACHE_ROOT_PASSWORD=myroot httpd
    ```

### 3) Create upload scripts

 First I searched for available S3 libraries. Found boto3 for python and Net::Amazon::S3 on CPAN for Perl. Played with them for a while, testing several methods
* We must install the chosen libraries
    ```
    cpan Net::Amazon::S3 IO::All
    pip install boto3
    ```
* Configure the environment for the scripts and enter the keys created in step 1)
    ```
	aws configure
    ```

> testing the scripts I ran into this error " must specify endpoint location to access bucket so you must enter the information below in aws configure "
* South America (São Paulo)	sa-east-1

	### created s3.pl and s3.py upload scripts ### 
	(they are in the zip file I also copied then to the EC2 ubuntu instance) 
    ```
    scp -i .ssh/id_rsa s3.pl s3.py ubuntu@$IP:
    ```
> During the development of this two scripts I discovered that unlike bash, perl and python do not tie the current linux user to the aws user
> First tought of copying files from docker, but docker but docker logs seems more elegant. Spent time trying to capture docker logs output with scripts.

Both the python and perl scripts do the same thing. I decided for python first (was mentioned in the requirements). But I like Perl better for sysadmin work (bes language for text processing and in my opinon superceedes bash). Python has a better object model and is easier for team programming though. I really love python the terse syntax and the way it exposes algorithms with clarity ( it reminds me of mathematics)

>side note: AWS saw the key when I uploaded the script to github, locked my account and contacted me. I deleted the key, contacted them and they restored it, but it did slow me down. Anyway, great work Amazon security team.


### 4) Create crontab entries
> The challenge asks the scripts to upload at 7 pm daily, but on which timezone? I suggest to improve the test by picking a TZ and make the examinee calculate convertion
* edit contrab and create the entries below
    ```
	crontab -e 
	#log uploading
	0 19 * * * (docker logs mysql 2>&1) >/tmp/mysql.log && /home/ubuntu/s3.pl /tmp/mysql.log
	0 19 * * * (docker logs apache 2>&1) >/tmp/apache.log && /home/ubuntu/s3.py /tmp/apache.log
    ```
### 5) Configure icinga to monitor containers

>I had worked with Nagios before (and even developed a monitoring solution in python) but never with Icinga. I had to do lots of reading on this item.

* I followed the pages below to understand and configure Icinga
	* https://wiki.icinga.org/display/howtos/Reset+Icinga+Web+root+password
	* https://wiki.icinga.org/display/howtos/Setting+up+Icinga+Web+on+Ubuntu

* The ubuntu setup of Icinga does must of the job. What I really needed to do was create remote monitoring files for Icinga (they are in the sent zip file):
    * mysql.cfg
	* apache.cfg
* Lets copy the files to the Instance and restart apache
    ```
    scp -i .ssh/id_rsa mysql.cfg http.cfg ubuntu@$IP:
    scp -i .ssh/id_rsa ubuntu@$IP:
    sudo cp mysql.cfg http.cfg /etc/icinga/objects
    sudo service apache2 restart
    ```
### 6) Passwod protect website
* Lets create .htpasswd to protect the webserver, requiring crossover login
	```
	htpasswd -c .htpasswd crossover
	```

* put .htpasswd on /var/www/html/ and change edit /etc/apache2/sites-enabled/000-default.conf, adding the lines below

	```
      <Directory "/var/www/html">
         AuthType Basic
         AuthName "Restricted Content"
         AuthUserFile /var/www/html/.htpasswd
         Require valid-user
     </Directory>
    ```
* restart apache
  	```
    sudo service apache2 restart
    ```
> I was unable to put .htpasswd to work inside container. I was short of time and moved on.


### 7) Backup

* The first form of backup will be to create AMI image of the running instance on AWS console
> One could later programatically do the snapshot using a script

In the first version of the scripts I was capturing the logs in perl and python (using subprocess in python), from the execution of "docker logs container" in a subshell. But since I also had to upload backups at this stage, I decided to change the scripts, passing the filepath as a parameter to the scripts. This way I could use them to upload logs and backups to S3 bucket. So I changed the scripts. Now we must add the entries bellow on crontab:
    ```

	crontab -e 
	#backups
	docker save -o mysql.tar mysql && /home/ubuntu/s3.pl mysql.tar
	docker save -o apache.tar mysql && /home/ubuntu/s3.py apache.tar
    ```

### Thats it. We have finished the challenge. Except for the puppet script, which unfortunatelly I did not have enought time to do. ###

> Dear examiner, would you consider adding one more day to the total due time of this assignment?

