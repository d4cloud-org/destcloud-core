#!/bin/sh

rm result
wget -nc -O result --post-file=subtopology.yaml http://localhost:4567/sub_topology
