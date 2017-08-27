# fsiproject: fsi portal

This is the fsi web portal, a part of the fsi project.


## fsi project = flexible server installation for esxi, xenserver and linux

fsi is a web portal and some additional installation, configuration and update functions for:
- VMware ESXi 4.x, 5.x and 6.x
- XenServer 6.x and 7.x
- CentOS 5.x, 6.x and 7.x
- RedHat Enterprise 5.x, 6.x and 7.x

In the fsi portal you can add or import different server configuration. The installation and running servers are monitored with some detail views. Each detail server web page has the posibility to patch the server with new fixes or updates. Rudimentary virtual machine actions can use to prepare these server for update/reboots.

A virtual machine cloning uses VMware API to clone / backup virtual machines. Controlled through schedule you can start a backup rotation scheme Grandfather-father-son or simple unique. Clones can be put on ESXi datastores and scp/nfs/cifs targets. Clone process is running with online and offline virtual machines.

Project Homepage: [www.fsiproject.org](http://www.fsiproject.org)



## Statement

I know that the source is not 100%. I would like to change the saving of passwords for the kickstart installations differently. 

There is also still source, which I wanted to improve long ago times, contain. At the xenserver installation I want to change the bash and perl scripts with the xe commands to python and the xenserver api. My fsi web portal is not in responsive design or has theme support.

Nevertheless, I wanted to finally publish it and mayby someone will find the source or parts of it useful or can help me to develop and improve fsi.

Request: If you find something that can be improved ... please write me, I am glad about any help.

## Finaly

Finally, I would like to say a thank you to all who help every day and develop good libraries or tools I use in fsi. Please read for that the fsi project wiki for a list.

Project Wiki: [wiki.fsiproject.org](http://wiki.fsiproject.org)