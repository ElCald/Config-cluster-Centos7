#!/bin/bash

if [ -n "$1" ]; then

    # Nom de l'utilisateur
    nom_utilisateur="$1"

    sudo userdel -r $nom_utilisateur
    cat /etc/passwd | grep $nom_utilisateur

    # Commande pour créer l'utilisateur sur les machines distantes
    supp_utilisateur="sudo userdel $nom_utilisateur"
    verif_utilisateur="cat /etc/passwd | grep $nom_utilisateur"

    # Exécute la commande de création d'utilisateur sur toutes les machines du groupe clush
    clush -g computes "$supp_utilisateur"

    echo "Suppréssion de l'utilisateur $nom_utilisateur"

else
    echo "Erreur : pas de nom d'utilisateur."
    exit 1
fi
