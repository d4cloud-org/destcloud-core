# core

## Preparation

install ruby and ruby-dev from package manager e.g. yum, apt, pkg.

install daemon command from package manager if not installed.
e.g. apt-get install daemon

install sinatra, thin by gem.
e.g.:
 # gem install sinatra
 # gem install thin
 # gem install uuidtools
 # gem install rest-client 


## Installation

enter the directory destcloud-core, and do install.sh as root user.

 # ./install.sh

## Invoke it

 # systemctl start destcloud2

## Stop it

 # systemctl stop destcloud2

## enable/disable the service

 # systemctl enable destcloud2

or

 # systemctl disable destcloud2


