# Documentation installation d’un cluster sur Centos7
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
```bash
sudo passwd
```

### Changement du nom sur chaque machine :
```bash
sudo hostnamectl set-hostname nvidia0
sudo nano /etc/hosts
```
    
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
```bash
ssh-keygen -t rsa -b 4096
```
    
#### Copie de la clé ssh dans toutes les machines :
```bash
ssh-copy-id root@10.124.2.[46-50]
```
    
**Ne pas oublier la connexion ssh de nvidia0 vers nvidia0 et faire une 1ère connexion ssh avec toutes les machines pour enregistrer le fingerprint dans le répertoire** `~/.ssh/known_hosts`
    

# 2/ Clush

### Dépendances :
```bash
sudo yum install -y perl-Errno perl-File-Temp perl-IO-File perl-IO-Socket-SSL perl-Getopt-Long perl-Text-Glob
```

### Installation de EPEL:
```bash
sudo yum install -y epel-release
```

### Installer clush :
```bash 
sudo yum install -y clustershell
```

###  Configurer noeuds :
```bash
sudo nano /etc/clustershell/groups 
```

Ajouter dans le fichier `/etc/clustershell/groups` (**PAS D’ESPACE ENTRE** “:” ET “all” ou “computes” ou “admin”):
    
```
all: nvidia0 nvidia1 nvidia2 nvidia3 nvidia4
computes: nvidia1 nvidia2 nvidia3 nvidia4
admin: nvidia0
```
### Exemples de vérifications
```bash
clush -w 10.124.2.[46-50] "hostname -I"
clush -g Cl_Nvidia echo "Bonjour"
```

# 3/ NFS

Pour l’installation de NFS sur toutes les machines nous passerons par clush, s’il n’est pas installé, il faudra faire les commandes sur toutes les machines.
Les répertoires partagés seront `/apps` et `/home`.

*Exécution de toutes les commandes suivantes depuis la machine root (nvidia0).*
    

### Installer NFS sur toutes les machines:
```bash
clush -g all sudo yum -y install nfs-utils
```

Créer répertoire apps si il n’existe pas :
```bash
clush -g all sudo mkdir -p /apps
```

### Editer le fichier exports :
```bash
sudo nano /etc/exports
```

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
```bash
sudo systemctl enable nfs-server
sudo systemctl start nfs-server
```

Vérifier que les dossiers sont biens exportés : 
```bash
sudo exportfs -v
```

### Ajout de règles au pare-feu :
```bash
sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --permanent --add-service=mountd
sudo firewall-cmd --permanent --add-service=rpc-bind
sudo firewall-cmd --reload
```
    

Sur chaques machines **hormis la root**, montez les répertoires :
```bash
clush -g computes sudo mount -t nfs machine0:/home /home
clush -g computes sudo mount -t nfs machine0:/apps /apps
```

Vérification que les partages ont été montés correctement :
```bash
clush -g computes df -h | grep nvidia0
```

Enfin, pour monter les répertoires automatiquement au démarrage des machines, ajouter ces lignes au fichier `/etc/fstab` de toutes les machines **sauf la root** :
````
nvidia0:/home /home nfs defaults 0 0
nvidia0:/apps /apps nfs defaults 0 0  
````
    

# 4/ Create user

### Script bash :
Voir `createuser.sh`

### Donner les permissions au script :
```bash
chmod +x createuser.sh
```

### Exécution du script
```bash
./createuser.sh nom
```

