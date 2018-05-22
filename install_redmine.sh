#!/bin/sh

set -e

MYSQL_VERSION=5.5
[ -z "${MYSQL_PASSWD}" ] && MYSQL_PASSWD=mysql
[ -z "${REDMINE_PASSWD}" ] && REDMINE_PASSWD=redmine

mysql_install()
{
  cat <<EOF | sudo debconf-set-selections
mysql-server-${MYSQL_VERSION} mysql-server/root_password password ${MYSQL_PASSWD}
mysql-server-${MYSQL_VERSION} mysql-server/root_password_again password ${MYSQL_PASSWD}
EOF
  sudo apt install -y mysql-server
}

redmine_install()
{
  cat <<EOF | sudo debconf-set-selections
redmine redmine/instances/default/dbconfig-install boolean true
redmine redmine/instances/default/database-type select mysql
redmine redmine/instances/default/mysql/admin-pass password ${MYSQL_PASSWD}
redmine redmine/instances/default/password-confirm password ${MYSQL_PASSWD}
redmine redmine/instances/default/mysql/app-pass password ${REDMINE_PASSWD}
redmine redmine/instances/default/app-password-confirm password ${REDMINE_PASSWD}
EOF
  sudo apt install -y redmine-mysql
}

apache_install()
{
  sudo apt install -y apache2 libapache2-mod-passenger bundler

  # Overwrite passenger.conf.
  cat << EOF | sudo tee /etc/apache2/mods-available/passenger.conf
<IfModule mod_passenger.c>
  PassengerRoot /usr/lib/ruby/vendor_ruby/phusion_passenger/locations.ini
  PassengerDefaultRuby /usr/bin/ruby
  PassengerDefaultUser www-data
  RailsBaseURI /redmine
</IfModule>
EOF

  cd /var/www/html
  sudo ln -s /usr/share/redmine/public redmine
  sudo chown -R www-data:www-data /usr/share/redmine
  cat << EOF | sudo tee /etc/apache2/sites-available/redmine.conf
<VirtualHost _default_:443>
  SSLEngine on
  SSLCertificateFile    /etc/ssl/certs/ssl-cert-snakeoil.pem
  SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key

  <Directory /redmine>
    Options FollowSymLinks
    PassengerResolveSymlinksInDocumentRoot on
    AllowOverride None
  </Directory>
</VirtualHost>
EOF

  sudo a2enmod passenger
  sudo a2enmod ssl
  sudo a2ensite redmine

  sudo systemctl enable apache2
  sudo systemctl restart apache2
}

redmine_main()
{
  mysql_install
  redmine_install
  apache_install
}

redmine_main