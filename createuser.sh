if [ -n "$1" ]; then

    # Nom de l'utilisateur
    nom_utilisateur="$1"

    # Génère une chaine de 10 caractères aléatoires pour faire un mot de passe (8 c'est le nb min de char pour un passwd)
    new_password=$(< /dev/urandom tr -dc 'A-Za-z0-9!@#$%&*()' | head -c 10)

    # Liste des machines du réseau
    serveurs=("nvidia0" "nvidia1" "nvidia2" "nvidia3" "nvidia4")

    # Création de l'utilisateur sur la machine master (nvidia0)
    # useradd : Crée un utilisateur
    # -M : 
    # -m : Crée son répertoire dans /home
    # -d : Force son répertoire dans /home
    # -s : Le shell est bash
    sudo useradd -m -d /home/$nom_utilisateur -s /bin/bash $nom_utilisateur

    # Changement du mot de passe de l'utilisateur
    echo "$nom_utilisateur:$new_password" | sudo chpasswd


    # Commandes pour créer l'utilisateur sur les autres machines
    creer_utilisateur="sudo useradd -M -d /home/$nom_utilisateur -s /bin/bash $nom_utilisateur"
    modif_passwd="echo '$nom_utilisateur:$new_password' | sudo chpasswd"

    # Création des utilisateurs sur les autres machines du cluster
    clush -g computes "$creer_utilisateur && $modif_passwd"


    # Création de la clé ssh pour l'utilisateur dans son répertoire home
    su - $nom_utilisateur -c "ssh-keygen -t rsa -b 2048 -f "/home/$nom_utilisateur/.ssh/id_rsa" -N ''"

    # Copie de la clé public de l'utilisateur dans le fichier authorized_keys
    cat /home/$nom_utilisateur/.ssh/id_rsa.pub > /home/$nom_utilisateur/.ssh/authorized_keys

    # Permissions pour les accès au ssh de l'utilisateur
    chmod 700 /home/$nom_utilisateur/.ssh
    chmod 600 /home/$nom_utilisateur/.ssh/authorized_keys

    # Changement du propriétaire du fichier authorized_keys
    chown $nom_utilisateur:$nom_utilisateur /home/$nom_utilisateur/.ssh/authorized_keys

    echo "Création de l'utilisateur $nom_utilisateur avec le mot de passe : $new_password"

else
    echo "Erreur : pas de nom d'utilisateur."
    exit 1
fi