## Configurer SELinux 
*Source : <br>
[https://serverfault.com/questions/849631/why-is-selinux-blocking-remote-ssh-access-without-a-password](https://serverfault.com/questions/849631/why-is-selinux-blocking-remote-ssh-access-without-a-password)*

SELinux bloque l’accès de ssh aux répertoires et fichiers NFS, pour régler ce problème 2 options.
    
Retirer tout le système de sécurité SELinux avec :
```bash
setenforce 0
```

OU

Modifier la config pour laisser autoriser l’accès à ssh aux répertoires NFS
```bash
setsebool -P use_nfs_home_dirs 1
```

# 5/ MPI

Note : Un fichier de test pour MPI est dans le répertoire apps commun à toutes les machines.

### Installer mpi sur toutes les machines
```bash
clush -g all sudo yum -y install openmpi
clush -g all sudo yum -y install openmpi-devel
```

### Ajouter mpi au path
```bash
clush -g all "echo 'export PATH=/usr/lib64/openmpi/bin:\$PATH' | sudo tee /etc/profile.d/mpi.sh"
clush -g all "echo 'export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:\$LD_LIBRARY_PATH' | sudo tee -a /etc/profile.d/mpi.sh"
```

### Recharger le profil global
```bash
clush -g all "source /etc/profile.d/mpi.sh"
```

#### Compiler code mpi (sur une des machines vs toutes les machines)
```bash
mpicc -o /apps/test_mpi /apps/test_mpi.c
clush -g all mpicc -o /apps/test_mpi /apps/test_mpi.c
```

####  Executer code mpi
```bash
mpirun --allow-run-as-root -n 4 /apps/test_mpi
clush -g all mpirun --allow-run-as-root -n 4 /apps/test_mpi
```

# BONUS :

### Faire des petits trains :
```bash
clush -g all "TERM=xterm sl"
clush -g all "TERM=xterm sl -a -l -F"
```

# 6/ Slurm

*Source : <br>
[https://github.com/Artlands/Install-Slurm](https://github.com/Artlands/Install-Slurm)<br>
[Youtube - How to Make a Cluster Computer](https://youtu.be/mm11Ws-9DRc?si=5W03ex3sy5CuHVsP)*

Créer les utilisateurs globaux pour `Slurm ` et `Munge `. 
*Le plus simple est de mettre ces commandes dans un script shell dans un répertoire NFS et de l’éxecuter avec clush sur toutes les machines* : <br>
Utiliser `script1.sh`
```bash
export MUNGEUSER=991
groupadd -g $MUNGEUSER munge
useradd -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGEUSER -g munge -s /sbin/nologin munge
export SLURMUSER=992
groupadd -g $SLURMUSER slurm
useradd -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSER -g slurm -s /bin/bash slurm
```
```bash
clush -g all /apps/script1.sh
```

## Installation de Munge :
```bash
clush -g all sudo yum -y install munge munge-libs munge-devel
clush -g all munge --version
```

**Sur la machine master :**
```bash
sudo create-munge-key
```

On vérifie que la clé à bien été créée
```bash
ls -l /etc/munge/munge.key
```
    
#### On la copie sur chaque noeuds du cluster depuis la master
```bash
scp /etc/munge/munge.key root@nvidia1:/etc/munge/munge.key
scp /etc/munge/munge.key root@nvidia2:/etc/munge/munge.key
scp /etc/munge/munge.key root@nvidia3:/etc/munge/munge.key
scp /etc/munge/munge.key root@nvidia4:/etc/munge/munge.key
```

#### On met les bonnes permissions sur le fichier de la clé :
```bash
clush -g all sudo chmod 400 /etc/munge/munge.key
clush -g all sudo chown munge:munge /etc/munge/munge.key
```

### On lance Munge, puis on l’active au démarrage et on affiche son statut :
```bash
clush -g all sudo systemctl start munge
clush -g all sudo systemctl enable munge
clush -g all sudo systemctl status munge
```


 ## Installation de Slurm

#### Installation des dépendances avec clush
```bash
clush -g all yum install openssl openssl-devel pam-devel numactl numactl-devel hwloc hwloc-devel lua lua-devel readline-devel rrdtool-devel ncurses-devel man2html libibmad libibumad -y
```
    
#### Installer rpmbuild, python3, mariadb, perl, autoconf, automake
```bash
yum install rpm-build
yum install python3
yum install mariadb-devel
yum install autoconf
yum install automake
yum install perl-ExtUtils-MakeMaker
```
Dans le répertoire partagé NFS donc `/apps` ou `/home` télécharger Slurm **prendre la dernière version**. Conseil, créer un répertoire par exemple `slurm_installation` pour y décompresser le tar.bz2 téléchargé <br>
*Chercher la dernière version ici -> https://download.schedmd.com/slurm/*
```bash
wget https://download.schedmd.com/slurm/slurm-24.11.0.tar.bz2
```

#### Décompresser dans le répertoire `slurm_installation` s'il a été crée
```bash
rpmbuild -ta slurm-24.11.0.tar.bz2
```

#### Vérifier que “rpms” a été crée par “rpmbuild”
```bash
cd /root/rpmbuild/RPMS/x86_64
```
    

#### Copier le contenu du répertoire `/root/rpmbuild/RPMS/x86_64/` vers `/apps/slurm-rpms`
```bash
mkdir /apps/slurm-rpms
```
    

Se placer dans le répertoire `/root/rpmbuild/RPMS/x86_64/` pour faire cette commande
```bash
cp * /apps/slurm-rpms
```
    
#### Installation de slurmd.
À faire manuellement sur chacune des machines dans `/apps/slurm-rpms`. 
```bash
yum --nogpgcheck localinstall * -y
```

Si nécessaire en cas de conflit avec une architecture déjà présente, ajouter ce flag pour contourner le problème. **Ce n'est clairement pas recommandé**.<br>
```bash
yum --nogpgcheck localinstall * --setopt=protected_multilib=false -y
```


En cas de corruption de la base de données rpm suite à la dernière commande, faire ce qui suit. Sinon passer à la suite. <br>
```bash
rpm -qa | grep slurm
```

Supprimer ces paquets (changer le paquet). <br>
```bash
rpm -e --nodeps slurm-doc-20.11.9-1.el7.x86_64
```

Si nécessaire, reconstruire la base de données rpm. <br>

```bash
rpm --rebuilddb
yum clean all
yum update
rm -f /var/lib/rpm/__db.*
rpm --rebuilddb
```

Puis refaire un installation des paquets.<br>
Fin de l'étape de réparation de la bdd.
    

Sur la machine principale (nvidia0) modifier le fichier de configuration `slurm.conf`.
```bash
sudo nano /etc/slurm/slurm.conf
```
    

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
mkdir /var/log/slurm/
mkdir /var/spool/slurmctld/
mkdir /var/spool/slurm/
touch /var/log/slurmctld.log
touch /var/log/slurm_jobacct.log
touch /var/log/slurm/slurm_jobcomp.log
chown slurm: /var/log/slurm_jobacct.log
chown slurm: /var/log/slurm/slurm_jobcomp.log
chown slurm:slurm -R /var/log/slurm
chmod 755 /var/log/slurm/
chown slurm:slurm /var/spool/slurmctld/
chmod 755 /var/spool/slurmctld/
chown slurm: /var/spool/slurm/
chmod 755 /var/spool/slurm/
chown slurm: /var/log/slurmctld.log
chmod 755 /var/log/slurmctld.log
```
    

### Modifier les PID system sur la machine principale
```bash
nano /usr/lib/systemd/system/slurmctld.service
```
Ajouter cette ligne : `PIDFile=/var/run/slurmctld.pid`

```bash
nano /usr/lib/systemd/system/slurmdbd.service
```
Ajouter cette ligne : `PIDFile=/var/run/slurmdbd.pid`

```bash
nano /usr/lib/systemd/system/slurmd.service
```
Ajouter cette ligne : `PIDFile=/var/run/slurmd.pid`

#### Depuis la machine principale. À voir l’utilité de cette commande ?
```bash
echo CgroupMountpoint=/sys/fs/cgroup >> /etc/slurm/cgroup.conf
```
    

#### Sur les machines computes. Configurer les permissions des fichiers/répertoires pour slurm.
    
*Astuce, créer un script dans le répertoire NFS et faire un :*
```bash
clush -g computes /home/script.sh
```
    
Mettre les lignes ci-dessous dans le script
```bash
mkdir /var/spool/slurm
chown slurm: /var/spool/slurm
chmod 755 /var/spool/slurm
touch /var/log/slurm/slurmd.log
chown slurm: /var/log/slurm/slurmd.log
```

#### Vérification de la bonne installation de slurm sur toutes les machines.
```bash
clush -g all slurmd -C
```

Exemple de bon résultat :

````
nvidia1: NodeName=nvidia1 CPUs=2 Boards=1 SocketsPerBoard=2 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=1837
nvidia1: UpTime=25-04:00:46
````
  

### Désactivation des firewall sur toutes les machines computes
    
````bash
clush -g computes systemctl stop firewalld
clush -g computes systemctl disable firewalld
````

Sur la machine principale. Ouvrir ces ports par défaut pour slurm et recharger le firewall.
```bash
firewall-cmd --permanent --zone=public --add-port=6817/udp
firewall-cmd --permanent --zone=public --add-port=6817/tcp
firewall-cmd --permanent --zone=public --add-port=6818/udp
firewall-cmd --permanent --zone=public --add-port=6818/tcp
firewall-cmd --permanent --zone=public --add-port=6819/udp
firewall-cmd --permanent --zone=public --add-port=6819/tcp
firewall-cmd --reload
```

Vérifier sur la machine principale les ports ouverts
```bash
firewall-cmd --list-all
```

## Synchronisation de l’horloge sur toutes les machines

```bash
clush -g all yum install ntp -y
clush -g all chkconfig ntpd on
clush -g all ntpdate pool.ntp.org
clush -g all systemctl start ntpd
```

## Installation de MariaDB sur la machine principale
```bash
yum install mariadb-server mariadb-devel -y
```
    
### Lancement du service Mariadb
```bash
systemctl enable mariadb
systemctl start mariadb
systemctl status mariadb
```

#### Création de l’utilisateur “slurm” dans la bdd

```bash
mysql
```
```bash
MariaDB[(none)]> GRANT ALL ON slurm_acct_db.* TO 'slurm'@'localhost' IDENTIFIED BY '1234' with grant option;
    
MariaDB[(none)]> SHOW VARIABLES LIKE 'have_innodb';
    
MariaDB[(none)]> FLUSH PRIVILEGES;
    
MariaDB[(none)]> CREATE DATABASE slurm_acct_db;
    
MariaDB[(none)]> quit;
```

 Vérifier la connexion avec le mot de passe “1234”
    
```bash
mysql -p -u slurm
```
```bash
MariaDB[(none)]> show grants;
MariaDB[(none)]> quit;
```

### Créer un fichier de configuration
```bash
nano /etc/my.cnf.d/innodb.cnf
```

Copier les lignes ci-dessous à l’intérieur
    
```
[mysqld]
innodb_buffer_pool_size=1024M
innodb_log_file_size=64M
innodb_lock_wait_timeout=900
```

#### Implémenter ces modifications en arrêtant le service Mariadb

```bash
systemctl stop mariadb
mv /var/lib/mysql/ib_logfile? /tmp/
systemctl start mariadb
```
#### Vérifier les paramètres courant
    
```bash
mysql

MariaDB[(none)]> SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
``` 

#### Modifier fichier de config slurmdbd (cette commande va le créer s’il n’existe pas)
```bash
nano /etc/slurm/slurmdbd.conf
```

Copier le contenue de
[https://github.com/Artlands/Install-Slurm/blob/master/Configs/slurmdbd.conf](https://github.com/Artlands/Install-Slurm/blob/master/Configs/slurmdbd.conf)
    
Le coller en modifiant s’il le faut certaines options dans `/etc/slurm/slurmdbd.conf`
    
#### Mise en place des permissions pour slurmdbd.
```bash
chown slurm: /etc/slurm/slurmdbd.conf
chmod 600 /etc/slurm/slurmdbd.conf
touch /var/log/slurmdbd.log
chown slurm: /var/log/slurmdbd.log
```

Vérifier manuellement le service slurmdbd (Ctrl+C pour quitter)
```bash
slurmdbd -D -vvv
```
    
### Depuis la machine principale. Recharger le system daemon
```bash
systemctl daemon-reload
```
    
### Depuis la machine principale. Lancer le system slurmdbd.
```bash
systemctl enable slurmdbd
systemctl start slurmdbd
systemctl status slurmdbd
```

### Depuis la machine principale. Lancer le system slurm daemon.
```bash
systemctl enable slurmctld.service
systemctl start slurmctld.service
systemctl status slurmctld.service
```
