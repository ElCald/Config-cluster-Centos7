# Documentation installation d’un cluster sur CentOS 7
 Installation de `Clush`, `NFS`, `MPI`, `Slurm`. Configuration de `SSH` et script pour créer un utilisateur.
| **Machine** | **Type** | **Adresse** |
|--|--|--|
| **nvidia0** | Admin | 10.124.2.46 |
| **nvidia1** | Compute | 10.124.2.47 |
| **nvidia2** | Compute | 10.124.2.48 |
| **nvidia3** | Compute | 10.124.2.49 |
| **nvidia4** | Compute | 10.124.2.50 |


# -1/ Update les mirrors

Changement des mirrors car ceux présents par défaut sont obsolètes.
````
sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/CentOS-*.repo
sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/CentOS-*.repo
sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/CentOS-*.repo
````

# 0/ Passwd + hostname

### Changement du mot de passe :
`sudo passwd`

### Changement du nom sur chaque machine :

`sudo hostnamectl set-hostname nvidia0` 
`sudo nano /etc/hosts`
    
Ajouts de l’ip de toutes les machines suivie de leur nom
````
10.124.2.46 nvidia0
10.124.2.47 nvidia1
10.124.2.48 nvidia2
10.124.2.49 nvidia3
10.124.2.50 nvidia4
````
Exemple contenu `/etc/hosts`: <br>
![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXel_clibGcZydxMhlKWB7uFBscCHR2uvrENOzCl3xaoPDZAKpj2Ght8xc6r3Qw5L0nLKDj9u1ROo0wNPLx6hhyXN63UfnvlD6QmnfPLDgdiIjXePoQn8i5fI6ncRNvib_QgRR4g?key=Gmghb7iB0o37wOY8486IdA)

# 1/ SSH

Connexion ssh du compte root de la machine admin vers admin et vers computes

###  Création de la clé ssh avec protocole RSA :

`ssh-keygen -t rsa -b 4096` 
    
#### Copie de la clé ssh dans toutes les machines :
    
`ssh-copy-id root@10.124.2.[46-50]`
    
**Ne pas oublier la connexion ssh de nvidia0 vers nvidia0 et faire une 1ère connexion ssh avec toutes les machines pour enregistrer le fingerprint dans le répertoire** `~/.ssh/known_hosts`
    

# 2/ Clush

### Dépendances :
    
`sudo yum install -y perl-Errno perl-File-Temp perl-IO-File perl-IO-Socket-SSL perl-Getopt-Long perl-Text-Glob` 

### Installation de EPEL:
    

`sudo yum install -y epel-release` 

### Installer clush :
    
` sudo yum install -y clustershell`

###  Configurer noeuds :
    
`sudo nano /etc/clustershell/groups` 

Ajouter dans le fichier `/etc/clustershell/groups` (**PAS D’ESPACE ENTRE** “:” ET “all” ou “computes” ou “admin”):
    
```
all: nvidia0 nvidia1 nvidia2 nvidia3 nvidia4
computes: nvidia1 nvidia2 nvidia3 nvidia4
admin: nvidia0
```
### Exemples de vérifications
    
` clush -w 10.124.2.[46-50] "hostname -I" `<br>
` clush -g Cl_Nvidia echo "Bonjour" `
    

# 3/ NFS

Pour l’installation de NFS sur toutes les machines nous passerons par clush, s’il n’est pas installé, il faudra faire les commandes sur toutes les machines.
Les répertoires partagés seront `/apps` et `/home`.

*Exécution de toutes les commandes suivantes depuis la machine root (nvidia0).*
    

### Installer NFS sur toutes les machines:

`clush -g all sudo yum -y install nfs-utils`
    
Créer répertoire apps si il n’existe pas :
    
` clush -g all sudo mkdir -p /apps`

### Editer le fichier exports :

`sudo nano /etc/exports`
    

