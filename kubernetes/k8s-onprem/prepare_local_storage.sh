#!/bin/bash -e 

n1=$1      #first rumber in volumes list
n2=$2      #last number in volumes list
disk=$3    #storage disk name (for example, sdb; you can choose name "folder" to create volumes at /var/opt/)
make_fs=$4 #create filesystem on disk

if [ -z "${n1}" ]; then
	echo >&2 "ERROR: Volumes list first number is not defined"
	exit 2
fi
if [ -z "${n2}" ]; then
	echo >&2 "ERROR: Volumes list last number is not defined"
	exit 2
fi
if [ -z "${disk}" ]; then
	echo >&2 "ERROR: Disk name is not provided"
	exit 2
fi

if [ -n "${make_fs}" ]; then
	sudo mkfs.ext4 /dev/${disk}
	sudo mkdir -p /mnt/disk-${disk}
	sudo mount /dev/${disk} /mnt/disk-${disk}
	echo "/dev/${disk} /mnt/disk-${disk} ext4 defaults 0 1" | sudo tee -a /etc/fstab 
fi

if [ ${disk} != "folder" ]; then 
	for i in $(seq ${n1} ${n2}); do
		sudo mkdir -p /mnt/disk-${disk}/vol${i} /mnt/disks/disk_vol${i}
		sudo mount --bind /mnt/disk-${disk}/vol${i} /mnt/disks/disk_vol${i}
		echo "/mnt/disk-${disk}/vol${i} /mnt/disks/disk_vol${i} none bind 0 0" | sudo tee -a /etc/fstab
	done
else
	for i in $(seq ${n1} ${n2}); do
		sudo mkdir -p /var/opt/vol${i} /mnt/disks/disk_vol${i}
		sudo mount --bind /var/opt/vol${i} /mnt/disks/disk_vol${i}
		echo /var/opt/vol${i} /mnt/disks/disk_vol${i} none bind 0 0 | sudo tee -a /etc/fstab
	done
fi

#for ubuntu 24.04 you need to apply fstab changes
sudo systemctl daemon-reload