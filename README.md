# Automated Project Bootstrapping and Process Management

Bash deployment agent for the unmodified Student Attendance Tracker.

## Requirements

- Bash, Python 3, `zip`, `sed`, `awk`, `head`, `chmod`, and standard Unix tools.
- Linux, macOS (with compatible `sed -i` syntax), or a Linux environment such as WSL on Windows. The script uses GNU `sed -i`, so Linux/WSL is recommended.
- Three original files in `templates/`: `attendance_checker.py`, `assets.csv`, `config.json`.

## Start

```bash
chmod +x deploy_agent.sh
./deploy_agent.sh
```

The interactive menu offers **1 Deploy**, **2 Run**, **3 Archive logs**, **4 Exit**. Run commands from any working directory: the script resolves templates and projects relative to its own location.

## Deploy (menu 1)

The script verifies that `python3` and `zip` exist and displays `python3 --version`. Enter a suffix such as `v1`; this creates `attendance_tracker_v1/`. Only alphanumeric characters, `_`, and `-` are allowed. Existing projects are **never overwritten**: deployment stops with an error. The script creates `Helpers/` and an initially empty `reports/`, copies the unmodified Python script and template configuration, and constructs `Helpers/assets.csv`.

- **Option A (template roster):** choose 1 through 10 students. The header and selected sample rows are copied. Each student has four prior sessions, so `total_sessions` is set to **5**.
- **Option B (generated roster):** choose 1 through 10 students from the sample name/email arrays built into the shell script. Counts start at zero, so `total_sessions` is set to **1**.

`attendance_checker.py` is made executable with `chmod +x`, and `Helpers/config.json` is restricted using `chmod 600` (owner read/write only). The script prints a permissions confirmation.

Choose `y` to update thresholds, then enter whole-number percentages from 0 to 100 for the warning and failure thresholds. The failure threshold cannot exceed the warning threshold. Invalid input is rejected. The script uses targeted `sed` replacements in the **deployed** `Helpers/config.json`, preserving the file's layout. Choose `n` to retain defaults of 75 and 50. The template stays unchanged.

At the end of deployment, the shell starts `python3 attendance_checker.py` from the deployed project directory. Mark each student using `P` or `A`. This live session checks that the Python application can read the files and create outputs.

## Run (menu 2)

Enter the suffix of an existing project, e.g., `v1`. The script checks for required files and runs `python3 attendance_checker.py` from that project's root with the terminal connected so you can mark students.

**Important subsequent-session step:** `attendance_checker.py` updates roster counts, but does not increment `total_sessions`. Before running a *new full session*, set `total_sessions` in the deployed `Helpers/config.json` to one plus the number of **completed** prior sessions. For example, a sample-roster deployment starts at session 5, and the next complete session should use 6. Do not blindly increase after a partially completed session, since students can have different totals. No changes are made to the supplied Python application.

## Archive logs (menu 3)

After a marking run, select menu 3 and enter the deployed project's suffix. The script checks for each source file independently:

```text
attendance_tracker_v1/
├── attendance_checker.py
├── Helpers/
│   ├── assets.csv
│   └── config.json
├── reports/
│   ├── attendance.log
│   └── absent.log     # only if absent students were recorded
└── archives/
    ├── attendance/
    │   └── attendance_YYYYMMDD_HHMMSS.log
    └── absent/
        └── absent_YYYYMMDD_HHMMSS.log
```

The command **copies** existing logs, leaving the original reports in place. It prints full archive paths and reports skipped missing files without failing. A repeated archive in the same second waits to generate a new timestamp instead of overwriting a previous archive. If nobody was absent, `absent.log` may not exist.

## Interrupted deployment: Ctrl+C and Ctrl+Z

During the **deploy setup phase only**, Bash traps both `SIGINT` (Ctrl+C) and `SIGTSTP` (Ctrl+Z). The interrupt handler:

1. Explains which signal interrupted the setup.
2. Uses `zip` to back up **whatever has been created so far** as `attendance_tracker_v1_archive.zip` (a timestamped variant is used if that filename already exists).
3. Deletes the incomplete project **only if the ZIP command succeeds**. If backup creation fails, it leaves the directory available for recovery.
4. Exits with status 130 instead of suspending or crashing.

The ZIP can contain an incomplete `Helpers/`, `reports/`, Python source, config, and possibly the roster depending on exactly when the signal arrived. The deployment signal handlers are disabled **before** the interactive Python marking session starts, so Ctrl+C in Python is handled by the Python application instead.

**Demo:** start menu 1, type a new suffix, wait for the roster-choice prompt, and press Ctrl+C. Inspect the ZIP using `unzip -l attendance_tracker_<suffix>_archive.zip` and show that the original incomplete directory is gone. Repeat with a *different suffix* and Ctrl+Z. In a non-interactive test, send `SIGINT` or `SIGTSTP` to the Bash process while it awaits input.

## Testing checklist

- Confirm template-based deployment with 2 students; mark one present and one absent. Check the roster counts, both reports, and `total_sessions: 5`.
- Confirm generated-roster deployment with 2 students, initial counts of zero, and `total_sessions: 1`.
- Reject a second deploy with an existing suffix; confirm no files were overwritten.
- Enter nonnumeric thresholds and retry; inspect `Helpers/config.json` for validated settings while verifying its original formatting.
- Check `ls -l` for executable Python script and config permission `-rw-------`.
- Choose Run and complete marking for a deployed project.
- Choose Archive twice; confirm separately archived logs with unique filenames. Test a session with no absences to verify the missing-log message.
- Interrupt a deployment using both Ctrl+C and Ctrl+Z and verify ZIP contents plus directory cleanup.
- Check `bash -n deploy_agent.sh` for syntax errors.

## Version control and delivery

Create a GitHub repository named `deploy_agent_GithubUsername`, substituting your actual username. Commit the script, README, and original templates. Use descriptive commits, for example: `Add deployment and input checks`, `Implement log archival`, `Handle SIGINT and SIGTSTP`, and `Document and test workflow`. Add a link to your walkthrough video in the README before submission.

**Walkthrough video:** explain the file structure, how both roster options work, threshold validation and `sed`, permissions, the live marking prompts, timestamped archived logs, interruption backup and cleanup, and one or two error cases. Show the real terminal output while demonstrating.

**Video link:**

## Limitations

- The default generated roster has ten built-in sample students, so option B supports 1 through 10 students.
- This script targets Bash and GNU userland tools, most directly Linux or WSL.
- A new full session requires advancing `total_sessions` in the deployed config; the Python application itself is not modified.
