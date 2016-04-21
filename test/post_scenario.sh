#!/bin/sh

rm result
wget -O result -nc --post-file=scenario.yaml http://localhost:4567/scenario/+5