Ajouter les lignes suivantes :
````
/home nvidia1(rw,sync,no_root_squash,no_subtree_check)
nvidia2(rw,sync,no_root_squash,no_subtree_check) 
nvidia3(rw,sync,no_root_squash,no_subtree_check) 
nvidia4(rw,sync,no_root_squash,no_subtree_check

/apps nvidia1(rw,sync,no_root_squash,no_subtree_check) 
nvidia2(rw,sync,no_root_squash,no_subtree_check) 
nvidia3(rw,sync,no_root_squash,no_subtree_check) 
nvidia4(rw,sync,no_root_squash,no_subtree_check)
````

### Démarrer le service NFS et le configurer pour qu’il démarre automatiquement
    

`sudo systemctl enable nfs-server`<br>
`sudo systemctl start nfs-server`
    

Vérifier que les dossiers sont biens exportés : 
`sudo exportfs -v`
    
### Ajout de règles au pare-feu :
   
` sudo firewall-cmd --permanent --add-service=nfs sudo firewall-cmd --permanent --add-service=mountd sudo firewall-cmd --permanent --add-service=rpc-bind sudo firewall-cmd --reload `
    

Sur chaques machines **hormis la root**, montez les répertoires :
    
`clush -g computes sudo mount -t nfs machine0:/home /home`<br>
`clush -g computes sudo mount -t nfs machine0:/apps /apps`
    

Vérification que les partages ont été montés correctement :
    
`clush -g computes df -h | grep nvidia0`
    

Enfin, pour monter les répertoires automatiquement au démarrage des machines, ajouter ces lignes au fichier `/etc/fstab` de toutes les machines **sauf la root** :
````
nvidia0:/home /home nfs defaults 0 0
nvidia0:/apps /apps nfs defaults 0 0  
````
    

# 4/ Create user

### Script bash :
```bash
if [ -n  "$1" ]; then
	# Nom de l'utilisateur
	nom_utilisateur="$1"

	# Génère une chaine de 10 caractères aléatoires pour faire un mot de passe (8 c'est le nb min de char pour un passwd)
	new_password=$(< /dev/urandom tr -dc 'A-Za-z0-9!@#$%&*()'  |  head  -c  10)

	# Création de l'utilisateur sur la machine master (nvidia0)
	# useradd : Crée un utilisateur
	# -M :
	# -m : Crée son répertoire dans /home
	# -d : Force son répertoire dans /home
	# -s : Le shell est bash
	sudo  useradd  -m  -d  /home/$nom_utilisateur  -s  /bin/bash  $nom_utilisateur
	  
	# Changement du mot de passe de l'utilisateur
	echo  "$nom_utilisateur:$new_password"  |  sudo  chpasswd

	# Commandes pour créer l'utilisateur sur les autres machines
	creer_utilisateur="sudo useradd -M -d /home/$nom_utilisateur -s /bin/bash $nom_utilisateur"
	modif_passwd="echo '$nom_utilisateur:$new_password' | sudo chpasswd"

	# Création des utilisateurs sur les autres machines du cluster
	clush  -g  computes  "$creer_utilisateur && $modif_passwd"

	# Création de la clé ssh pour l'utilisateur dans son répertoire home
	su  -  $nom_utilisateur  -c  "ssh-keygen -t rsa -b 2048 -f "/home/$nom_utilisateur/.ssh/id_rsa" -N ''"

	# Copie de la clé public de l'utilisateur dans le fichier authorized_keys
	cat  /home/$nom_utilisateur/.ssh/id_rsa.pub  >  /home/$nom_utilisateur/.ssh/authorized_keys

	# Permissions pour les accès au ssh de l'utilisateur
	chmod  700  /home/$nom_utilisateur/.ssh
	chmod  600  /home/$nom_utilisateur/.ssh/authorized_keys

	# Changement du propriétaire du fichier authorized_keys
	chown  $nom_utilisateur:$nom_utilisateur  /home/$nom_utilisateur/.ssh/authorized_keys
	echo  "Création de l'utilisateur $nom_utilisateur avec le mot de passe : $new_password"
else
	echo  "Erreur : pas de nom d'utilisateur."
	exit  1
fi
```

### Donner les permissions au script :

`chmod +x createuser.sh`

### Exécution du script

`./createuser.sh nom`
    

## Configurer SELinux 
*Source : <br>
[https://serverfault.com/questions/849631/why-is-selinux-blocking-remote-ssh-access-without-a-password](https://serverfault.com/questions/849631/why-is-selinux-blocking-remote-ssh-access-without-a-password)*

SELinux bloque l’accès de ssh aux répertoires et fichiers NFS, pour régler ce problème 2 options.
    
Retirer tout le système de sécurité SELinux avec :

`setenforce 0`
    

OU

Modifier la config pour laisser autoriser l’accès à ssh aux répertoires NFS
    
`setsebool -P use_nfs_home_dirs 1`
    

# 5/ MPI

Note : Un fichier de test pour MPI est dans le répertoire apps commun à toutes les machines.

### Installer mpi sur toutes les machines
    

`clush -g all sudo yum -y install openmpi`<br>
`clush -g all sudo yum -y install openmpi-devel`
    

### Ajouter mpi au path
    
`clush -g all "echo 'export PATH=/usr/lib64/openmpi/bin:\$PATH' | sudo tee /etc/profile.d/mpi.sh"`
    
`clush -g all "echo 'export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:\$LD_LIBRARY_PATH' | sudo tee -a /etc/profile.d/mpi.sh"`
    

### Recharger le profil global
    
`clush -g all "source /etc/profile.d/mpi.sh"`
    

#### Compiler code mpi (sur une des machines vs toutes les machines)
    

`mpicc -o /apps/test_mpi /apps/test_mpi.c`<br>
`clush -g all mpicc -o /apps/test_mpi /apps/test_mpi.c`
    

####  Executer code mpi

`mpirun --allow-run-as-root -n 4 /apps/test_mpi`<br>
`clush -g all mpirun --allow-run-as-root -n 4 /apps/test_mpi`
    

# BONUS :

### Faire des petits trains :
    
`clush -g all "TERM=xterm sl"`<br>
`clush -g all "TERM=xterm sl -a -l -F"`
    

# 6/ Slurm

*Source : <br>
[https://github.com/Artlands/Install-Slurm](https://github.com/Artlands/Install-Slurm)<br>
[Youtube - How to Make a Cluster Computer](https://youtu.be/mm11Ws-9DRc?si=5W03ex3sy5CuHVsP)*

Créer les utilisateurs globaux pour `Slurm ` et `Munge `. 
*Le plus simple est de mettre ces commandes dans un script shell et de l’éxecuter avec clush sur toutes les machines* :
```bash
export MUNGEUSER=991
groupadd -g $MUNGEUSER munge
useradd -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGEUSER -g munge -s /sbin/nologin munge
export SLURMUSER=992
groupadd -g $SLURMUSER slurm
useradd -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSER -g slurm -s /bin/bash slurm
```

## Installation de Munge :

`clush -g all sudo yum -y install munge munge-libs munge-devel`<br>
`clush -g all munge --version`
    

**Sur la machine root :**

`sudo create-munge-key`
    
On vérifie que la clé à bien été créée

`ls -l /etc/munge/munge.key`
    
#### On la copie sur chaque noeuds du cluster 
*Je n’ai pas trouvé le moyen de la faire marcher avec clush*
```bash
scp /etc/munge/munge.key root@nvidia1:/etc/munge/munge.key
scp /etc/munge/munge.key root@nvidia2:/etc/munge/munge.key
scp /etc/munge/munge.key root@nvidia3:/etc/munge/munge.key
scp /etc/munge/munge.key root@nvidia4:/etc/munge/munge.key
```

#### On met les bonnes permissions sur le fichier de la clé :

`clush -g all sudo chmod 400 /etc/munge/munge.key`<br>
`clush -g all sudo chown munge:munge /etc/munge/munge.key`
    

### On lance Munge, puis on l’active au démarrage et on affiche son statut :
```
clush -g all sudo systemctl start munge
clush -g all sudo systemctl enable munge
clush -g all sudo systemctl status munge
```


 ## Installation de Slurm

#### Installation des dépendances avec clush
    
`clush -g all yum install openssl openssl-devel pam-devel numactl numactl-devel hwloc hwloc-devel lua lua-devel readline-devel rrdtool-devel ncurses-devel man2html libibmad libibumad -y`
    
#### Installer rpmbuild, python3, mariadb, perl, autoconf, automake
```bash
yum install rpm-build
yum install python3
yum install mariadb-devel
yum install autoconf
yum install automake
yum install perl-ExtUtils-MakeMaker
```
Dans le répertoire partagé NFS donc `/apps` ou `/home` télécharger Slurm **prendre la dernière version**.
    
`wget [https://download.schedmd.com/slurm/slurm-19.05.4.tar.bz2]`
    

#### Décompresser
    
`rpmbuild -ta [slurm-19.05.4.tar.bz2]`
    

#### Vérifier que “rpms” a été crée par “rpmbuild”
    
`cd /root/rpmbuild/RPMS/x86_64`
    

#### Copier le contenu du répertoire `/root/rpmbuild/RPMS/x86_64/` vers `/apps/slurm-rpms`

`mkdir /apps/slurm-rpms`
    

Se placer dans le répertoire `/root/rpmbuild/RPMS/x86_64/` pour faire cette commande

`cp * /apps/slurm-rpms`
    
#### Installation de slurmd.
À faire manuellement sur chacune des machines dans `/apps/slurm-rpms`. 
    
`yum --nogpgcheck localinstall * -y`
    

Sur la machine principale (nvidia0) modifier le fichier de configuration `slurm.conf`.
    
`sudo nano /etc/slurm/slurm.conf`
    

Copier le fichier `slurm.conf` ici 
[https://github.com/Artlands/Install-Slurm/blob/master/Configs/slurm.conf](https://github.com/Artlands/Install-Slurm/blob/master/Configs/slurm.conf)
    
Le coller dans `/etc/slurm/slurm.conf` modifier les dernières lignes pour remplacer par nos noeuds.
    
````
NodeName=nvidia[1-4] NodeAddr=nvidia[1-4] CPUs=4 RealMemory=1881504 Sockets=4 CoresPerSocket=1 ThreadsPerCore=1 State=UNKNOWN
````



#### Depuis la machine principale. Envoyer la config aux machines computes.

```bash
scp /etc/slurm/slurm.conf root@nvidia1:/etc/slurm/ 
scp /etc/slurm/slurm.conf root@nvidia2:/etc/slurm/ 
scp /etc/slurm/slurm.conf root@nvidia3:/etc/slurm/ 
scp /etc/slurm/slurm.conf root@nvidia4:/etc/slurm/
```

#### Depuis la machine principale. Configurer les permissions des fichiers/répertoire pour slurm.
    
```bash
mkdir /var/spool/slurmctld/
mkdir /var/spool/slurm
touch /var/log/slurmctld.log
touch /var/log/slurm_jobacct.log /var/log/slurm/slurm_jobcomp.log
chown slurm:slurm -R /var/log/slurm
chmod 755 /var/log/slurm/
chown slurm:slurm /var/spool/slurmctld/
chmod 755 /var/spool/slurmctld/
chown slurm: /var/spool/slurm/
chmod 755 /var/spool/slurm/
chown slurm: /var/log/slurmctld.log
chmod 755 /var/log/slurmctld.log
chown slurm: /var/log/slurm_jobacct.log /var/log/slurm_jobcomp.log
```
    

### Modifier les PID system sur la machine principale
    
`nano /usr/lib/systemd/system/slurmctld.service`<br>
Ajouter cette ligne : `PIDFile=/var/run/slurmctld.pid`
    
`nano /usr/lib/systemd/system/slurmcdbd.service`<br>
Ajouter cette ligne : `PIDFile=/var/run/slurmdbd.pid`

`nano /usr/lib/systemd/system/slurmd.service`<br>
Ajouter cette ligne : `PIDFile=/var/run/slurmd.pid`

#### Depuis la machine principale. À voir l’utilité de cette commande ?
    
`echo CgroupMountpoint=/sys/fs/cgroup >> /etc/slurm/cgroup.conf`
    

#### Sur les machines computes. Configurer les permissions des fichiers/répertoires pour slurm.
    
*Astuce, créer un script dans le répertoire NFS et faire un :*
    
`clush -g computes /home/script.sh`
    
Mettre les lignes ci-dessous dans le script
```bash
mkdir /var/spool/slurm
chown slurm: /var/spool/slurm
chmod 755 /var/spool/slurm
touch /var/log/slurm/slurmd.log
chown slurm: /var/log/slurm/slurmd.log
```

#### Vérification de la bonne installation de slurm sur toutes les machines.
    
`clush -g all slurmd -C`

Exemple de bon résultat :

````
nvidia1: NodeName=nvidia1 CPUs=2 Boards=1 SocketsPerBoard=2 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=1837
nvidia1: UpTime=25-04:00:46
````
  

### Désactivation des firewall sur toutes les machines computes
    
````
clush -g computes systemctl stop firewalld
clush -g computes systemctl disable firewalld
````

Sur la machine principale. Ouvrir ces ports par défaut pour slurm et recharger le firewall.
````
firewall-cmd --permanent --zone=public --add-port=6817/udp
firewall-cmd --permanent --zone=public --add-port=6817/tcp
firewall-cmd --permanent --zone=public --add-port=6818/udp
firewall-cmd --permanent --zone=public --add-port=6818/tcp
firewall-cmd --permanent --zone=public --add-port=6819/udp
firewall-cmd --permanent --zone=public --add-port=6819/tcp
firewall-cmd --reload
````

Vérifier sur la machine principale les ports ouverts
    
`firewall-cmd --list-all`
    

## Synchronisation de l’horloge sur toutes les machines

````
clush -g all yum install ntp -y
clush -g all chkconfig ntpd on
clush -g all ntpdate pool.ntp.org
clush -g all systemctl start ntpd
````

## Installation de MariaDB sur la machine principale
    
`yum install mariadb-server mariadb-devel -y`
    
### Lancement du service Mariadb
    
````
systemctl enable mariadb
systemctl start mariadb
systemctl status mariadb
````

#### Création de l’utilisateur “slurm” dans la bdd
    

```
mysql
```
````
MariaDB[(none)]> GRANT ALL ON slurm_acct_db.* TO 'slurm'@'localhost' IDENTIFIED BY '1234' with grant option;
    
MariaDB[(none)]> SHOW VARIABLES LIKE 'have_innodb';
    
 MariaDB[(none)]> FLUSH PRIVILEGES;
    
MariaDB[(none)]> CREATE DATABASE slurm_acct_db;
    
MariaDB[(none)]> quit;
````

 Vérifier la connexion avec le mot de passe “1234”
    
````
mysql -p -u slurm
````
````
MariaDB[(none)]> show grants;
MariaDB[(none)]> quit;
````

### Créer un fichier de configuration
    
`nano /etc/my.cnf.d/innodb.cnf` 

Copier les lignes ci-dessous à l’intérieur
    
````
[mysqld]
innodb_buffer_pool_size=1024M
innodb_log_file_size=64M
innodb_lock_wait_timeout=900
````

#### Implémenter ces modifications en arrêtant le service Mariadb

````
systemctl stop mariadb
mv /var/lib/mysql/ib_logfile? /tmp/
systemctl start mariadb
````
#### Vérifier les paramètres courant
    
````
mysql

MariaDB[(none)]> SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
 ````   

#### Modifier fichier de config slurmdbd (cette commande va le créer s’il n’existe pas)
    
`nano /etc/slurm/slurmdbd.conf`

Copier le contenue de
[https://github.com/Artlands/Install-Slurm/blob/master/Configs/slurmdbd.conf](https://github.com/Artlands/Install-Slurm/blob/master/Configs/slurmdbd.conf)
    
Le coller en modifiant s’il le faut certaines options dans `/etc/slurm/slurmdbd.conf`
    
#### Mise en place des permissions pour slurmdbd.
    
````
chown slurm: /etc/slurm/slurmdbd.conf
chmod 600 /etc/slurm/slurmdbd.conf
touch /var/log/slurmdbd.log
chown slurm: /var/log/slurmdbd.log
````

Vérifier manuellement le service slurmdbd (Ctrl+C pour quitter)
    
`slurmdbd -D -vvv`
    
### Depuis la machine principale. Recharger le system daemon
    
`systemctl daemon-reload`
    
### Depuis la machine principale. Lancer le system slurmdbd.
    
````
systemctl enable slurmdbd
systemctl start slurmdbd
systemctl status slurmdbd
````

### Depuis la machine principale. Lancer le system slurm daemon.
    
````
systemctl enable slurmctld.service
systemctl start slurmctld.service
systemctl status slurmctld.service
````
