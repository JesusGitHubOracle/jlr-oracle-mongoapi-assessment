1. Copy clusters.example.txt to clusters.txt. Add one cluster-name|URI per line.
2. Restrict access: chmod 600 clusters.txt
3. Run:
   bash collect-clusters.sh clusters.txt ./captures /path/to/mongoserverStatus.sh

Requires bash, mongosh and jq. Use the existing script filename exactly (case matters).
Output: captures/cluster-01/<timestamp>_serverStatus_<run-id>.json
The wrapper supplies Enter automatically, validates each JSON, and continues on failure.
Exit 0: all captures succeeded. Exit 1: a capture or setup failed.
A cluster URI captures the selected server or router, not all members.
Use additional named entries if member-specific captures are required.
The URI list contains credentials: keep it private and out of version control.
