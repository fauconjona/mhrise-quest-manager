#!/bin/bash

# Vérifier si le dossier ./reframework/autorun existe
if [ ! -d "./reframework/autorun" ]; then
    mkdir -p ./reframework/autorun
fi

# Copier le fichier quest_manager dans le dossier ./reframework/autorun
cp quest_manager.lua ./reframework/autorun

# Créer un fichier zip avec le dossier ./reframework/autorun à l'intérieur
zip -r quest-manager.zip ./reframework/autorun