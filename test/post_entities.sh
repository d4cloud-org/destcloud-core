#!/bin/sh

rm result
wget -nc -O result --post-file=entities2.yaml http://localhost:4567/entities 
