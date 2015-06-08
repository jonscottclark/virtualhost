#!/bin/bash
### Set Language
TEXTDOMAIN=virtualhost

### Set default parameters
action=$1
hostname=$2
rootDir=$3
owner=$(who am i | awk '{print $1}')
email='webmaster@localhost'
sitesEnable='/etc/apache2/sites-enabled/'
sitesAvailable='/etc/apache2/sites-available/'
userDir='/var/www/'
sitesAvailablehostname=$sitesAvailable$hostname.conf

### don't modify from here unless you know what you are doing ####

if [ "$(whoami)" != 'root' ]; then
	echo $"=> ERROR: Must run $0 as root. Use sudo. Exiting..."
		exit 1;
fi

if [ "$action" != 'create' ] && [ "$action" != 'delete' ]
	then
		echo $"=> MISSING ARG: You must specify an action ('create' or 'delete') as the first argument. Exiting..."
		exit 1;
fi

while [ "$hostname" == "" ]
do
	echo -e $"=> MISSING ARG: No hostname provided. Enter a hostname:"
	read hostname
done

if [ "$rootDir" == "" ]; then
	rootdir=${hostname//./}
fi

### if root dir starts with '/', don't use /var/www as default starting point
if [[ "$rootDir" =~ ^/ ]]; then
	userDir=''
fi

rootDir=$userDir$rootDir

if [ "$action" == 'create' ]
	then
		### check if hostname already exists
		if [ -e $sitesAvailablehostname ]; then
			echo -e $"=> ERROR: This hostname already exists. Exiting..."
			exit;
		fi

		### check if directory exists or not
		if ! [ -d $rootDir ]; then
			### create the directory
			mkdir $rootDir
			### give permission to root dir
			chmod 755 $rootDir
			### write test file in the new hostname dir
			if ! echo "<?php echo phpinfo(); ?>" > $rootDir/phpinfo.php
			then
				echo $"=> ERROR: Not able to write phpinfo.php to $userDir/$rootdir/. Please check permissions!"
				exit;
			else
				echo $"=> CREATED: $rootDir/phpinfo.php"
			fi
		fi

		### create virtual host rules file
		if ! echo "
		<VirtualHost *:80>
			ServerAdmin $email
			ServerName $hostname
			ServerAlias $hostname
			DocumentRoot $rootDir
			<Directory />
				AllowOverride All
			</Directory>
			<Directory $rootDir>
				Options Indexes FollowSymLinks MultiViews
				AllowOverride all
				Require all granted
			</Directory>
			ErrorLog /var/log/apache2/$hostname-error.log
			LogLevel error
			CustomLog /var/log/apache2/$hostname-access.log combined
		</VirtualHost>" > $sitesAvailablehostname
		then
			echo -e $"=> ERROR: Can't create $hostname.conf"
			exit;
		fi

		### Add hostname in /etc/hosts
		if ! echo "127.0.0.1	$hostname" >> /etc/hosts
		then
			echo $"=> ERROR: Not able to write to /etc/hosts"
			exit;
		else
			echo -e $"=> OK: Host added to /etc/hosts file \n"
		fi

		if [ "$owner" == "" ]; then
			chown -R $(whoami):$(whoami) $rootDir
		else
			chown -R $owner:$owner $rootDir
		fi

		### enable website
		a2ensite $hostname

		### restart Apache
		/etc/init.d/apache2 reload

		### show the finished message
		echo -e $"=> OK: Virtual host created!"
    echo -e $"       URL: http://$hostname"
    echo -e $"       Document Root: $rootDir"
		exit;
	else
		### check whether hostname already exists
		if ! [ -e $sitesAvailablehostname ]; then
			echo -e $"=> ERROR: Can't remove. This hostname does not exist."
			exit;
		else
			### Delete hostname in /etc/hosts
			newhost=${hostname//./\\.}
			sed -i "/$newhost/d" /etc/hosts

			### disable website
			a2dissite $hostname

			### restart Apache
			/etc/init.d/apache2 reload

			### Delete virtual host rules files
			rm $sitesAvailablehostname
		fi

		### check if directory exists or not
		if [ -d $rootDir ]; then
			echo -e $"=> CONFIRM: Delete host root directory ? (y/n)"
			read deldir

			if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then
				### Delete the directory
				rm -rf $rootDir
				echo -e $"=> OK: Directory deleted"
			else
				echo -e $"=> OK: Host directory left alone."
			fi
		else
			echo -e $"=> OK: Host directory not found. Exiting..."
		fi

		### show the finished message
		echo -e $"=> REMOVED: $hostname"
		exit 0;
fi
