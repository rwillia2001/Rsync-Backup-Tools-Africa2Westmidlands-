# Rsync-Backup-Tools-Africa2Westmidlands-

Here’s a concise, plain-English summary you can keep with the script (or drop into a README).

What problems we had (and why)

Mixed platforms (Windows → Linux)

The source (M:\MUSIC_LIB) lives on Windows 11, exposed via Cygwin + sshd.

Windows paths, permissions, and timestamps don’t map cleanly to Linux unless rsync options are chosen carefully.

SSH under sudo broke authentication

Running rsync as root on Westmidlands2 was necessary to avoid destination permission errors.

But sudo caused SSH to stop using the user’s ~/.ssh keys.

Fix: explicitly tell rsync/ssh which key file and known_hosts to use.

Destination permission chaos

Earlier runs had created parts of the destination tree with restrictive permissions.

Rsync failed with Permission denied (13) just trying to stat() files.

Fix: standardise on running rsync as root, avoiding fragile per-directory permission fixes.

--inplace caused write failures

--inplace requires write access to existing destination files.

Some files weren’t writable → rsync failed.

Fix: remove --inplace and let rsync safely replace files.

Exit codes were misleading

echo $? sometimes reflected a later command (du), not rsync.

Fix: always capture rsync’s exit code immediately.

What the script does now (reliably)

Runs on Westmidlands2

Pulls data from AfricaServer over SSH

Uses:

sudo (so permissions never block the run)

An explicit SSH key and known_hosts (so sudo doesn’t break auth)

Dry-run by default (safe)

Optional --live and --delete

Logs every run with a timestamp

Has guardrails to prevent destructive mistakes

In short: it is designed to “BOOM first time” with no manual intervention.

What it backs up

Source (read-only):

AfricaServer (Windows 11)
M:\MUSIC_LIB
→ Cygwin path: /cygdrive/m/MUSIC_LIB


Destination (authoritative backup):

Westmidlands2
/mnt/sound/backups/MUSIC_LIB


Included content

Ableton Live Packs

Native Instruments libraries (Kontakt, legacy NI content)

Samples, instruments, presets

DAW resources required to rebuild a working music environment

Explicitly excluded

Old email archives:

98_LEGACY_ARCHIVE/M_ROOT_OLD/EMAIL_ARCHIVE/**


Legacy IIS / web junk:

98_LEGACY_ARCHIVE/M_ROOT_OLD/**/Inetpub/**


Everything else under MUSIC_LIB is mirrored.

How to use it (next time)

From Westmidlands2:

1. Safe test (default)
./sync_musiclib_to_westmidlands2.sh

2. Live sync (no deletions)
./sync_musiclib_to_westmidlands2.sh --live

3. Full mirror (including deletions)
./sync_musiclib_to_westmidlands2.sh --live --delete


⚠️ --delete only removes files from Westmidlands2 that no longer exist on AfricaServer.
It never deletes source data.

Bottom line

The script now handles Windows ↔ Linux, permissions, and SSH correctly.

It has been verified with a dry-run showing zero changes and exit code 0.

You can now run it confidently, repeatedly, and forget about it.

If you want, next step could be:

adding this to cron,

or writing a tiny README.md to live next to the script permanently.
Install / use

Save that as sync_musiclib_to_westmidlands2.sh

Make it executable:

chmod +x sync_musiclib_to_westmidlands2.sh

Run next time

Safe test:

./sync_musiclib_to_westmidlands2.sh


Live:

./sync_musiclib_to_westmidlands2.sh --live


If you want, I can also add a --dry-run flag explicitly (right now dry-run is the default) and/or add a --log-dir override.
