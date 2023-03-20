#!/bin/bash

file_to_copy="quest_manager.lua"
destination_folder="/media/steam/SteamLibrary/steamapps/common/MonsterHunterRise/reframework/autorun/"

if [ -f "$file_to_copy" ]; then
    cp "$file_to_copy" "$destination_folder"
    echo "Done"
else
    echo "File $file_to_copy doesn't exist."
fi
