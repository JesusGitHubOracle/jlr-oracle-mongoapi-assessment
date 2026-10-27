# MongoDB cluster assessment and sizing

Use this package to collect `serverStatus` JSON from MongoDB Enterprise or Atlas clusters and complete a spreadsheet for high-level Oracle Autonomous AI JSON Database sizing.

## 1 Download the package

1. Open the [GitHub repository](https://github.com/JesusGitHubOracle/jlr-oracle-mongodb-api).
2. Locate the uploaded quick assessment ZIP. The package in this folder is available as [quick-assessment.zip](../quick-assessment.zip).
3. Open the ZIP file page and select **Download raw file**. GitHub may show a download icon instead of this label.
4. Extract the ZIP into a working directory on your collection machine.
5. Open a terminal in the extracted `quick-assessment` folder.

The package contains:

| File | Purpose |
| --- | --- |
| `collect-clusters.sh` | Run the existing extraction script for each cluster in your list. |
| `clusters.example.txt` | Example list of cluster names and connection URIs. |
| Sizing workbook (`.xlsx`) | Customer inputs for the high-level sizing exercise. |

## 2 Prepare the collection machine

Use macOS, Linux, or a configured Linux environment such as WSL on Windows. Install **Bash**, **MongoDB Shell (`mongosh`)**, and **jq** in that environment.

Check that the tools are available:

```bash
bash --version
mongosh --version
jq --version
```

The collection machine must have network access to each MongoDB endpoint. Configure any required Atlas network access entries, private connectivity, DNS, and TLS trust before collecting.

Use a MongoDB account with permission to run `serverStatus` against each endpoint. Ask your MongoDB administrator to confirm the appropriate monitoring privileges.

## 3 Download the existing extraction script

The quick assessment ZIP requires the separate [mongoserverStatus.sh extraction script](../../migration/mongoserverStatus.sh).

1. Open that script in the GitHub repository.
2. Select **Download raw file**.
3. Save it as `mongoserverStatus.sh` in the extracted `quick-assessment` folder.

Your working directory should now contain:

```text
quick-assessment/
  collect-clusters.sh
  clusters.example.txt
  mongoserverStatus.sh
  <sizing workbook>.xlsx
```

Use the exact filename, including capitalization. The commands below explicitly select this local extraction script.

## 4 Create the cluster list

Copy the example file:

```bash
cp clusters.example.txt clusters.txt
chmod 600 clusters.txt
```

Edit `clusters.txt` in a text editor. Add one line per cluster, using this format:

```text
cluster-name|MongoDB-connection-URI
```

For example:

```text
# Cluster name and URI separated by a single pipe character
cluster-01|mongodb+srv://USERNAME:PASSWORD@cluster01.example.mongodb.net/admin
cluster-02|mongodb://USERNAME:PASSWORD@mongo02.example.com:27017/admin?authSource=admin
```

- Replace the example hosts, usernames, passwords, and options with your actual connection details. Add the remaining clusters to the same file.
- Use unique cluster names containing only letters, numbers, hyphens, or underscores. The name becomes the output directory name.
- Do not add spaces around the `|` separator or wrap the URI in quotes.
- Preserve the authentication, TLS, replica set, and other connection options required by your deployment. Percent-encode special characters in URI usernames and passwords.
- Blank lines and comment lines starting with `#` are ignored.

The list contains credentials. Keep it private, do not commit it to GitHub, and do not include it in the files returned for assessment. Run collection on a trusted machine because the underlying extraction script passes the URI to `mongosh` as a process argument.

**Capture scope:** one cluster URI captures the selected server or router. It does not automatically collect every member of a replica set or every shard. If member-specific evidence is required, add separate entries with unique names and administrator-supplied member URIs. Record which endpoints were captured.

## 5 Run the collection

From the extracted folder, run:

```bash
bash collect-clusters.sh clusters.txt ./captures ./mongoserverStatus.sh
```

The three arguments are:

| Argument | Meaning |
| --- | --- |
| `clusters.txt` | Your cluster names and connection URIs. |
| `./captures` | Parent directory for the collected files. |
| `./mongoserverStatus.sh` | Path to the existing extraction script. |

The wrapper runs clusters sequentially, supplies Enter to the extraction script automatically, and validates each generated JSON file. It continues with the next cluster if a capture fails.

Example console output:

```text
Collecting cluster-01
Saved: ./captures/cluster-01/<timestamp>_serverStatus_<run-id>.json
Collecting cluster-02
Saved: ./captures/cluster-02/<timestamp>_serverStatus_<run-id>.json
```

After the command finishes, check its exit status immediately:

```bash
echo $?
```

- `0`: all processed captures succeeded.
- `1`: a capture failed or a setup/input problem was detected. Review the console messages.

Check that your list includes all intended clusters and that every cluster has a successful capture. The script does not enforce a count of 30.

## 6 Review the output and retry failures

The output is organized by cluster name:

```text
captures/
  cluster-01/
    <timestamp>_serverStatus_<run-id>.json
  cluster-02/
    <timestamp>_serverStatus_<run-id>.json
```

Each run uses a new run identifier. Repeating the command preserves files from previous runs. An invalid capture from the current run is removed; older successful files can still exist in that cluster directory, so use the current console messages and run identifier to confirm success.

If a cluster fails:

1. Check the URI and its authentication database.
2. Confirm network access, DNS resolution, and TLS settings from the collection machine.
3. Confirm that the MongoDB account can run `serverStatus`.
4. Correct the issue and rerun the command. To retry only failed clusters, create a list containing those entries and pass that filename as the first argument.

If a connection hangs, use **Ctrl+C**, investigate connectivity, and retry. This sample wrapper has no per-cluster timeout.

## 7 Complete the sizing spreadsheet

Open the Excel workbook included in the ZIP. Depending on the package version, it may be named `MongoDB customer sizing.xlsx` or `MongoDB-SAN-sizing.xlsx`.

1. Open the **Cluster sizing** worksheet.
2. Replace the placeholder cluster names with the same names used in `clusters.txt`.
3. Complete one row for each of the 30 clusters. Yellow cells are customer inputs. Grey cells calculate `totalVcpu` and `totalMemoryGb` automatically.
4. Read the **Field guide** worksheet for definitions and the supplied example.
5. Leave unknown values blank and identify missing information when returning the workbook. Enter a numeric zero only when it is a measured value.

| Field | What to provide |
| --- | --- |
| `name` | Unique cluster name matching its capture directory. |
| `tier` | Atlas tier, such as `M30`, or Enterprise host class. |
| `nodes` | Number of data-bearing MongoDB members. Exclude routers, config servers, and arbiters. |
| `vcpuPerNode` | Provisioned vCPU per member. Use the average if members have different capacities. |
| `totalVcpu` | Calculated as `nodes × vcpuPerNode`. |
| `memoryPerNodeGb` | Provisioned RAM per member. Use the average if members differ. |
| `totalMemoryGb` | Calculated as `nodes × memoryPerNodeGb`. |
| `usedStorageGb` | Logical application data, counted once per replica set and summed once across shards. Do not multiply by replica count. |
| `hostStorageGb` | Provisioned disk capacity for one logical data copy, summed across shard primaries. Do not multiply by replica count. |
| `cpuPeakPct` | Peak CPU percentage for the declared node scope and monitoring window. Enter `50` for 50%. |
| `cpuNormalPct` | Average CPU percentage for the same scope and window. Enter `30` for 30%. |
| `peakConnections` | Peak simultaneous application connections across the declared endpoints. |
| `normalConnections` | Average simultaneous application connections for the same scope and window. |
| `source` | Monitoring system or export reference, date range, sampling interval, and scope. |

Memory and storage fields use **GiB** despite the `Gb` field names: divide bytes by `1,073,741,824`.

Use a representative business cycle for CPU and connection measurements, including relevant batch or business peaks. Use the same member population as the capacity totals. For members with different capacities, use a capacity-weighted CPU series; take its average and peak rather than adding individual member peaks from different times.

A single `serverStatus` snapshot does not provide historical normal and peak CPU or connections. Obtain these values from Atlas monitoring or your Enterprise monitoring system. Use `source` to identify that evidence.

## 8 Return the assessment inputs

Provide the assessment team with:

- The completed sizing workbook for all 30 clusters.
- The `captures` directory containing the selected successful JSON files, with cluster directory names preserved.
- A note identifying failed or missing captures, unknown sizing inputs, capture dates, and any member-specific capture scope.

Transfer these files through your agreed secure channel. Do not include `clusters.txt` or credentials. Captures can contain internal hostnames and operational metadata.

The assessment team uses the JSON files in the Oracle compatibility tool and the workbook for high-level sizing. Representative application testing is still needed to validate compatibility and the proposed target configuration.
