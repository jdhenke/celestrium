#!/bin/sh
# run from root of repo
(curl -O http://snap.stanford.edu/data/facebook_combined.txt.gz &&
  gunzip facebook_combined.txt.gz &&
  mv facebook_combined.txt data/ &&
  echo "Done.") ||
echo "Failed."